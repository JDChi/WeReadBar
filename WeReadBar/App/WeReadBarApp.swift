import SwiftUI
import AppKit

@main
struct WeReadBarApp: App {
    @StateObject private var store = StatsStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(store)
        } label: {
            Image(systemName: "book.closed.fill")
                .contextMenu {
                    Button("Refresh now") {
                        Task { await store.refresh() }
                    }
                    Divider()
                    Button("Change API key…") {
                        store.needsAPIKey = true
                        OnboardingWindowController.shared.show(store: store)
                    }
                    Divider()
                    Button("Quit WeReadBar") {
                        NSApp.terminate(nil)
                    }
                }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Minimal NSApplicationDelegate. Currently a placeholder for any future
/// app-lifecycle hooks (e.g., global hotkeys, login-item registration).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app behaves as a menu-bar app even before SwiftUI wiring kicks in.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar apps don't quit when a popover closes.
        false
    }
}
