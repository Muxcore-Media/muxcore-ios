import Foundation

enum AuthCallback {
    static let redirectURI = "muxcore://auth/callback"
    static let customScheme = "muxcore"

    static func mobileAuthLoginURL(serverBase: URL) -> URL {
        var components = URLComponents(url: serverBase, resolvingAgainstBaseURL: false)!
        components.path = "/api/mobile/auth/login"
        components.queryItems = [
            URLQueryItem(name: "redirect_uri", value: redirectURI),
        ]
        return components.url!
    }

    static func authCallbackCode(from url: URL, serverHost: String?) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty
        else {
            return nil
        }

        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()
        if scheme == customScheme, host == "auth" {
            return code
        }

        guard let serverHost, let host, host == serverHost.lowercased() else {
            return nil
        }
        let path = url.path
        if path == "/auth/callback" || path.hasPrefix("/auth/callback/") {
            return code
        }
        return nil
    }

    static func isMuxcoreAuthDeepLink(_ url: URL) -> Bool {
        url.scheme?.lowercased() == customScheme && url.host?.lowercased() == "auth"
    }
}
