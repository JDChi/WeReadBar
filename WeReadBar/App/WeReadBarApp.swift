import SwiftUI

/// Minimal SwiftUI App whose sole purpose is to own the NSApplication
/// event loop. All real work (status item, popover, right-click menu)
/// happens in `AppDelegate`, attached via `@NSApplicationDelegateAdaptor`.
///
/// `Settings { EmptyView() }` is a no-op scene — required because SwiftUI
/// `App` requires at least one Scene. It's dormant for our `LSUIElement`
/// app since Cmd+, has no menu item in the (non-existent) app menu.
@main
struct WeReadBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
