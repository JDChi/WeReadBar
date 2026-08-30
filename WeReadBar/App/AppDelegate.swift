import AppKit
import SwiftUI

/// AppDelegate is the lifecycle entry point. It owns the shared
/// `StatsStore` and the two co-operating controllers
/// (`MenuBarController` for the status icon and right-click menu,
/// `PopoverPresenter` for the popover window). The AppKit status-item
/// / popover machinery lives in those controllers; this file just
/// wires them together.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Owned

    private let store = StatsStore()
    private var popoverPresenter: PopoverPresenter!
    private var menuBarController: MenuBarController!

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.bootstrap()

        popoverPresenter = PopoverPresenter(store: store)
        menuBarController = MenuBarController(popoverPresenter: popoverPresenter)

        // First run (no token yet): open the onboarding window directly so
        // the user sees the key-entry UI before they ever click the
        // menu-bar icon.
        if store.needsAPIKey {
            DispatchQueue.main.async {
                OnboardingWindowController.shared.show(store: self.store)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu-bar app: never quit just because the popover closed.
        return false
    }
}
