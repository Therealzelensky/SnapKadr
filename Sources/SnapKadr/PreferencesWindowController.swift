import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    private let model = SuitePrefsModel()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("Настройки", "Preferences")
        window.isReleasedWhenClosed = false
        self.init(window: window)
        let root = SuitePreferencesView(model: model) { [weak self] in
            self?.window?.orderOut(nil)
        }
        window.contentView = NSHostingView(rootView: root)
        window.center()
    }

    func show() {
        model.reload()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
