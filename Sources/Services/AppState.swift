import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var serverURLString: String = SessionStore.serverURL()?.absoluteString ?? "https://mux.zem.systems"
    @Published var isAuthenticated: Bool = SessionStore.sessionCookie() != nil
    @Published var username: String? = SessionStore.username()
    @Published var capabilities: Capabilities = .defaults
    @Published var lastError: String?

    let api: APIClient
    let userdata: UserDataStore
    lazy var auth = AuthService(api: api)

    init() {
        let client = APIClient()
        api = client
        userdata = UserDataStore(api: client)
    }

    func bootstrap() async {
        if let url = SessionStore.serverURL() {
            api.setServerBase(url)
            serverURLString = url.absoluteString
            if let cookie = SessionStore.sessionCookie() {
                api.syncSessionCookie(cookie, serverBase: url)
            }
        }
        isAuthenticated = SessionStore.sessionCookie() != nil
        username = SessionStore.username()
        if isAuthenticated {
            await refreshCapabilities()
            await userdata.pullFromServer()
        }
    }

    func configureServer(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = normalizedServerURL(trimmed) else {
            lastError = "Enter a valid URL (e.g. https://mux.zem.systems)"
            return
        }
        serverURLString = url.absoluteString
        api.setServerBase(url)
        lastError = nil
    }

    func login() async {
        guard let url = normalizedServerURL(serverURLString) else {
            lastError = "Enter a valid server URL first."
            return
        }
        lastError = nil
        do {
            try await auth.login(serverURL: url)
            isAuthenticated = true
            username = SessionStore.username()
            await refreshCapabilities()
            await userdata.pullFromServer()
        } catch {
            isAuthenticated = false
            lastError = error.localizedDescription
        }
    }

    func logout() {
        auth.logout()
        isAuthenticated = false
        username = nil
        capabilities = .defaults
    }

    func refreshCapabilities() async {
        do {
            capabilities = try await api.getCapabilities()
            lastError = nil
        } catch {
            if case APIError.unauthorized = error {
                logout()
            }
            lastError = error.localizedDescription
        }
    }

    private func normalizedServerURL(_ raw: String) -> URL? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.hasPrefix("http://") && !value.hasPrefix("https://") {
            value = "https://\(value)"
        }
        guard let url = URL(string: value) else { return nil }
        return url
    }
}
