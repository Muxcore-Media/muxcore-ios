import Foundation

extension APIClient {
    convenience init() {
        self.init(serverBase: SessionStore.serverURL(), sessionToken: SessionStore.sessionCookie())
    }

    func establishSession(from callbackURL: URL) async throws -> String {
        guard let base = serverBase, let serverHost = base.host,
              let code = AuthCallback.authCallbackCode(from: callbackURL, serverHost: serverHost) else {
            throw APIError.badResponse("Missing auth code")
        }
        let result = try await exchangeMobileCode(code)
        let token = result.token
        setSessionToken(token)
        do {
            let scope = try await sessionScope()
            guard scope.userID == result.userID else { throw APIError.decodingFailed }
            try SessionStore.saveSession(cookie: token, username: result.username, scope: scope)
            // Retain the existing AVPlayer cookie behavior. The JSON session is independently cookie-free.
            syncSessionCookie(token, serverBase: base)
            return token
        } catch {
            // A superseded exchange must not clear a newer sign-in.
            if sessionToken == token { setSessionToken(nil); SessionStore.clearSession() }
            throw error
        }
    }

    func syncSessionCookie(_ value: String, serverBase: URL) {
        guard let host = serverBase.host else { return }
        var properties: [HTTPCookiePropertyKey: Any] = [
            .domain: host, .path: "/", .name: "session", .value: value,
        ]
        if serverBase.scheme == "https" { properties[.secure] = "TRUE" }
        if let cookie = HTTPCookie(properties: properties) { HTTPCookieStorage.shared.setCookie(cookie) }
    }

    func clearPlaybackSessionCookie() {
        guard let base = serverBase else { return }
        for cookie in HTTPCookieStorage.shared.cookies(for: base) ?? [] where cookie.name == "session" {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}
