import Foundation

enum ServerURL {
    /// Exact scheme/host/effective-port binding; never treat another port as the same server.
    static func origin(_ url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host?.lowercased(), !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        let port = url.port ?? (scheme == "https" ? 443 : 80)
        return "\(scheme)://\(host):\(port)"
    }

    static func validationError(for url: URL) -> String? {
        guard let host = url.host?.lowercased(), !host.isEmpty else {
            return "Enter a valid URL (e.g. https://mux.zem.systems)"
        }
        guard origin(url) != nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/" else {
            return "Use an HTTP or HTTPS server origin without credentials, a path, query, or fragment."
        }
        if host.hasPrefix("auth.") {
            return "Use your media server URL (https://mux.zem.systems), not the auth login host."
        }
        if host.hasPrefix("admin.") {
            return "Use your media server URL (https://mux.zem.systems), not the admin UI host."
        }
        return nil
    }
}
