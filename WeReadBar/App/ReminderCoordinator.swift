import Foundation
import UserNotifications
import os

private let reminderLog = Logger(subsystem: "com.local.wereadbar", category: "reminder")

/// Owns reminder permission, periodic refreshes, and notification delivery
/// while the menu-bar process is alive. It deliberately does not install a
/// login item or background helper.
@MainActor
final class ReminderCoordinator {
    private let store: StatsStore
    private var timer: Timer?
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()

    init(store: StatsStore) {
        self.store = store
    }

    func start() {
        Task { await requestAuthorizationIfNeeded() }
        if !store.needsAPIKey {
            Task { await refreshAndEvaluate() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            Task { await self?.refreshAndEvaluate() }
        }
    }

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            reminderLog.error("notification authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func notificationAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func refreshAndEvaluate() async {
        await store.refresh()
        guard !store.needsAPIKey, store.lastError == nil, store.hasData else { return }
        await evaluate(days: store.days, now: Date())
    }

    private func evaluate(days: [ReadingDay], now: Date) async {
        guard ReminderSettings.isEnabled,
              let inactiveDays = completeInactiveDays(in: days, now: now) else { return }

        // A reading record today or yesterday resets the completed-day count
        // and lets a future lapse notify again.
        if inactiveDays == 0 {
            ReminderSettings.lastNotificationDate = nil
            return
        }

        guard inactiveDays >= ReminderSettings.thresholdDays else { return }
        let today = dayIdentifier(for: now)
        guard ReminderSettings.lastNotificationDate != today else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "WeReadBar"
        content.body = String.localizedStringWithFormat(
            NSLocalizedString("reminder.notification.body", comment: ""),
            inactiveDays
        )
        content.sound = .default

        do {
            try await center.add(UNNotificationRequest(
                identifier: "com.local.wereadbar.inactivity-reminder",
                content: content,
                trigger: nil
            ))
            ReminderSettings.lastNotificationDate = today
            reminderLog.notice("sent inactivity reminder after \(inactiveDays, privacy: .public) complete days")
        } catch {
            reminderLog.error("could not schedule inactivity reminder: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Returns completed, no-reading calendar days after the latest active
    /// day and before today. A missing history is intentionally not nudged.
    private func completeInactiveDays(in days: [ReadingDay], now: Date) -> Int? {
        let today = calendar.startOfDay(for: now)
        guard let lastActive = days
            .filter({ $0.active && $0.date != .distantPast && $0.date <= today })
            .map(\.date)
            .max()
        else { return nil }

        let lastDay = calendar.startOfDay(for: lastActive)
        let calendarDays = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        return max(0, calendarDays - 1)
    }

    private func dayIdentifier(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
