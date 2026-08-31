import Foundation

/// Persists the user's local inactivity-reminder preferences separately from
/// the WeRead API token. Defaults are intentionally enabled and conservative.
enum ReminderSettings {
    private static let enabledKey = "WeReadBar.reminderEnabled"
    private static let thresholdKey = "WeReadBar.reminderThresholdDays"
    private static let lastNotificationDateKey = "WeReadBar.reminderLastNotificationDate"

    static var isEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: enabledKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var thresholdDays: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: thresholdKey)
            return (1...30).contains(stored) ? stored : 3
        }
        set { UserDefaults.standard.set(min(max(newValue, 1), 30), forKey: thresholdKey) }
    }

    /// `yyyy-MM-dd` in Asia/Shanghai. Prevents duplicate notices within one day.
    static var lastNotificationDate: String? {
        get { UserDefaults.standard.string(forKey: lastNotificationDateKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastNotificationDateKey) }
    }
}
