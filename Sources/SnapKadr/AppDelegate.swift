import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: DualStatusController?
    private var prefs: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppBranding.applyApplicationIcon()
        UpdateService.shared.start()

        status = DualStatusController(
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

    private func showPreferences() {
        if prefs == nil {
            prefs = PreferencesWindowController()
        }
        prefs?.show()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
