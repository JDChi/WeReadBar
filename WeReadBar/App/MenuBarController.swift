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
    private let updateController: UpdateController

    // MARK: - Owned

    private var statusItem: NSStatusItem!
    private var rightClickMenu: NSMenu!

    // MARK: - Init

    init(popoverPresenter: PopoverPresenter, updateController: UpdateController) {
        self.popoverPresenter = popoverPresenter
        self.updateController = updateController
        super.init()
        setupStatusItem()
        setupRightClickMenu()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        let image = NSImage(systemSymbolName: "book.closed.fill",
                            accessibilityDescription: String(localized: "app.name"))
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

        let refresh = NSMenuItem(title: String(localized: "menu.refreshNow"),
                                 action: #selector(menuRefreshNow),
                                 keyEquivalent: "r")
        refresh.target = self
        rightClickMenu.addItem(refresh)

        rightClickMenu.addItem(.separator())

        let checkForUpdates = NSMenuItem(title: String(localized: "menu.checkForUpdates"),
                                         action: #selector(menuCheckForUpdates),
                                         keyEquivalent: "")
        checkForUpdates.target = self
        rightClickMenu.addItem(checkForUpdates)

        let about = NSMenuItem(title: String(localized: "menu.about"),
                               action: #selector(menuAbout),
                               keyEquivalent: "")
        about.target = self
        rightClickMenu.addItem(about)

        let goToRead = NSMenuItem(title: String(localized: "goToRead"),
                                  action: #selector(menuGoToRead),
                                  keyEquivalent: "")
        goToRead.target = self
        rightClickMenu.addItem(goToRead)

        let settings = NSMenuItem(title: String(localized: "menu.settings"),
                                  action: #selector(menuSettings),
                                  keyEquivalent: ",")
        settings.target = self
        rightClickMenu.addItem(settings)

        rightClickMenu.addItem(.separator())

        let quit = NSMenuItem(title: String(localized: "menu.quit"),
                              action: #selector(menuQuit),
                              keyEquivalent: "q")
        quit.target = self
        rightClickMenu.addItem(quit)
    }

    // MARK: - Click dispatch

    @objc private func handleStatusClick(_ sender: NSStatusBarButton) {
        let eventType = NSApp.currentEvent?.type
        if eventType == .rightMouseUp {
            // Right-click: show menu below the status icon using context menu.
            // Using popUpContextMenu lets macOS handle edge detection properly.
            NSMenu.popUpContextMenu(rightClickMenu, with: NSApp.currentEvent!, for: sender)
        } else {
            // Left-click: toggle popover, anchored to the clicked button.
            popoverPresenter?.toggle(anchoredTo: sender)
        }
    }

    // MARK: - Menu actions
    //
    // These forward to the shared settings window and `NSApp.terminate`.
    // They intentionally don't reach into the
    // `StatsStore` directly — the menu is the "user wants to do X"
    // channel, not a data-pipeline driver.

    @objc private func menuRefreshNow() {
        popoverPresenter?.refreshFromMenu()
    }

    @objc private func menuAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "WeReadBar",
            .applicationVersion: version,
            .version: "Build \(build)"
        ])
    }

    @objc private func menuCheckForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        updateController.checkForUpdates()
    }

    @objc private func menuGoToRead() {
        NSWorkspace.shared.open(WeReadURL.homepage)
    }

    @objc private func menuSettings() {
        popoverPresenter?.showSettings()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}

/// Centralized WeRead URLs. Kept here (not in Data/WeReadClient) because
/// these are about opening the web/app, not the API.
enum WeReadURL {
    /// Web homepage. Falls back gracefully if the user has the WeRead
    /// macOS app — the OS will offer to open it natively.
    static let homepage = URL(string: "https://weread.qq.com/")!

    /// Where users go to obtain a WeRead API bearer token. Linked from
    /// the onboarding window so first-time users know how to get one.
    static let tokenHelp = URL(string: "https://weread.qq.com/r/weread-skills")!
}
