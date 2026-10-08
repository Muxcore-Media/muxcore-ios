import Foundation
import Security

enum SessionStore {
    private static let service = "systems.zem.muxcore"
    private static let serverAccount = "serverURL"
    private static let sessionAccount = "sessionCookie"
    private static let usernameAccount = "username"
    private static let nativeSessionAccount = "nativeSession.v2"
    private struct NativeSession: Codable {
        let token: String
        let username: String?
        let scope: UserDataScope
    }

    static func saveServerURL(_ url: URL) {
        save(url.absoluteString, account: serverAccount)
    }

    static func serverURL() -> URL? {
        guard let raw = read(account: serverAccount) else { return nil }
        return URL(string: raw)
    }

    static func saveSession(cookie: String, username: String?, scope: UserDataScope) throws {
        // Token and verified owner are one atomic keychain value: a failed write must
        // never pair a new user's token with the previous user's pending-data scope.
        let data = try JSONEncoder().encode(NativeSession(token: cookie, username: username, scope: scope))
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: nativeSessionAccount,
        ]
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw APIError.badResponse("Could not securely save this session. Sign in again.") }
    }

    private static func nativeSession() -> NativeSession? {
        guard let raw = read(account: nativeSessionAccount), let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(NativeSession.self, from: data)
    }

    static func sessionCookie() -> String? {
        guard let session = nativeSession(), let base = serverURL(),
              ServerURL.origin(base) == session.scope.origin else { return nil }
        return session.token
    }

    static func userdataScope() -> UserDataScope? { nativeSession()?.scope }
    static func username() -> String? { nativeSession()?.username }

    static func clearSession() {
        delete(account: nativeSessionAccount)
        delete(account: sessionAccount)
        delete(account: usernameAccount)
    }

    static func clearAll() {
        clearSession()
        delete(account: serverAccount)
    }

    private static func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
