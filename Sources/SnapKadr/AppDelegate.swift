import AppKit
import SnapKit
import KadrKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: SuiteStatusController?
    private var prefs: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppBranding.applyApplicationIcon()
        UpdateService.shared.start()
        InstallLocationGuard.warnIfNeeded()
        SnapEngine.shared.prepare()
        KadrEngine.shared.prepare()
        SuiteHotkeyMonitor.shared.start()

        status = SuiteStatusController(
            onPreferences: { [weak self] in self?.showPreferences() },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPreferences()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.pathExtension.lowercased() == "kadr" {
            KadrEngine.shared.openProject(at: url)
        }
    }

    private func showPreferences() {
        if prefs == nil {
            prefs = PreferencesWindowController()
        }
        prefs?.show()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
