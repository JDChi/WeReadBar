import AppKit
import SwiftUI

/// Owns the reusable AppKit settings window. Keeping a real NSWindow avoids
/// SwiftUI Window-scene reopening issues in this LSUIElement application.
/// Closes automatically when clicking outside or losing focus.
@MainActor
final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    private override init() {
        super.init()
    }

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
            window.delegate = self
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// Close window when it loses focus (clicking outside)
extension SettingsWindowController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        window?.close()
    }
}
