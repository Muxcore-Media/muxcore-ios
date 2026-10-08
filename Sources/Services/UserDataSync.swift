import Foundation

struct UserDataScope: Codable, Equatable {
    let origin: String
    let userID: String
    let tenantID: String

    var storageKey: String {
        // No credential or username in preferences. Components cannot collide across tenants/origins.
        let components = [origin, tenantID, userID]
        let key = (try? JSONEncoder().encode(components))?.base64EncodedString() ?? ""
        return "muxcore.userdata.scoped.v2.\(key)"
    }
}

@MainActor
protocol UserDataAPI: AnyObject {
    var sessionGeneration: UUID { get }
    func getUserdata() async throws -> APIClient.UserdataBlob
    func putUserdata(_ blob: APIClient.UserdataBlob) async throws -> APIClient.UserdataBlob
}

extension APIClient: UserDataAPI {}

enum UserDataSyncState: Equatable {
    case signedOut, pending, syncing, acknowledged, failed(String)

    var message: String {
        switch self {
        case .signedOut: return "Sign in to sync this account's data."
        case .pending: return "Changes saved on this device. Waiting to sync."
        case .syncing: return "Syncing with your server…"
        case .acknowledged: return "Last sync acknowledged by your server."
        case .failed(let message): return message
        }
    }
}

/// Foundation-only production state machine, also used by the observable iOS store.
/// All work is main-actor serialized, including edits made while network requests suspend.
@MainActor
class UserDataSync {
    private enum Field: String, Codable { case progress, favorites, prefs, playlists, queue }
    private struct Record: Codable {
        var blob = APIClient.UserdataBlob()
        var dirty: Set<Field> = []
        var removedFavorites: Set<String> = []
        var preferencePatch: Data?
        var dirtyProgress: Set<String> = []
        var dirtyFavorites: Set<String> = []
    }

    private let api: UserDataAPI
    private let defaults: UserDefaults
    private let automaticallySync: Bool
    private var record = Record()
    private(set) var scope: UserDataScope?
    private var generation = UUID()
    private var activeSync: UUID?
    private var storageUnavailable = false
    private(set) var revision = 0
    private(set) var syncState: UserDataSyncState = .signedOut
    var preferences: UserPreferences { record.blob.prefs ?? .defaults }
    var hasPendingChanges: Bool { !record.dirty.isEmpty }
    var isSyncing: Bool { activeSync != nil }

    init(api: UserDataAPI, defaults: UserDefaults = .standard, automaticallySync: Bool = true) {
        self.api = api
        self.defaults = defaults
        self.automaticallySync = automaticallySync
    }

    // The UI wrapper publishes changes; tests exercise this same implementation.
    func didChange() {}

    func activate(_ scope: UserDataScope?) {
        generation = UUID()
        self.scope = scope
        record = Record()
        storageUnavailable = false
        if let scope, let data = defaults.data(forKey: scope.storageKey) {
            do { record = try JSONDecoder().decode(Record.self, from: data) }
            catch { storageUnavailable = true }
        }
        // Global v1 caches have no provable owner: preserve them, never read or upload them.
        syncState = storageUnavailable
            ? .failed("Saved data could not be read. Sync is paused to preserve it on this device.")
            : (scope == nil ? .signedOut : .pending)
        revision += 1
        didChange()
    }

