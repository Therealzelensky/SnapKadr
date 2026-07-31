import Foundation
import AppKit
import Sparkle

/// Sparkle wrapper — check for updates from GitHub Releases appcast.
final class UpdateService: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateService()

    private var controller: SPUStandardUpdaterController?

    func start() {
        guard controller == nil else { return }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        start()
        controller?.checkForUpdates(nil)
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? true }
        set {
            start()
            controller?.updater.automaticallyChecksForUpdates = newValue
        }
    }
}
