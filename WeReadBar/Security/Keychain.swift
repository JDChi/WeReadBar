import Foundation
import Security

/// Tiny wrapper around the macOS Keychain for the WeRead bearer token.
/// Uses the user's login keychain; no entitlements needed when sandbox is off.
enum Keychain {
    private static let service = "com.local.wereadbar.apikey"
    private static let account = "default"

    /// Stores `token`, overwriting any prior value.
    static func save(_ token: String) throws {
        let data = Data(token.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Overwrite semantics: delete any prior entry first.
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(
                domain: "WeReadBar.Keychain",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "SecItemAdd failed (\(status))"]
            )
        }
    }

    /// Reads the stored token, if any.
    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    /// Removes the stored token (if any).
    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
