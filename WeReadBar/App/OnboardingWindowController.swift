import AppKit
import SwiftUI

/// Manages the onboarding NSWindow directly via AppKit (bypasses SwiftUI
/// `Window` scene to avoid the "can't reopen after close" bug).
/// Singleton so the popover can call `show()` without coupling.
@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    private init() {}

    /// Shows the onboarding window. Creates it on first call, reuses it after.
    /// `dismissOnSave` ensures the window closes itself once the store flips
    /// `needsAPIKey` to false (key successfully saved).
    func show(store: StatsStore) {
        if window == nil {
            createWindow(store: store)
        }
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func createWindow(store: StatsStore) {
        let content = OnboardingWindow()
            .environmentObject(store)

        let hosting = NSHostingController(rootView: content)
        let win = NSWindow(contentViewController: hosting)
        win.title = String(localized: "window.title.setup")
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false        // keep instance alive after close
        win.center()
        win.setContentSize(NSSize(width: 380, height: 220))
        win.titlebarAppearsTransparent = false

        self.window = win
    }

    /// Force-close the onboarding window (used when the key is cleared from elsewhere).
    func hide() {
        window?.orderOut(nil)
    }
}
