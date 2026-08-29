import Foundation

enum ServerURL {
    static func validationError(for url: URL) -> String? {
        guard let host = url.host?.lowercased(), !host.isEmpty else {
            return "Enter a valid URL (e.g. https://mux.zem.systems)"
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
