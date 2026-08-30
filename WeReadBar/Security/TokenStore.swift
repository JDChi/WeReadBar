import Foundation

/// Persists the WeRead API bearer token in `UserDefaults`
/// (~/Library/Preferences/com.local.wereadbar.plist).
///
/// Previously this used the macOS Keychain. We switched because ad-hoc
/// signed apps trigger a Keychain password prompt on every read — the
/// token is a low-stakes read-only credential for the user's own reading
/// data, and any process that could read UserDefaults could already
/// trigger the same Keychain prompt. Net result: zero dialogs at launch.
///
/// The single key lives at "WeReadBar.apiToken".
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
