import Foundation

@MainActor
final class UserDataStore: ObservableObject {
    private let api: APIClient
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let progress = "muxcore.userdata.progress.v1"
        static let favorites = "muxcore.userdata.favorites.v1"
        static let prefs = "muxcore.userdata.prefs.v1"
        static let playlists = "muxcore.userdata.playlists.v1"
        static let queue = "muxcore.userdata.queue.v1"
        static let serverAuth = "muxcore.userdata.meta.serverAuth"
    }

    @Published private(set) var preferences: UserPreferences = .defaults
    @Published private(set) var revision = 0

    init(api: APIClient) {
        self.api = api
        preferences = readPrefs()
    }

    func bump() { revision += 1 }

    // MARK: - Progress

    func listProgress() -> [ProgressEntry] {
        let map = readMapProgress()
        return map.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func getProgress(id: String) -> ProgressEntry? {
        readMapProgress()[id]
    }

    func upsertProgress(_ entry: ProgressEntry) {
        var map = readMapProgress()
        var next = entry
        if next.updatedAt.isEmpty { next.updatedAt = ISO8601DateFormatter().string(from: Date()) }
        if entry.watched == nil {
            let ratio = next.durationSec > 0 ? next.positionSec / next.durationSec : 0
            if ratio >= 0.92 {
                next.watched = true
                next.positionSec = 0
            }
        } else if entry.watched == true {
            next.positionSec = 0
        }
        map[next.id] = next
        writeMapProgress(map)
        Task { await pushToServer() }
        bump()
    }

    func markWatched(id: String, watched: Bool) {
        var map = readMapProgress()
        guard var cur = map[id] else { return }
        cur.watched = watched
        if watched { cur.positionSec = 0 }
        cur.updatedAt = ISO8601DateFormatter().string(from: Date())
        map[id] = cur
        writeMapProgress(map)
        Task { await pushToServer() }
        bump()
    }

    func continueWatching(limit: Int = 24) -> [ProgressEntry] {
        listProgress().filter { entry in
            guard entry.watched != true else { return false }
            guard entry.positionSec > 5 else { return false }
            if entry.durationSec > 0 && entry.positionSec / entry.durationSec >= 0.92 { return false }
            return true
        }.prefix(limit).map { $0 }
    }

    // MARK: - Favorites

    func listFavorites() -> [FavoriteEntry] {
        readMapFavorites().values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func isFavorite(id: String) -> Bool {
        readMapFavorites()[id] != nil
    }

    @discardableResult
    func toggleFavorite(_ entry: FavoriteEntry) -> Bool {
        var map = readMapFavorites()
        if map[entry.id] != nil {
            map.removeValue(forKey: entry.id)
            writeMapFavorites(map)
            Task { await pushToServer() }
            bump()
            return false
        }
        map[entry.id] = entry
        writeMapFavorites(map)
        Task { await pushToServer() }
        bump()
        return true
    }

    // MARK: - Preferences

    func updatePreferences(_ patch: (inout UserPreferences) -> Void) {
        var next = preferences
        patch(&next)
        preferences = next
        defaults.set(try? JSONEncoder().encode(next), forKey: Keys.prefs)
        Task { await pushToServer() }
        bump()
    }

    // MARK: - Playlists

    func listPlaylists() -> [Playlist] {
        guard let data = defaults.data(forKey: Keys.playlists),
              let list = try? JSONDecoder().decode([Playlist].self, from: data)
        else { return [] }
        return list
    }

    func savePlaylists(_ list: [Playlist]) {
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: Keys.playlists)
        }
        Task { await pushToServer() }
        bump()
    }

    // MARK: - Queue

    func listQueue() -> [QueueItem] {
        guard let data = defaults.data(forKey: Keys.queue),
              let list = try? JSONDecoder().decode([QueueItem].self, from: data)
        else { return [] }
        return list
    }

    func enqueue(_ item: QueueItem) {
        let cur = listQueue().filter { $0.id != item.id }
        saveQueue(cur + [item])
    }

    func dequeue(id: String) {
        saveQueue(listQueue().filter { $0.id != id })
    }

    func clearQueue() {
        saveQueue([])
    }

    private func saveQueue(_ list: [QueueItem]) {
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: Keys.queue)
        }
        Task { await pushToServer() }
        bump()
    }

    // MARK: - Server sync

    func pullFromServer() async {
        do {
            let blob = try await api.getUserdata()
            if let progress = blob.progress {
                let local = readMapProgress()
                writeMapProgress(mergeProgress(local, progress))
            }
            if let favorites = blob.favorites {
                writeMapFavorites(favorites)
            }
            if let prefs = blob.prefs {
                preferences = prefs
                defaults.set(try? JSONEncoder().encode(prefs), forKey: Keys.prefs)
            }
            if let playlists = blob.playlists {
                defaults.set(try? JSONEncoder().encode(playlists), forKey: Keys.playlists)
            }
            if let queue = blob.queue {
                defaults.set(try? JSONEncoder().encode(queue), forKey: Keys.queue)
            }
            defaults.set(true, forKey: Keys.serverAuth)
            bump()
        } catch {
            defaults.set(false, forKey: Keys.serverAuth)
        }
    }

    func pushToServer() async {
        do {
            let merged = try await api.putUserdata(
                progress: readMapProgress(),
                favorites: readMapFavorites(),
                prefs: preferences,
                playlists: listPlaylists(),
                queue: listQueue()
            )
            if let progress = merged.progress { writeMapProgress(progress) }
            if let favorites = merged.favorites { writeMapFavorites(favorites) }
            if let prefs = merged.prefs {
                preferences = prefs
                defaults.set(try? JSONEncoder().encode(prefs), forKey: Keys.prefs)
            }
            if let playlists = merged.playlists {
                defaults.set(try? JSONEncoder().encode(playlists), forKey: Keys.playlists)
            }
            if let queue = merged.queue {
                defaults.set(try? JSONEncoder().encode(queue), forKey: Keys.queue)
            }
            defaults.set(true, forKey: Keys.serverAuth)
            bump()
        } catch {
            /* offline cache */
        }
    }

    // MARK: - Private helpers

    private func readPrefs() -> UserPreferences {
        guard let data = defaults.data(forKey: Keys.prefs),
              let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else { return .defaults }
        return prefs
    }

    private func readMapProgress() -> [String: ProgressEntry] {
        guard let data = defaults.data(forKey: Keys.progress),
              let map = try? JSONDecoder().decode([String: ProgressEntry].self, from: data)
        else { return [:] }
        return map
    }

    private func writeMapProgress(_ map: [String: ProgressEntry]) {
        defaults.set(try? JSONEncoder().encode(map), forKey: Keys.progress)
    }

    private func readMapFavorites() -> [String: FavoriteEntry] {
        guard let data = defaults.data(forKey: Keys.favorites),
              let map = try? JSONDecoder().decode([String: FavoriteEntry].self, from: data)
        else { return [:] }
        return map
    }

    private func writeMapFavorites(_ map: [String: FavoriteEntry]) {
        defaults.set(try? JSONEncoder().encode(map), forKey: Keys.favorites)
    }

    private func mergeProgress(_ local: [String: ProgressEntry], _ server: [String: ProgressEntry]) -> [String: ProgressEntry] {
        var out = local
        for (id, entry) in server {
            let cur = out[id]
            if cur == nil || entry.updatedAt >= cur!.updatedAt {
                out[id] = entry
            }
        }
        return out
    }
}
