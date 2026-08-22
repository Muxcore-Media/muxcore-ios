import Foundation

extension APIClient {
    // MARK: - Userdata

    struct UserdataBlob {
        var progress: [String: ProgressEntry]?
        var favorites: [String: FavoriteEntry]?
        var prefs: UserPreferences?
        var playlists: [Playlist]?
        var queue: [QueueItem]?
    }

    func getUserdata() async throws -> UserdataBlob {
        let raw = try await getJSON(path: "/api/userdata") as? [String: Any] ?? [:]
        return parseUserdataBlob(raw)
    }

    func putUserdata(
        progress: [String: ProgressEntry],
        favorites: [String: FavoriteEntry],
        prefs: UserPreferences,
        playlists: [Playlist],
        queue: [QueueItem]
    ) async throws -> UserdataBlob {
        let body: [String: Any] = [
            "progress": encodeMap(progress),
            "favorites": encodeMap(favorites),
            "prefs": encodePrefs(prefs),
            "playlists": playlists.map { ["id": $0.id, "name": $0.name, "itemIds": $0.itemIds] },
            "queue": queue.map { queueItemDict($0) },
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        let raw = try await getJSON(path: "/api/userdata", method: "PUT", body: data) as? [String: Any] ?? [:]
        return parseUserdataBlob(raw)
    }

    // MARK: - Discover & requests

    func getDiscoverDetail(type: SearchMediaType, id: Int) async throws -> DiscoverDetail {
        let path = "/api/discover/\(type == .tv ? "tv" : "movie")/\(id)"
        let raw = try await getJSON(path: path) as? [String: Any] ?? [:]
        return MediaNormalizer.discoverDetail(from: raw)
    }

    func requestTitle(
        tmdbId: Int,
        title: String,
        year: Int,
        overview: String,
        poster: String,
        mediaType: SearchMediaType
    ) async throws -> [String: Any] {
        let body: [String: Any] = [
            "tmdbId": tmdbId,
            "title": title,
            "year": year,
            "overview": overview,
            "poster": poster,
            "mediaType": mediaType == .tv ? "tv" : "movie",
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        return try await getJSON(path: "/api/request", method: "POST", body: data) as? [String: Any] ?? [:]
    }

    func listRequests() async throws -> [MediaRequest] {
        let raw = try await getJSON(path: "/api/requests")
        if let array = raw as? [Any] {
            return array.compactMap { item -> MediaRequest? in
                guard let dict = item as? [String: Any] else { return nil }
                return MediaNormalizer.mediaRequest(from: dict)
            }
        }
        return []
    }

    // MARK: - Collections

    func listCollections() async throws -> [CollectionSummary] {
        let raw = try await getJSON(path: "/api/collections") as? [String: Any] ?? [:]
        let rows = JSONHelpers.dictArray(raw["items"])
        return rows.map { dict in
            CollectionSummary(
                id: JSONHelpers.string(dict, keys: ["id"]),
                name: JSONHelpers.string(dict, keys: ["name"]),
                movieCount: JSONHelpers.int(dict, keys: ["movie_count", "movieCount"])
            )
        }
    }

    func getCollection(id: String) async throws -> (id: String, name: String, movies: [Movie]) {
        let raw = try await getJSON(path: "/api/collections/\(id)") as? [String: Any] ?? [:]
        let movies = JSONHelpers.dictArray(raw["movies"]).map { MediaNormalizer.movie(from: $0, serverBase: serverBase) }
        return (
            JSONHelpers.string(raw, keys: ["id"]),
            JSONHelpers.string(raw, keys: ["name"]),
            movies
        )
    }

    // MARK: - Libraries

    func listLibrary(path: String) async throws -> LibraryListResponse {
        let raw = try await getJSON(path: path) as? [String: Any] ?? [:]
        return MediaNormalizer.libraryList(from: raw)
    }

    func listMusic() async throws -> LibraryListResponse { try await listLibrary(path: "/api/music") }
    func listBooks() async throws -> LibraryListResponse { try await listLibrary(path: "/api/books") }
    func listComics() async throws -> LibraryListResponse { try await listLibrary(path: "/api/comics") }
    func listAudiobooks() async throws -> LibraryListResponse { try await listLibrary(path: "/api/audiobooks") }

    func listMoviesLibrary(library: String, page: Int = 1, pageSize: Int = 48) async throws -> ListResponse<Movie> {
        let path = "/api/movies?page=\(page)&page_size=\(pageSize)&library=\(library)"
        let data = try await getJSON(path: path)
        return MediaNormalizer.listMovies(from: data, serverBase: serverBase)
    }

    func getMusicArtist(id: String) async throws -> MusicArtistDetail {
        let raw = try await getJSON(path: "/api/music/\(id)") as? [String: Any] ?? [:]
        return MediaNormalizer.musicArtist(from: raw, serverBase: serverBase)
    }

    func getTrackLyrics(trackId: String) async throws -> TrackLyrics {
        let raw = try await getJSON(path: "/api/music/tracks/\(trackId)/lyrics") as? [String: Any] ?? [:]
        return TrackLyrics(
            found: raw["found"] as? Bool ?? false,
            text: JSONHelpers.string(raw, keys: ["text"]),
            title: JSONHelpers.string(raw, keys: ["title"]).isEmpty ? nil : JSONHelpers.string(raw, keys: ["title"]),
            format: JSONHelpers.string(raw, keys: ["format"]).isEmpty ? nil : JSONHelpers.string(raw, keys: ["format"])
        )
    }

    func getBookAuthor(id: String) async throws -> BookAuthorDetail {
        let raw = try await getJSON(path: "/api/books/\(id)") as? [String: Any] ?? [:]
        return MediaNormalizer.bookAuthor(from: raw, serverBase: serverBase)
    }

    // MARK: - Live TV

    func listLiveTV() async throws -> LiveTVData {
        let raw = try await getJSON(path: "/api/livetv") as? [String: Any] ?? [:]
        return MediaNormalizer.liveTV(from: raw)
    }

    func createLiveTVTimer(channelID: String, title: String, series: Bool) async throws {
        let body: [String: Any] = ["channel_id": channelID, "title": title, "series": series]
        let data = try JSONSerialization.data(withJSONObject: body)
        _ = try await getJSON(path: "/api/livetv/timers", method: "POST", body: data)
    }

    // MARK: - Quick connect & password

    func approveQuickConnect(code: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["code": code])
        let raw = try await getJSON(path: "/api/quickconnect", method: "POST", body: body) as? [String: Any] ?? [:]
        return JSONHelpers.string(raw, keys: ["message"])
    }

    func requestPasswordReset(username: String, note: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["username": username, "note": note])
        let raw = try await getJSON(path: "/api/password-reset", method: "POST", body: body) as? [String: Any] ?? [:]
        return JSONHelpers.string(raw, keys: ["message"])
    }

