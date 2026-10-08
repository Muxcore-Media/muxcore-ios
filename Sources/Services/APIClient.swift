import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum APIError: LocalizedError {
    case missingServer
    case unauthorized
    case badResponse(String)
    case decodingFailed
    case sessionChanged

    var errorDescription: String? {
        switch self {
        case .missingServer: return "Server URL is not configured."
        case .unauthorized: return "Session expired. Sign in again."
        case .badResponse(let detail): return detail
        case .decodingFailed: return "Could not read server response."
        case .sessionChanged: return "The signed-in session changed. Retry with the current account."
        }
    }
}

/// Native API traffic never follows redirects or uses the browser cookie jar.
final class BFFRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
final class APIClient {
    private let session: URLSession
    private(set) var serverBase: URL?
    private(set) var sessionToken: String?
    private(set) var sessionGeneration = UUID()

    init(serverBase: URL?, sessionToken: String? = nil,
         configuration: URLSessionConfiguration = .ephemeral) {
        let config = configuration.copy() as! URLSessionConfiguration
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config, delegate: BFFRedirectPolicy(), delegateQueue: nil)
        self.serverBase = serverBase
        self.sessionToken = sessionToken
    }

    func setServerBase(_ url: URL) {
        if ServerURL.origin(url) != serverBase.flatMap(ServerURL.origin) {
            setSessionToken(nil)
        }
        serverBase = url
    }

    func setSessionToken(_ token: String?) {
        sessionGeneration = UUID()
        sessionToken = token
    }

    func currentServerBase() -> URL? { serverBase }

    // Media links may be external; JSON requests below enforce the BFF origin.
    func absoluteURL(path: String) -> URL? {
        guard let serverBase else { return nil }
        return URL(string: path, relativeTo: serverBase)?.absoluteURL
    }

    func getJSON(path: String, method: String = "GET", body: Data? = nil,
                 authenticated: Bool = true) async throws -> Any {
        guard let base = serverBase, let origin = ServerURL.origin(base),
              let url = absoluteURL(path: path) else { throw APIError.missingServer }
        guard ServerURL.origin(url) == origin, url.user == nil, url.password == nil else {
            throw APIError.badResponse("API request must stay on the configured server.")
        }
        let generation = sessionGeneration
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated, let token = sessionToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard generation == sessionGeneration else { throw APIError.sessionChanged }
        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse("Invalid response") }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200 ... 299).contains(http.statusCode) else {
            // Do not surface a server's arbitrary body (which can echo credentials).
            throw APIError.badResponse("Server request failed (HTTP \(http.statusCode)).")
        }
        do { return try JSONSerialization.jsonObject(with: data) }
        catch { throw APIError.decodingFailed }
    }

    func exchangeMobileCode(_ code: String) async throws -> (token: String, userID: String, username: String?) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw APIError.badResponse("Missing auth code") }
        let body = try JSONSerialization.data(withJSONObject: ["code": trimmed])
        guard let raw = try await getJSON(path: "/api/mobile/session", method: "POST", body: body,
                                         authenticated: false) as? [String: Any],
              let token = raw["session_token"] as? String, !token.isEmpty,
              let userID = raw["user_id"] as? String, !userID.isEmpty else {
            throw APIError.decodingFailed
        }
        return (token, userID, raw["username"] as? String)
    }

    func sessionScope() async throws -> UserDataScope {
        guard let raw = try await getJSON(path: "/api/session") as? [String: Any],
              let userID = raw["user_id"] as? String, !userID.isEmpty,
              let base = serverBase, let origin = ServerURL.origin(base) else {
            throw APIError.decodingFailed
        }
        if let tenant = raw["tenant_id"], !(tenant is String) { throw APIError.decodingFailed }
        return UserDataScope(origin: origin, userID: userID, tenantID: raw["tenant_id"] as? String ?? "")
    }

    // MARK: - API surface (mirrors media-ui-app client)

    func getCapabilities() async throws -> Capabilities {
        let raw = try await getJSON(path: "/api/capabilities") as? [String: Any] ?? [:]
        return MediaNormalizer.capabilities(from: raw)
    }

    func listMovies(page: Int = 1, pageSize: Int = 48) async throws -> ListResponse<Movie> {
        let path = "/api/movies?page=\(page)&page_size=\(pageSize)"
        let data = try await getJSON(path: path)
        return MediaNormalizer.listMovies(from: data, serverBase: serverBase)
    }

    func getMovie(id: String) async throws -> Movie {
        let raw = try await getJSON(path: "/api/movies/\(id)") as? [String: Any] ?? [:]
        let row = JSONHelpers.asDict(raw["movie"] ?? raw["item"] ?? raw)
        return MediaNormalizer.movie(from: row, serverBase: serverBase)
    }

    func listTVShows(page: Int = 1, pageSize: Int = 48) async throws -> ListResponse<TVShow> {
        let path = "/api/tv?page=\(page)&page_size=\(pageSize)"
        let data = try await getJSON(path: path)
        return MediaNormalizer.listTV(from: data, serverBase: serverBase)
    }

    func getTVShow(id: String) async throws -> TVShow {
        let raw = try await getJSON(path: "/api/tv/\(id)") as? [String: Any] ?? [:]
        let row = JSONHelpers.asDict(raw["show"] ?? raw["series"] ?? raw["item"] ?? raw)
        return MediaNormalizer.tvShow(from: row, serverBase: serverBase)
    }

    func search(query: String, type: SearchMediaType? = nil) async throws -> [SearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        var path = "/api/search?q=\(encoded)"
        if let type {
            path += "&type=\(type.rawValue)"
        }
        let raw = try await getJSON(path: path) as? [String: Any] ?? [:]
        let rows = JSONHelpers.dictArray(raw["results"])
        return rows.compactMap { MediaNormalizer.searchResult(from: $0) }
    }

    func resolvePlayback(src: String) async throws -> PlaybackResolve {
        let encoded = src.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? src
        let raw = try await getJSON(path: "/api/playback/resolve?src=\(encoded)") as? [String: Any] ?? [:]
        return MediaNormalizer.playbackResolve(from: raw)
    }

    func ping() async throws {
        _ = try await getJSON(path: "/api/capabilities")
    }
}
