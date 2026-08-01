import Foundation
import AppKit
import Combine
import Sparkle

/// Sparkle wrapper — check for updates; exposes pending-update state for prefs UI.
final class UpdateService: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateService()

    @Published private(set) var updateAvailable = false
    @Published private(set) var pendingShortVersion: String?
    @Published private(set) var pendingBuild: String?

    private var controller: SPUStandardUpdaterController?
    private var foundUpdateThisCycle = false

    func start() {
        guard controller == nil else {
            applyAutomaticUpdatePolicy()
            return
        }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        applyAutomaticUpdatePolicy()
    }

    /// When auto-check is on: background check + download + silent install.
    /// When off: only user-initiated checks (standard Sparkle UI).
    func applyAutomaticUpdatePolicy() {
        let enabled = SuiteSharedSettings.autoCheckUpdates
        guard let updater = controller?.updater else { return }
        updater.automaticallyChecksForUpdates = enabled
        updater.automaticallyDownloadsUpdates = enabled
        // Sparkle 2 user default: install downloaded updates without prompting
        UserDefaults.standard.set(enabled, forKey: "SUAutomaticallyUpdate")
    }

    func checkForUpdates() {
        start()
        foundUpdateThisCycle = false
        controller?.checkForUpdates(nil)
    }

    func checkForUpdatesInBackground() {
        start()
        foundUpdateThisCycle = false
        controller?.updater.checkForUpdatesInBackground()
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? true }
        set {
            start()
            if SuiteSharedSettings.autoCheckUpdates != newValue {
                SuiteSharedSettings.autoCheckUpdates = newValue
            } else {
                applyAutomaticUpdatePolicy()
            }
        }
    }

    // MARK: SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let shortV = item.displayVersionString
        let build = item.versionString
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.foundUpdateThisCycle = true
            self.updateAvailable = true
            self.pendingShortVersion = shortV
            self.pendingBuild = build
        }
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.foundUpdateThisCycle {
                self.updateAvailable = false
                self.pendingShortVersion = nil
                self.pendingBuild = nil
            }
            self.foundUpdateThisCycle = false
        }
    }
}
