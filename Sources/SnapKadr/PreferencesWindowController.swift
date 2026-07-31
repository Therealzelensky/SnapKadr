import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    private let model = PrefsRootModel()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr("Настройки", "Preferences")
        window.minSize = NSSize(width: 640, height: 480)
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.contentView = NSHostingView(rootView: PrefsShellView(model: model))
        window.center()
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