    func listProgress() -> [ProgressEntry] {
        (record.blob.progress ?? [:]).values.sorted { $0.updatedAt > $1.updatedAt }
    }
    func getProgress(id: String) -> ProgressEntry? { record.blob.progress?[id] }
    func upsertProgress(_ entry: ProgressEntry) {
        guard scope != nil, !storageUnavailable else { return }
        var next = entry
        if next.updatedAt.isEmpty { next.updatedAt = ISO8601DateFormatter().string(from: Date()) }
        if entry.watched == nil, next.durationSec > 0, next.positionSec / next.durationSec >= 0.92 {
            next.watched = true
            next.positionSec = 0
        } else if entry.watched == true { next.positionSec = 0 }
        var map = record.blob.progress ?? [:]
        map[next.id] = next
        record.blob.progress = map
        record.dirtyProgress.insert(next.id)
        changed(.progress)
    }
    func markWatched(id: String, watched: Bool) {
        guard var entry = getProgress(id: id) else { return }
        entry.watched = watched
        entry.updatedAt = ISO8601DateFormatter().string(from: Date())
        upsertProgress(entry)
    }
    func continueWatching(limit: Int = 24) -> [ProgressEntry] {
        Array(listProgress().filter {
            $0.watched != true && $0.positionSec > 5 && ($0.durationSec <= 0 || $0.positionSec / $0.durationSec < 0.92)
        }.prefix(limit))
    }
    func listFavorites() -> [FavoriteEntry] {
        (record.blob.favorites ?? [:]).values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    func isFavorite(id: String) -> Bool { record.blob.favorites?[id] != nil }
    @discardableResult
    func toggleFavorite(_ entry: FavoriteEntry) -> Bool {
        guard scope != nil, !storageUnavailable else { return false }
        var map = record.blob.favorites ?? [:]
        if map.removeValue(forKey: entry.id) != nil {
            record.removedFavorites.insert(entry.id)
            record.dirtyFavorites.remove(entry.id)
        } else {
            map[entry.id] = entry
            record.removedFavorites.remove(entry.id)
            record.dirtyFavorites.insert(entry.id)
        }
        record.blob.favorites = map
        changed(.favorites)
        return map[entry.id] != nil
    }
    func updatePreferences(_ patch: (inout UserPreferences) -> Void) {
        guard scope != nil, !storageUnavailable else { return }
        var next = preferences
        patch(&next)
        do {
            let before = try preferencesObject(preferences)
            let after = try preferencesObject(next)
            let difference = Self.preferenceDifference(before, after)
            guard !difference.isEmpty else { return }
            let prior = try record.preferencePatch.map { try JSONSerialization.jsonObject(with: $0) as? [String: Any] ?? [:] } ?? [:]
            record.preferencePatch = try JSONSerialization.data(withJSONObject: APIClient.overlay(prior, difference))
            record.blob.prefs = next
            changed(.prefs)
        } catch {
            syncState = .failed("Could not save preference changes on this device.")
            didChange()
        }
    }
    func listPlaylists() -> [Playlist] { record.blob.playlists ?? [] }
    func savePlaylists(_ list: [Playlist]) {
        guard scope != nil, !storageUnavailable else { return }
        record.blob.playlists = list
        changed(.playlists)
    }
    func listQueue() -> [QueueItem] { record.blob.queue ?? [] }
    func enqueue(_ item: QueueItem) { saveQueue(listQueue().filter { $0.id != item.id } + [item]) }
    func dequeue(id: String) { saveQueue(listQueue().filter { $0.id != id }) }
    func clearQueue() { saveQueue([]) }
    private func saveQueue(_ list: [QueueItem]) {
        guard scope != nil, !storageUnavailable else { return }
        record.blob.queue = list
        changed(.queue)
    }

    private func changed(_ field: Field) {
        record.dirty.insert(field)
        revision += 1
        syncState = .pending
        guard persist() else { didChange(); return }
        didChange()
        // Capture before scheduling so an old account's queued task cannot sync a new account.
        let epoch = generation
        if automaticallySync {
            Task { [weak self] in
                guard let self, self.generation == epoch else { return }
                await self.synchronize()
            }
        }
    }

    func pullFromServer() async { await synchronize() }
    func pushToServer() async { await synchronize() }

    func synchronize() async {
        guard let scope, !storageUnavailable, activeSync == nil else { return }
        let epoch = generation
        let session = api.sessionGeneration
        let operation = UUID()
        activeSync = operation
        syncState = .syncing
        didChange()
        defer {
            if activeSync == operation {
                activeSync = nil
                didChange()
                // Wait for the old network write to drain even across logout/re-login to the same account.
                // Generation checks protect local state; this barrier also prevents writes overtaking each other.
                if generation != epoch, self.scope != nil, automaticallySync {
                    Task { [weak self] in await self?.synchronize() }
                }
            }
        }
        func isCurrent() -> Bool { generation == epoch && api.sessionGeneration == session }
        do {
            var refreshRequired = true
            repeat {
                // The provider defaults omitted replaceable sections. Refresh and send their
                // merged values, including again before draining edits made during a prior PUT.
                if refreshRequired {
                    let remote = try await api.getUserdata()
                    guard isCurrent() else { return }
                    try validate(remote, scope: scope)
                    let beforePull = record
                    apply(remote)
                    guard persist() else { record = beforePull; didChange(); return }
                    refreshRequired = false
                }
                guard !record.dirty.isEmpty else {
                    syncState = .acknowledged
                    revision += 1
                    didChange()
                    return
                }
                let sentRevision = revision
                let fields = record.dirty.union([.prefs, .playlists, .queue])
                let patch = pendingPatch()
                let response = try await api.putUserdata(patch)
                guard isCurrent() else { return }
                try validate(response, scope: scope)
                // A response to an older edit must never replace newer local data or clear its dirty bit.
                guard revision == sentRevision else { refreshRequired = true; continue }
                if fields.contains(.favorites), record.removedFavorites.contains(where: { response.favorites?[$0] != nil }) {
                    throw APIError.badResponse("Your server has not confirmed favorite removal. The change remains pending on this device.")
                }
                // A malformed/partial success must not acknowledge a write it does not contain.
                try validateAcknowledgement(response, patch: patch, fields: fields)
                let beforeAcknowledgement = record
                record.dirty.subtract(fields)
                record.removedFavorites.removeAll()
                record.preferencePatch = nil
                record.dirtyProgress.removeAll()
                record.dirtyFavorites.removeAll()
                apply(response)
                guard persist() else { record = beforeAcknowledgement; didChange(); return }
            } while isCurrent()
        } catch {
            guard isCurrent() else { return }
            let detail: String
            if let error = error as? APIError { detail = error.localizedDescription }
            else { detail = "Cannot reach your server. Retry when your connection is available." }
            syncState = .failed(hasPendingChanges ? "\(detail) Changes remain on this device." : detail)
            didChange()
        }
    }

    private func validate(_ blob: APIClient.UserdataBlob, scope: UserDataScope) throws {
        guard blob.userID == scope.userID, (blob.tenantID ?? "") == scope.tenantID else {
            throw APIError.badResponse("The server returned data for a different account. Sign in again.")
        }
    }

    private func pendingPatch() -> APIClient.UserdataBlob {
        APIClient.UserdataBlob(
            progress: record.dirty.contains(.progress) ? (record.blob.progress ?? [:]).filter { record.dirtyProgress.contains($0.key) } : nil,
            favorites: record.dirty.contains(.favorites) ? (record.blob.favorites ?? [:]).filter { record.dirtyFavorites.contains($0.key) } : nil,
            prefs: preferences,
            playlists: listPlaylists(),
            queue: listQueue(),
            rawPrefs: record.blob.rawPrefs
        )
    }

    private func validateAcknowledgement(_ response: APIClient.UserdataBlob, patch: APIClient.UserdataBlob, fields: Set<Field>) throws {
        let progressMatches = (patch.progress ?? [:]).allSatisfy { response.progress?[$0.key] == $0.value }
        let favoritesMatch = (patch.favorites ?? [:]).allSatisfy { response.favorites?[$0.key] == $0.value }
        guard (!fields.contains(.progress) || progressMatches),
              (!fields.contains(.favorites) || favoritesMatch),
              (!fields.contains(.prefs) || response.prefs == patch.prefs),
              (!fields.contains(.playlists) || (response.playlists ?? []) == patch.playlists),
              (!fields.contains(.queue) || (response.queue ?? []) == patch.queue) else {
            throw APIError.badResponse("Your server has not confirmed all changes. Retry sync.")
        }
    }

    private func apply(_ remote: APIClient.UserdataBlob) {
        var progress = remote.progress ?? [:]
        for id in record.dirtyProgress { progress[id] = record.blob.progress?[id] }
        record.blob.progress = progress
        var favorites = remote.favorites ?? [:]
        for id in record.dirtyFavorites { favorites[id] = record.blob.favorites?[id] }
        for id in record.removedFavorites { favorites.removeValue(forKey: id) }
        record.blob.favorites = favorites
        if !record.dirty.contains(.prefs) { record.blob.prefs = remote.prefs }
        else if let data = record.preferencePatch,
                let patch = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let base = try? preferencesObject(remote.prefs ?? .defaults),
                let merged = try? JSONSerialization.data(withJSONObject: APIClient.overlay(base, patch)),
                let prefs = try? JSONDecoder().decode(UserPreferences.self, from: merged) {
            record.blob.prefs = prefs
        }
        if !record.dirty.contains(.playlists) { record.blob.playlists = remote.playlists }
        if !record.dirty.contains(.queue) { record.blob.queue = remote.queue }
        record.blob.rawPrefs = remote.rawPrefs
        revision += 1
        didChange()
    }

    private func preferencesObject(_ prefs: UserPreferences) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(prefs)) as? [String: Any] ?? [:]
    }

    private static func preferenceDifference(_ before: [String: Any], _ after: [String: Any]) -> [String: Any] {
        var changes: [String: Any] = [:]
        for (key, value) in after {
            if let old = before[key] as? [String: Any], let new = value as? [String: Any] {
                let nested = preferenceDifference(old, new)
                if !nested.isEmpty { changes[key] = nested }
            } else if (before[key] as? NSObject)?.isEqual(value) != true {
                changes[key] = value
            }
        }
        return changes
    }

    @discardableResult
    private func persist() -> Bool {
        guard let scope, !storageUnavailable else { return false }
        do {
            defaults.set(try JSONEncoder().encode(record), forKey: scope.storageKey)
            return true
        } catch {
            syncState = .failed("Could not save changes on this device. Retry sync.")
            didChange()
            return false
        }
    }
}
