import Foundation

enum APIError: LocalizedError {
    case missingServer
    case unauthorized
    case badResponse(String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingServer:
            return "Server URL is not configured."
        case .unauthorized:
            return "Session expired. Sign in again."
        case .badResponse(let detail):
            return detail
        case .decodingFailed:
            return "Could not read server response."
        }
    }
}

final class APIClient {
    private let session: URLSession
    var serverBase: URL?

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        self.session = URLSession(configuration: config)
        self.serverBase = SessionStore.serverURL()
        if let base = serverBase, let cookie = SessionStore.sessionCookie() {
            syncSessionCookie(cookie, serverBase: base)
        }
    }

    func setServerBase(_ url: URL) {
        serverBase = url
        SessionStore.saveServerURL(url)
    }

    func currentServerBase() -> URL? {
        serverBase
    }

    func absoluteURL(path: String) -> URL? {
        guard let serverBase else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        return URL(string: path, relativeTo: serverBase)
    }

    func getJSON(path: String, method: String = "GET", body: Data? = nil) async throws -> Any {
        guard let url = absoluteURL(path: path) else { throw APIError.missingServer }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let cookie = SessionStore.sessionCookie() {
            request.setValue("session=\(cookie)", forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.badResponse("Invalid response")
        }
        if http.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let detail = parseErrorBody(data) ?? "\(http.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))"
            throw APIError.badResponse(detail)
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    func establishSession(from callbackURL: URL) async throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty
        else {
            throw APIError.badResponse("Missing auth code")
        }
        let path = "/auth/callback?code=\(code)"
        guard let url = absoluteURL(path: path) else { throw APIError.missingServer }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.badResponse("Invalid auth response")
        }
        guard (200 ... 399).contains(http.statusCode) else {
            throw APIError.badResponse("Auth callback failed (\(http.statusCode))")
        }

        if let cookie = extractSessionCookie(from: http, url: url) {
            SessionStore.saveSession(cookie: cookie, username: nil)
            if let base = serverBase {
                syncSessionCookie(cookie, serverBase: base)
            }
            return cookie
        }
        if let stored = HTTPCookieStorage.shared.cookies(for: url)?.first(where: { $0.name == "session" }) {
            SessionStore.saveSession(cookie: stored.value, username: nil)
            return stored.value
        }
        throw APIError.badResponse("No session cookie returned")
    }

    func syncSessionCookie(_ value: String, serverBase: URL) {
        guard let host = serverBase.host else { return }
        var properties: [HTTPCookiePropertyKey: Any] = [
            .domain: host,
            .path: "/",
            .name: "session",
            .value: value,
        ]
        if serverBase.scheme == "https" {
            properties[.secure] = "TRUE"
        }
        if let cookie = HTTPCookie(properties: properties) {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    private func extractSessionCookie(from response: HTTPURLResponse, url: URL) -> String? {
        if let header = response.value(forHTTPHeaderField: "Set-Cookie") {
            return parseSessionValue(header)
        }
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                result[key] = value
            }
        }
        if !headers.isEmpty {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
            if let value = cookies.first(where: { $0.name == "session" })?.value {
                return value
            }
        }
        return nil
    }

    private func parseSessionValue(_ header: String) -> String? {
        let parts = header.split(separator: ";")
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("session=") {
                return String(trimmed.dropFirst("session=".count))
            }
        }
        return nil
    }

    private func parseErrorBody(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }
        if let error = object["error"] as? String {
            if let code = object["code"] as? String {
                return "\(error) (\(code))"
            }
            return error
        }
        return nil
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

    func search(query: String) async throws -> [SearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let raw = try await getJSON(path: "/api/search?q=\(encoded)") as? [String: Any] ?? [:]
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