    func jellyfinPlayURL(muxId: String) async throws -> String? {
        let encoded = muxId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? muxId
        let raw = try await getJSON(path: "/api/jellyfin/play?mux_id=\(encoded)") as? [String: Any] ?? [:]
        let url = JSONHelpers.string(raw, keys: ["url"])
        return url.isEmpty ? nil : url
    }

    func fetchPlaybackSubtitles(src: String) async throws -> [PlaybackSubtitleTrack] {
        let encoded = src.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? src
        let raw = try await getJSON(path: "/api/playback/subtitles?src=\(encoded)") as? [String: Any] ?? [:]
        let rows = JSONHelpers.dictArray(raw["tracks"])
        return rows.map { dict in
            PlaybackSubtitleTrack(
                id: JSONHelpers.string(dict, keys: ["id"]),
                label: JSONHelpers.string(dict, keys: ["label"]),
                language: JSONHelpers.string(dict, keys: ["language", "srclang"]).isEmpty ? nil : JSONHelpers.string(dict, keys: ["language", "srclang"]),
                src: JSONHelpers.string(dict, keys: ["src"]),
                isDefault: JSONHelpers.bool(dict, keys: ["default"])
            )
        }
    }

    // MARK: - Private encoding

    private func parseUserdataBlob(_ raw: [String: Any]) -> UserdataBlob {
        var progress: [String: ProgressEntry]? = nil
        if let p = raw["progress"] as? [String: Any] {
            progress = decodeMap(p, as: ProgressEntry.self)
        }
        var favorites: [String: FavoriteEntry]? = nil
        if let f = raw["favorites"] as? [String: Any] {
            favorites = decodeMap(f, as: FavoriteEntry.self)
        }
        var prefs: UserPreferences? = nil
        if let p = raw["prefs"] {
            prefs = decode(p, as: UserPreferences.self)
        }
        var playlists: [Playlist]? = nil
        if let arr = raw["playlists"] as? [Any] {
            playlists = arr.compactMap { decode($0, as: Playlist.self) }
        }
        var queue: [QueueItem]? = nil
        if let arr = raw["queue"] as? [Any] {
            queue = arr.compactMap { decode($0, as: QueueItem.self) }
        }
        return UserdataBlob(progress: progress, favorites: favorites, prefs: prefs, playlists: playlists, queue: queue)
    }

    private func encodeMap<T: Encodable>(_ map: [String: T]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, value) in map {
            if let data = try? JSONEncoder().encode(value),
               let obj = try? JSONSerialization.jsonObject(with: data) {
                out[key] = obj
            }
        }
        return out
    }

    private func encodePrefs(_ prefs: UserPreferences) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(prefs),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return obj
    }

    private func queueItemDict(_ item: QueueItem) -> [String: Any] {
        var d: [String: Any] = ["id": item.id, "kind": item.kind.rawValue, "title": item.title, "href": item.href]
        if let s = item.streamURL { d["stream_url"] = s }
        if let p = item.posterURL { d["poster_url"] = p }
        return d
    }

    private func decode<T: Decodable>(_ value: Any, as type: T.Type) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: value) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func decodeMap<T: Decodable>(_ dict: [String: Any], as type: T.Type) -> [String: T] {
        var out: [String: T] = [:]
        for (key, value) in dict {
            if let decoded = decode(value, as: type) {
                out[key] = decoded
            }
        }
        return out
    }
}
