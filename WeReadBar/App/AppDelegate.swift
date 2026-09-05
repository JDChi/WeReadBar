import AppKit
import SwiftUI
import UserNotifications

/// AppDelegate is the lifecycle entry point. It owns the shared
/// `StatsStore` and the two co-operating controllers
/// (`MenuBarController` for the status icon and right-click menu,
/// `PopoverPresenter` for the popover window). The AppKit status-item
/// / popover machinery lives in those controllers; this file just
/// wires them together.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Owned

    private let store = StatsStore()
    private var popoverPresenter: PopoverPresenter!
    private var menuBarController: MenuBarController!
    private var reminderCoordinator: ReminderCoordinator!
    private var updateController: UpdateController!

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        store.bootstrap()
        reminderCoordinator = ReminderCoordinator(store: store)
        reminderCoordinator.start()
        updateController = UpdateController()

        popoverPresenter = PopoverPresenter(store: store, reminderCoordinator: reminderCoordinator)
        menuBarController = MenuBarController(
            popoverPresenter: popoverPresenter,
            updateController: updateController
        )

        // First run (no token yet): open settings directly so the user sees
        // the account setup before they ever click the menu-bar icon.
        if store.needsAPIKey {
            DispatchQueue.main.async {
                SettingsWindowController.shared.show(store: self.store, reminderCoordinator: self.reminderCoordinator)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu-bar app: never quit just because the popover closed.
        return false
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
