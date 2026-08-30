import AppKit
import SwiftUI

/// AppDelegate owns the NSStatusItem, right-click NSMenu, and NSPopover
/// directly via AppKit — SwiftUI's `MenuBarExtra` is intentionally
/// bypassed so that right-click menus work reliably across macOS versions
/// (`.contextMenu` on a MenuBarExtra icon is flaky and inconsistent).
///
/// Attached to the SwiftUI App via `@NSApplicationDelegateAdaptor`; the
/// SwiftUI App's `@main` synthesizes the real `main()` that starts the
/// NSApplication event loop (an `@main`-on-AppDelegate would only
/// instantiate this class without ever calling `NSApp.run()`).
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Owned objects

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var rightClickMenu: NSMenu!
    private let store = StatsStore()

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.bootstrap()
        setupStatusItem()
        setupRightClickMenu()
        setupPopover()

        // First run (no token yet): open onboarding window directly so the
        // user sees the key-entry UI before they ever click the menu-bar icon.
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

    // MARK: - Status item

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
                                 action: #selector(refreshNow),
                                 keyEquivalent: "r")
        refresh.target = self
        rightClickMenu.addItem(refresh)

        rightClickMenu.addItem(.separator())

        let changeKey = NSMenuItem(title: "Change API key…",
                                   action: #selector(changeAPIKey),
                                   keyEquivalent: "")
        changeKey.target = self
        rightClickMenu.addItem(changeKey)

        rightClickMenu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit WeReadBar",
                              action: #selector(quitApp),
                              keyEquivalent: "q")
        quit.target = self
        rightClickMenu.addItem(quit)
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 600, height: 280)
        let host = NSHostingController(
            rootView: PopoverView().environmentObject(store)
        )
        popover.contentViewController = host
    }

    // MARK: - Click handling

    @objc private func handleStatusClick(_ sender: NSStatusBarButton) {
        let eventType = NSApp.currentEvent?.type
        if eventType == .rightMouseUp {
            // Right-click: show menu just below the status icon.
            let position = NSPoint(x: 0, y: sender.bounds.height)
            rightClickMenu.popUp(positioning: nil, at: position, in: sender)
        } else {
            // Left-click: toggle popover.
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Make the popover key so SwiftUI inputs receive focus.
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Menu actions

    @objc private func refreshNow() {
        Task { await store.refresh() }
    }

    @objc private func changeAPIKey() {
        store.needsAPIKey = true
        OnboardingWindowController.shared.show(store: store)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
