import AppKit
import SwiftUI

/// Owns the `NSPopover` and its hosting controller, plus the few
/// "menu-driven" actions that need to reach back into the popover's
/// state or open secondary windows (onboarding).
///
/// Pulled out of `AppDelegate` so the AppKit popover lifecycle stays
/// out of the app-lifecycle wiring file.
@MainActor
final class PopoverPresenter: NSObject {

    // MARK: - Owned

    private let store: StatsStore
    private var popover: NSPopover!

    // MARK: - Init

    init(store: StatsStore) {
        self.store = store
        super.init()
        setupPopover()
    }

    // MARK: - Setup

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 600, height: 280)
        let host = NSHostingController(
            rootView: PopoverView().environmentObject(store)
        )
        popover.contentViewController = host
    }

    // MARK: - Public API (called by MenuBarController)

    /// Left-click on the status icon: show or hide the popover, anchored
    /// to the given status button. Caller (MenuBarController) injects
    /// the button reference so this class doesn't reach into the status bar.
    func toggle(anchoredTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Make the popover key so SwiftUI inputs receive focus.
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    /// "Refresh now" menu item.
    func refreshFromMenu() {
        Task { await store.refresh() }
    }

    /// "Change API key…" menu item — opens the onboarding window and
    /// forces `needsAPIKey = true` so the popover's `.onChange` also
    /// reacts when it's open.
    func requestAPIKeyChange() {
        store.needsAPIKey = true
        OnboardingWindowController.shared.show(store: store)
    }
}
