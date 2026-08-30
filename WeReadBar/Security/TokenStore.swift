import Foundation

/// Persists the WeRead API bearer token in `UserDefaults`
/// (~/Library/Preferences/com.local.wereadbar.plist, key
/// "WeReadBar.apiToken"). The token is a low-stakes read-only
/// credential for the user's own reading data; UserDefaults is fine.
enum TokenStore {
    private static let defaultsKey = "WeReadBar.apiToken"

    /// Persists `token`, overwriting any prior value.
    static func save(_ token: String) {
        UserDefaults.standard.set(token, forKey: defaultsKey)
    }

    /// Reads the stored token, or nil if none has been saved.
    static func load() -> String? {
        UserDefaults.standard.string(forKey: defaultsKey)
    }

    /// Removes the stored token (if any).
    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
