import Foundation
import Security

enum SessionStore {
    private static let service = "systems.zem.muxcore"
    private static let serverAccount = "serverURL"
    private static let sessionAccount = "sessionCookie"
    private static let usernameAccount = "username"

    static func saveServerURL(_ url: URL) {
        save(url.absoluteString, account: serverAccount)
    }

    static func serverURL() -> URL? {
        guard let raw = read(account: serverAccount) else { return nil }
        return URL(string: raw)
    }

    static func saveSession(cookie: String, username: String?) {
        save(cookie, account: sessionAccount)
        if let username {
            save(username, account: usernameAccount)
        }
    }

    static func sessionCookie() -> String? {
        read(account: sessionAccount)
    }

    static func username() -> String? {
        read(account: usernameAccount)
    }

    static func clearSession() {
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
