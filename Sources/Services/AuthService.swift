import AuthenticationServices
import Foundation
import UIKit

@MainActor
final class AuthService: NSObject {
    private let api: APIClient
    private var webAuthSession: ASWebAuthenticationSession?

    init(api: APIClient) {
        self.api = api
    }

    func login(serverURL: URL) async throws {
        api.setServerBase(serverURL)
        let loginURL = serverURL.appendingPathComponent("login")
        guard let host = serverURL.host else {
            throw APIError.badResponse("Invalid server URL")
        }

        let callbackURL = try await startWebAuth(
            url: loginURL,
            host: host
        )
        _ = try await api.establishSession(from: callbackURL)
    }

    func logout() {
        SessionStore.clearSession()
    }

    private func startWebAuth(url: URL, host: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callback: .https(host: host, path: "/auth/callback")
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: APIError.badResponse("Login cancelled"))
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            if !session.start() {
                continuation.resume(throwing: APIError.badResponse("Could not start login session"))
            }
        }
    }
}

extension AuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return window
        }
        return scenes.flatMap(\.windows).first ?? ASPresentationAnchor()
    }
}
