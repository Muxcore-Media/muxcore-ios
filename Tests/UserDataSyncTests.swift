import XCTest
@testable import MuxCoreKit

@MainActor
private final class FixtureUserDataAPI: UserDataAPI {
    var sessionGeneration = UUID()
    var gets = 0
    var writes: [APIClient.UserdataBlob] = []
    var get: () async throws -> APIClient.UserdataBlob = { APIClient.UserdataBlob(userID: "alice", tenantID: "home") }
    var put: (APIClient.UserdataBlob) async throws -> APIClient.UserdataBlob = { blob in
        var response = blob
        response.userID = "alice"
        response.tenantID = "home"
        return response
    }
    func getUserdata() async throws -> APIClient.UserdataBlob { gets += 1; return try await get() }
    func putUserdata(_ blob: APIClient.UserdataBlob) async throws -> APIClient.UserdataBlob {
        writes.append(blob)
        return try await put(blob)
    }
}

final class UserDataSyncTests: XCTestCase {
    private let alice = UserDataScope(origin: "https://fixture.invalid:443", userID: "alice", tenantID: "home")
    private func queue(_ id: String) -> QueueItem { QueueItem(id: id, kind: .movie, title: id, href: "/movies/\(id)") }
    private func favorite(_ id: String) -> FavoriteEntry { FavoriteEntry(id: id, kind: .movie, title: id, href: "/movies/\(id)") }
    private func progress(_ id: String) -> ProgressEntry {
        ProgressEntry(id: id, kind: .movie, title: id, href: "/movies/\(id)", positionSec: 21, durationSec: 100,
                      updatedAt: "2026-10-08T12:00:00Z", watched: false)
    }
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "fixture.\(UUID())")! }

    @MainActor func testOfflinePendingDataSurvivesRelaunchAndRetries() async {
        let api = FixtureUserDataAPI()
        let storage = defaults()
        let store = UserDataSync(api: api, defaults: storage, automaticallySync: false)
        store.activate(alice)
        store.enqueue(queue("first"))
        api.get = { throw URLError(.notConnectedToInternet) }
        await store.synchronize()
        XCTAssertTrue(store.hasPendingChanges)
        XCTAssertNotEqual(store.syncState, .acknowledged)
        let relaunched = UserDataSync(api: api, defaults: storage, automaticallySync: false)
        relaunched.activate(alice)
        XCTAssertEqual(relaunched.listQueue().map(\.id), ["first"])
        XCTAssertTrue(relaunched.hasPendingChanges)
        api.get = { APIClient.UserdataBlob(userID: "alice", tenantID: "home") }
        await relaunched.synchronize()
        XCTAssertFalse(relaunched.hasPendingChanges)
        XCTAssertEqual(relaunched.syncState, .acknowledged)
        XCTAssertEqual(api.writes.first?.queue?.map(\.id), ["first"])
        XCTAssertEqual(api.writes.first?.prefs, .defaults)
    }

    @MainActor func testEveryDataCategoryCanBeAcknowledgedAndRestored() async {
        let api = FixtureUserDataAPI()
        let storage = defaults()
        let store = UserDataSync(api: api, defaults: storage, automaticallySync: false)
        store.activate(alice)
        store.upsertProgress(progress("movie"))
        store.markWatched(id: "movie", watched: true)
        store.toggleFavorite(favorite("movie"))
        store.savePlaylists([Playlist(id: "p", name: "P", itemIds: ["movie"])])
        store.enqueue(queue("movie"))
        store.updatePreferences { $0.display.theme = .light }
        await store.synchronize()
        XCTAssertEqual(store.syncState, .acknowledged)
        XCTAssertFalse(store.hasPendingChanges)
        let restored = UserDataSync(api: api, defaults: storage, automaticallySync: false)
        restored.activate(alice)
        XCTAssertEqual(restored.getProgress(id: "movie")?.watched, true)
        XCTAssertEqual(restored.getProgress(id: "movie")?.positionSec, 0)
        XCTAssertTrue(restored.isFavorite(id: "movie"))
        XCTAssertEqual(restored.listPlaylists().first?.itemIds, ["movie"])
        XCTAssertEqual(restored.listQueue().first?.id, "movie")
        XCTAssertEqual(restored.preferences.display.theme, .light)
    }

    @MainActor func testInFlightWriteCannotLoseNewerEditOrStartParallelWrite() async {
        let api = FixtureUserDataAPI()
        let store = UserDataSync(api: api, defaults: defaults(), automaticallySync: false)
        store.activate(alice)
        store.enqueue(queue("first"))
        let started = expectation(description: "first PUT started")
        var release: CheckedContinuation<Void, Never>?
        api.put = { blob in
            if api.writes.count == 1 {
                await withCheckedContinuation { release = $0; started.fulfill() }
            }
            var response = blob; response.userID = "alice"; response.tenantID = "home"
            return response
        }
        let operation = Task { await store.synchronize() }
        await fulfillment(of: [started], timeout: 1)
        store.enqueue(queue("second"))
        await store.synchronize()
        XCTAssertEqual(api.writes.count, 1)
        release?.resume()
        await operation.value
        XCTAssertEqual(api.writes.count, 2)
        XCTAssertEqual(api.writes.last?.queue?.map(\.id), ["first", "second"])
        XCTAssertEqual(store.listQueue().map(\.id), ["first", "second"])
        XCTAssertFalse(store.hasPendingChanges)
    }

    @MainActor func testDelayedPullPreservesNewLocalEdit() async {
        let api = FixtureUserDataAPI()
        let store = UserDataSync(api: api, defaults: defaults(), automaticallySync: false)
        store.activate(alice)
        let started = expectation(description: "GET started")
        var release: CheckedContinuation<Void, Never>?
        api.get = {
            await withCheckedContinuation { release = $0; started.fulfill() }
            return APIClient.UserdataBlob(queue: [], userID: "alice", tenantID: "home")
        }
        let operation = Task { await store.pullFromServer() }
        await fulfillment(of: [started], timeout: 1)
        store.enqueue(queue("local"))
        release?.resume()
        await operation.value
        XCTAssertEqual(store.listQueue().map(\.id), ["local"])
        XCTAssertEqual(api.writes.first?.queue?.map(\.id), ["local"])
    }

    @MainActor func testAccountSwitchAndLogoutIgnoreInFlightWriteAndPreserveOldPending() async {
        let api = FixtureUserDataAPI()
        let storage = defaults()
        let store = UserDataSync(api: api, defaults: storage, automaticallySync: false)
        store.activate(alice)
        store.enqueue(queue("alice-only"))
        let started = expectation(description: "PUT started")
        var release: CheckedContinuation<Void, Never>?
        api.put = { blob in
            await withCheckedContinuation { release = $0; started.fulfill() }
            var response = blob; response.userID = "alice"; response.tenantID = "home"
            return response
        }
        let operation = Task { await store.synchronize() }
        await fulfillment(of: [started], timeout: 1)
        store.activate(nil)
        api.sessionGeneration = UUID()
        store.activate(UserDataScope(origin: alice.origin, userID: "bob", tenantID: "home"))
        release?.resume()
        await operation.value
        XCTAssertTrue(store.listQueue().isEmpty)
        XCTAssertNotEqual(store.syncState, .acknowledged)
        XCTAssertEqual(api.writes.count, 1)
        store.activate(alice)
        XCTAssertEqual(store.listQueue().map(\.id), ["alice-only"])
        XCTAssertTrue(store.hasPendingChanges)
    }

    @MainActor func testScopeIsolationAndLegacyCacheQuarantine() async {
        let api = FixtureUserDataAPI()
        let storage = defaults()
        let legacy = Data("legacy ownerless data".utf8)
        storage.set(legacy, forKey: "muxcore.userdata.queue.v1")
        let store = UserDataSync(api: api, defaults: storage, automaticallySync: false)
        store.activate(alice)
        XCTAssertTrue(store.listQueue().isEmpty)
        store.enqueue(queue("alice"))
        for scope in [UserDataScope(origin: alice.origin, userID: "bob", tenantID: "home"),
                      UserDataScope(origin: alice.origin, userID: "alice", tenantID: "other"),
                      UserDataScope(origin: "https://elsewhere.invalid:443", userID: "alice", tenantID: "home")] {
            store.activate(scope)
            XCTAssertTrue(store.listQueue().isEmpty)
            XCTAssertFalse(store.hasPendingChanges)
        }
        store.activate(nil)
        store.enqueue(queue("signed-out"))
        XCTAssertTrue(store.listQueue().isEmpty)
        XCTAssertEqual(storage.data(forKey: "muxcore.userdata.queue.v1"), legacy)
        store.activate(alice)
        XCTAssertEqual(store.listQueue().map(\.id), ["alice"])
    }

    @MainActor func testHTTPAndDecodeErrorsPreservePendingAndRemainVisible() async {
        for error in [APIError.unauthorized, .badResponse("Server request failed (HTTP 403)."),
                      .badResponse("Server request failed (HTTP 503)."), .decodingFailed] {
            let api = FixtureUserDataAPI()
            let store = UserDataSync(api: api, defaults: defaults(), automaticallySync: false)
            store.activate(alice)
            store.enqueue(queue("pending"))
            api.put = { _ in throw error }
            await store.synchronize()
            XCTAssertTrue(store.hasPendingChanges)
            XCTAssertEqual(store.listQueue().map(\.id), ["pending"])
            guard case .failed = store.syncState else { XCTFail("Failure was hidden"); continue }
            api.put = { blob in var out = blob; out.userID = "alice"; out.tenantID = "home"; return out }
            await store.synchronize()
            XCTAssertEqual(store.syncState, .acknowledged)
        }
    }

    @MainActor func testWrongAccountResponseCannotPopulateCacheOrTriggerWrite() async {
        let api = FixtureUserDataAPI()
        let store = UserDataSync(api: api, defaults: defaults(), automaticallySync: false)
        store.activate(alice)
        store.enqueue(queue("local"))
        api.get = { APIClient.UserdataBlob(userID: "bob", tenantID: "home") }
        await store.synchronize()
        XCTAssertTrue(api.writes.isEmpty)
        XCTAssertTrue(store.hasPendingChanges)
        XCTAssertNotEqual(store.syncState, .acknowledged)
    }

    @MainActor func testFavoriteRemovalIsNotFalselyAcknowledgedByUnionServer() async {
        let api = FixtureUserDataAPI()
        let entry = favorite("movie")
        api.get = { APIClient.UserdataBlob(favorites: ["movie": entry], userID: "alice", tenantID: "home") }
        api.put = { _ in APIClient.UserdataBlob(favorites: ["movie": entry], userID: "alice", tenantID: "home") }
        let store = UserDataSync(api: api, defaults: defaults(), automaticallySync: false)
        store.activate(alice)
        await store.synchronize()
        XCTAssertFalse(store.toggleFavorite(entry))
        await store.synchronize()
        XCTAssertFalse(store.isFavorite(id: "movie"))
        XCTAssertTrue(store.hasPendingChanges)
        guard case .failed(let detail) = store.syncState else { return XCTFail("Removal falsely acknowledged") }
        XCTAssertTrue(detail.contains("favorite removal"))
    }

    @MainActor func testPartialSuccessCannotClearPendingWrite() async {
        let api = FixtureUserDataAPI()
        api.put = { _ in APIClient.UserdataBlob(userID: "alice", tenantID: "home") }
        let store = UserDataSync(api: api, defaults: defaults(), automaticallySync: false)
        store.activate(alice)
        store.enqueue(queue("pending"))
        await store.synchronize()
        XCTAssertTrue(store.hasPendingChanges)
        XCTAssertNotEqual(store.syncState, .acknowledged)
    }
    @MainActor func testCorruptScopedCacheIsPreservedAndSyncPaused() async {
        let api = FixtureUserDataAPI()
        let storage = defaults()
        let corrupt = Data("unreadable pending record".utf8)
        storage.set(corrupt, forKey: alice.storageKey)
        let store = UserDataSync(api: api, defaults: storage, automaticallySync: false)
        store.activate(alice)
        store.enqueue(queue("must-not-overwrite"))
        await store.synchronize()
        XCTAssertEqual(storage.data(forKey: alice.storageKey), corrupt)
        XCTAssertEqual(api.gets, 0)
        XCTAssertTrue(api.writes.isEmpty)
        guard case .failed(let detail) = store.syncState else { return XCTFail("Corruption was hidden") }
        XCTAssertTrue(detail.contains("preserve"))
    }

    @MainActor func testSameAccountRebindWaitsForOldWriteToDrain() async {
        let api = FixtureUserDataAPI()
        let store = UserDataSync(api: api, defaults: defaults(), automaticallySync: false)
        store.activate(alice)
        store.enqueue(queue("first"))
        let started = expectation(description: "old PUT started")
        var release: CheckedContinuation<Void, Never>?
        api.put = { blob in
            if api.writes.count == 1 { await withCheckedContinuation { release = $0; started.fulfill() } }
            var result = blob; result.userID = "alice"; result.tenantID = "home"; return result
        }
        let old = Task { await store.synchronize() }
        await fulfillment(of: [started], timeout: 1)
        store.activate(nil)
        api.sessionGeneration = UUID()
        store.activate(alice)
        store.enqueue(queue("second"))
        await store.synchronize()
        XCTAssertEqual(api.writes.count, 1)
        XCTAssertTrue(store.isSyncing)
        release?.resume()
        await old.value
        XCTAssertTrue(store.hasPendingChanges)
        await store.synchronize()
        XCTAssertEqual(api.writes.count, 2)
        XCTAssertEqual(api.writes.last?.queue?.map(\.id), ["first", "second"])
        XCTAssertEqual(store.syncState, .acknowledged)
    }

    @MainActor func testAcknowledgementPersistenceFailureKeepsDirtyIntent() async {
        let api = FixtureUserDataAPI()
        let storage = defaults()
        let store = UserDataSync(api: api, defaults: storage, automaticallySync: false)
        store.activate(alice)
        store.enqueue(queue("pending"))
        var invalid = progress("unencodable")
        invalid.positionSec = .nan
        api.put = { blob in
            var result = blob; result.userID = "alice"; result.tenantID = "home"
            result.progress = ["unencodable": invalid]
            return result
        }
        await store.synchronize()
        XCTAssertTrue(store.hasPendingChanges)
        XCTAssertNotEqual(store.syncState, .acknowledged)
        let relaunched = UserDataSync(api: api, defaults: storage, automaticallySync: false)
        relaunched.activate(alice)
        XCTAssertTrue(relaunched.hasPendingChanges)
        XCTAssertEqual(relaunched.listQueue().map(\.id), ["pending"])
    }

    @MainActor func testOfflinePreferenceEditPreservesOtherServerPreferences() async {
        let api = FixtureUserDataAPI()
        var serverPrefs = UserPreferences.defaults
        serverPrefs.playback.skipIntroSec = 42
        serverPrefs.display.libraryPageSize = 100
        api.get = { APIClient.UserdataBlob(prefs: serverPrefs, userID: "alice", tenantID: "home") }
        let store = UserDataSync(api: api, defaults: defaults(), automaticallySync: false)
        store.activate(alice)
        store.updatePreferences { $0.display.theme = .light }
        await store.synchronize()
        XCTAssertEqual(api.writes.last?.prefs?.display.theme, .light)
        XCTAssertEqual(api.writes.last?.prefs?.display.libraryPageSize, 100)
        XCTAssertEqual(api.writes.last?.prefs?.playback.skipIntroSec, 42)
        XCTAssertEqual(store.syncState, .acknowledged)
    }

    @MainActor func testInFlightPullFromOldAccountIsDiscarded() async {
        let api = FixtureUserDataAPI()
        let store = UserDataSync(api: api, defaults: defaults(), automaticallySync: false)
        store.activate(alice)
        let started = expectation(description: "old GET started")
        var release: CheckedContinuation<Void, Never>?
        api.get = {
            await withCheckedContinuation { release = $0; started.fulfill() }
            return APIClient.UserdataBlob(queue: [self.queue("alice-only")], userID: "alice", tenantID: "home")
        }
        let old = Task { await store.synchronize() }
        await fulfillment(of: [started], timeout: 1)
        store.activate(UserDataScope(origin: alice.origin, userID: "bob", tenantID: "home"))
        api.sessionGeneration = UUID()
        release?.resume()
        await old.value
        XCTAssertTrue(store.listQueue().isEmpty)
        XCTAssertTrue(api.writes.isEmpty)
        XCTAssertNotEqual(store.syncState, .acknowledged)
    }

    @MainActor func testWrongTenantResponseFailsClosed() async {
        let api = FixtureUserDataAPI()
        api.get = { APIClient.UserdataBlob(userID: "alice", tenantID: "other-household") }
        let store = UserDataSync(api: api, defaults: defaults(), automaticallySync: false)
        store.activate(alice)
        store.enqueue(queue("local"))
        await store.synchronize()
        XCTAssertTrue(store.hasPendingChanges)
        XCTAssertTrue(api.writes.isEmpty)
        XCTAssertNotEqual(store.syncState, .acknowledged)
    }

    @MainActor func testClearedCollectionsCanBeOmittedByProviderOmitempty() async {
        let api = FixtureUserDataAPI()
        api.get = { APIClient.UserdataBlob(playlists: [Playlist(id: "p", name: "P", itemIds: [])],
                                         queue: [self.queue("old")], userID: "alice", tenantID: "home") }
        api.put = { _ in APIClient.UserdataBlob(prefs: .defaults, userID: "alice", tenantID: "home") }
        let store = UserDataSync(api: api, defaults: defaults(), automaticallySync: false)
        store.activate(alice)
        await store.synchronize()
        store.clearQueue()
        store.savePlaylists([])
        await store.synchronize()
        XCTAssertEqual(api.writes.last?.queue, [])
        XCTAssertEqual(api.writes.last?.playlists, [])
        XCTAssertEqual(store.syncState, .acknowledged)
        XCTAssertFalse(store.hasPendingChanges)
        XCTAssertTrue(store.listQueue().isEmpty)
        XCTAssertTrue(store.listPlaylists().isEmpty)
    }

    @MainActor func testProviderDefaultingOmittedSectionsCannotResetUntouchedData() async {
        let api = FixtureUserDataAPI()
        var prefs = UserPreferences.defaults
        prefs.playback.skipIntroSec = 45
        let playlist = Playlist(id: "kept", name: "Kept", itemIds: ["movie"])
        let queued = queue("kept")
        api.get = { APIClient.UserdataBlob(prefs: prefs, playlists: [playlist], queue: [queued], userID: "alice", tenantID: "home") }
        api.put = { blob in
            // Mirror internal/store.ParseBlob: absent replaceable sections become defaults/empty.
            APIClient.UserdataBlob(progress: blob.progress, favorites: blob.favorites,
                                   prefs: blob.prefs ?? .defaults, playlists: blob.playlists ?? [],
                                   queue: blob.queue ?? [], userID: "alice", tenantID: "home")
        }
        let store = UserDataSync(api: api, defaults: defaults(), automaticallySync: false)
        store.activate(alice)
        store.upsertProgress(progress("edited"))
        await store.synchronize()
        XCTAssertEqual(api.writes.last?.prefs?.playback.skipIntroSec, 45)
        XCTAssertEqual(api.writes.last?.playlists, [playlist])
        XCTAssertEqual(api.writes.last?.queue, [queued])
        XCTAssertNil(api.writes.last?.favorites)
        XCTAssertEqual(store.preferences.playback.skipIntroSec, 45)
        XCTAssertEqual(store.listPlaylists(), [playlist])
        XCTAssertEqual(store.listQueue(), [queued])
        XCTAssertEqual(store.syncState, .acknowledged)
    }

    @MainActor func testOnlyDirtyMapEntriesReachProviderAndRemoteOtherEntriesSurvive() async {
        let api = FixtureUserDataAPI()
        var remoteProgress = ["other": progress("other")]
        var remoteFavorites = ["other": favorite("other")]
        api.get = { APIClient.UserdataBlob(progress: remoteProgress, favorites: remoteFavorites,
                                         userID: "alice", tenantID: "home") }
        api.put = { blob in
            // Model the provider's unconditional incoming progress assignment after MergeProgress.
            for (id, entry) in blob.progress ?? [:] { remoteProgress[id] = entry }
            for (id, entry) in blob.favorites ?? [:] { remoteFavorites[id] = entry }
            return APIClient.UserdataBlob(progress: remoteProgress, favorites: remoteFavorites, prefs: blob.prefs,
                                          playlists: blob.playlists, queue: blob.queue, userID: "alice", tenantID: "home")
        }
        let store = UserDataSync(api: api, defaults: defaults(), automaticallySync: false)
        store.activate(alice)
        await store.synchronize()
        remoteProgress["other"]?.positionSec = 65
        remoteProgress["other"]?.updatedAt = "2026-10-08T13:00:00Z"
        remoteFavorites["other"]?.title = "Updated elsewhere"
        store.upsertProgress(progress("edited"))
        store.toggleFavorite(favorite("edited"))
        await store.synchronize()
        XCTAssertEqual(Set(api.writes.last?.progress?.keys ?? Dictionary<String, ProgressEntry>().keys), ["edited"])
        XCTAssertEqual(Set(api.writes.last?.favorites?.keys ?? Dictionary<String, FavoriteEntry>().keys), ["edited"])
        XCTAssertEqual(remoteProgress["other"]?.positionSec, 65)
        XCTAssertEqual(store.getProgress(id: "other")?.positionSec, 65)
        XCTAssertEqual(store.listFavorites().first(where: { $0.id == "other" })?.title, "Updated elsewhere")
        XCTAssertEqual(store.syncState, .acknowledged)
    }

}
