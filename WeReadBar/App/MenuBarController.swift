import AppKit
import SwiftUI

/// Owns the NSStatusItem, its right-click NSMenu, and the click-handling
/// dispatch (left-click → toggle popover; right-click → show menu).
///
/// Pulled out of `AppDelegate` so the lifecycle wiring (delegate, store)
/// stays separate from the AppKit status-item machinery.
@MainActor
final class MenuBarController: NSObject {

    // MARK: - Dependencies (injected)

    private weak var popoverPresenter: PopoverPresenter?

    // MARK: - Owned

    private var statusItem: NSStatusItem!
    private var rightClickMenu: NSMenu!

    // MARK: - Init

    init(popoverPresenter: PopoverPresenter) {
        self.popoverPresenter = popoverPresenter
        super.init()
        setupStatusItem()
        setupRightClickMenu()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        let image = NSImage(systemSymbolName: "book.closed.fill",
                            accessibilityDescription: "WeRead")
        image?.isTemplate = true   // auto-tints for light/dark menubar
        button.image = image
        button.target = self
        button.action = #selector(handleStatusClick(_:))
        // Listen for both left and right clicks so we can dispatch them.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Right-click menu. Held as a property; popped up manually in
    /// `handleStatusClick` (we do NOT set `statusItem.menu` because that
    /// would intercept left-clicks too and prevent the popover).
    private func setupRightClickMenu() {
        rightClickMenu = NSMenu()

        let refresh = NSMenuItem(title: "Refresh now",
                                 action: #selector(menuRefreshNow),
                                 keyEquivalent: "r")
        refresh.target = self
        rightClickMenu.addItem(refresh)

        rightClickMenu.addItem(.separator())

        let changeKey = NSMenuItem(title: "Change API key…",
                                   action: #selector(menuChangeAPIKey),
                                   keyEquivalent: "")
        changeKey.target = self
        rightClickMenu.addItem(changeKey)

        rightClickMenu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit WeReadBar",
                              action: #selector(menuQuit),
                              keyEquivalent: "q")
        quit.target = self
        rightClickMenu.addItem(quit)
    }

    // MARK: - Click dispatch

    @objc private func handleStatusClick(_ sender: NSStatusBarButton) {
        let eventType = NSApp.currentEvent?.type
        if eventType == .rightMouseUp {
            // Right-click: show menu just below the status icon.
            let position = NSPoint(x: 0, y: sender.bounds.height)
            rightClickMenu.popUp(positioning: nil, at: position, in: sender)
        } else {
            // Left-click: toggle popover, anchored to the clicked button.
            popoverPresenter?.toggle(anchoredTo: sender)
        }
    }

    // MARK: - Menu actions
    //
    // These forward to the shared `OnboardingWindowController` and
    // `NSApp.terminate`. They intentionally don't reach into the
    // `StatsStore` directly — the menu is the "user wants to do X"
    // channel, not a data-pipeline driver.

    @objc private func menuRefreshNow() {
        popoverPresenter?.refreshFromMenu()
    }

    @objc private func menuChangeAPIKey() {
        popoverPresenter?.requestAPIKeyChange()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}
