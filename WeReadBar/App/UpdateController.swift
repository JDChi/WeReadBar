import Sparkle

/// Owns Sparkle's standard updater for the lifetime of the menu-bar app.
/// Sparkle keeps the user's automatic-check preference in its own defaults and
/// presents its native UI for checks, downloads, installation, and relaunch.
@MainActor
final class UpdateController {

    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
