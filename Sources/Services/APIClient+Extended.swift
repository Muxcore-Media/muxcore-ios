import Foundation

extension APIClient {
    // MARK: - Userdata

    struct UserdataBlob: Codable {
        var progress: [String: ProgressEntry]?
        var favorites: [String: FavoriteEntry]?
        var prefs: UserPreferences?
        var playlists: [Playlist]?
        var queue: [QueueItem]?
        // Keep preference keys owned by other clients when the server replaces this document.
        var rawPrefs: Data?
        var userID: String?
        var tenantID: String?
    }

    func getUserdata() async throws -> UserdataBlob {
        try parseUserdataBlob(try await getJSON(path: "/api/userdata"))
    }

    func putUserdata(_ blob: UserdataBlob) async throws -> UserdataBlob {
        var body: [String: Any] = [:]
        if let value = blob.progress { body["progress"] = try jsonObject(value) }
        if let value = blob.favorites { body["favorites"] = try jsonObject(value) }
        if let value = blob.prefs {
            let preserved = try blob.rawPrefs.map { try JSONSerialization.jsonObject(with: $0) as? [String: Any] ?? [:] } ?? [:]
            body["prefs"] = Self.overlay(preserved, try jsonObject(value) as? [String: Any] ?? [:])
        }
        if let value = blob.playlists { body["playlists"] = try jsonObject(value) }
        if let value = blob.queue { body["queue"] = try jsonObject(value) }
        let data = try JSONSerialization.data(withJSONObject: body)
        return try parseUserdataBlob(try await getJSON(path: "/api/userdata", method: "PUT", body: data))
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

    private func parseUserdataBlob(_ value: Any) throws -> UserdataBlob {
        guard let raw = value as? [String: Any],
              let userID = raw["user_id"] as? String, !userID.isEmpty else {
            throw APIError.decodingFailed
        }
        if let tenant = raw["tenant_id"], !(tenant is String) { throw APIError.decodingFailed }
        func field<T: Decodable>(_ key: String, _ type: T.Type) throws -> T? {
            guard let value = raw[key] else { return nil }
            guard JSONSerialization.isValidJSONObject(value) else { throw APIError.decodingFailed }
            do {
                return try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: value))
            } catch { throw APIError.decodingFailed }
        }
        var prefs: UserPreferences?
        var rawPrefs: Data?
        if let value = raw["prefs"] {
            guard let dictionary = value as? [String: Any] else { throw APIError.decodingFailed }
            rawPrefs = try JSONSerialization.data(withJSONObject: dictionary)
            let defaults = try jsonObject(UserPreferences.defaults) as? [String: Any] ?? [:]
            let merged = Self.overlay(defaults, dictionary)
            do { prefs = try JSONDecoder().decode(UserPreferences.self, from: JSONSerialization.data(withJSONObject: merged)) }
            catch { throw APIError.decodingFailed }
        }
        return UserdataBlob(
            progress: try field("progress", [String: ProgressEntry].self),
            favorites: try field("favorites", [String: FavoriteEntry].self),
            prefs: prefs,
            playlists: try field("playlists", [Playlist].self),
            queue: try field("queue", [QueueItem].self),
            rawPrefs: rawPrefs, userID: userID, tenantID: raw["tenant_id"] as? String ?? ""
        )
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }

    static func overlay(_ base: [String: Any], _ patch: [String: Any]) -> [String: Any] {
        var result = base
        for (key, value) in patch {
            if let nested = value as? [String: Any], let original = result[key] as? [String: Any] {
                result[key] = overlay(original, nested)
            } else { result[key] = value }
        }
        return result
    }
}
