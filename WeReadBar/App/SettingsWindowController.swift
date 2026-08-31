import AppKit
import SwiftUI

/// Owns the reusable AppKit settings window. Keeping a real NSWindow avoids
/// SwiftUI Window-scene reopening issues in this LSUIElement application.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    private init() {}

    func show(store: StatsStore, reminderCoordinator: ReminderCoordinator) {
        if window == nil {
            let content = SettingsWindow(reminderCoordinator: reminderCoordinator)
                .environmentObject(store)
            let hosting = NSHostingController(rootView: content)
            let window = NSWindow(contentViewController: hosting)
            window.title = String(localized: "settings.windowTitle")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            window.setContentSize(NSSize(width: 460, height: 390))
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
