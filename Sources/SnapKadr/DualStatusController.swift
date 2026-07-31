import AppKit

final class DualStatusController {
    private let snapItem: NSStatusItem
    private let kadrItem: NSStatusItem
    private let onPreferences: () -> Void
    private let onQuit: () -> Void

    init(onPreferences: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onPreferences = onPreferences
        self.onQuit = onQuit

        snapItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        kadrItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = snapItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Щёлк")
            button.image?.isTemplate = true
            button.toolTip = AppBranding.isRussianLocale ? "Щёлк (suite)" : "Snap (suite)"
        }
        if let button = kadrItem.button {
            button.image = NSImage(systemSymbolName: "film", accessibilityDescription: "Кадр")
            button.image?.isTemplate = true
            button.toolTip = AppBranding.isRussianLocale ? "Кадр (suite)" : "Kadr (suite)"
            if AppBranding.isBeta {
                button.title = "β"
                button.imagePosition = .imageLeading
            }
        }

        snapItem.menu = makeSnapMenu()
        kadrItem.menu = makeKadrMenu()
    }

    private func makeSnapMenu() -> NSMenu {
        let m = NSMenu()
        m.addItem(item(AppBranding.isRussianLocale ? "Область" : "Area", #selector(snapArea)))
        m.addItem(item(AppBranding.isRussianLocale ? "Весь экран" : "Fullscreen", #selector(snapFull)))
        m.addItem(item(AppBranding.isRussianLocale ? "Окно" : "Window", #selector(snapWindow)))
        m.addItem(.separator())
        m.addItem(item(AppBranding.isRussianLocale ? "Настройки…" : "Preferences…", #selector(prefs)))
        m.addItem(item(AppBranding.isRussianLocale ? "Выйти" : "Quit", #selector(quit)))
        m.items.forEach { $0.target = self }
        return m
    }

    private func makeKadrMenu() -> NSMenu {
        let m = NSMenu()
        m.addItem(item(AppBranding.isRussianLocale ? "Панель захвата" : "Capture bar", #selector(kadrCapture)))
        m.addItem(item(AppBranding.isRussianLocale ? "Запись экрана" : "Record display", #selector(kadrDisplay)))
        m.addItem(.separator())
        m.addItem(item(AppBranding.isRussianLocale ? "Настройки…" : "Preferences…", #selector(prefs)))
        m.addItem(item(AppBranding.isRussianLocale ? "Выйти" : "Quit", #selector(quit)))
        m.items.forEach { $0.target = self }
        return m
    }

    private func item(_ title: String, _ sel: Selector) -> NSMenuItem {
        NSMenuItem(title: title, action: sel, keyEquivalent: "")
    }

    @objc private func snapArea() { CompanionLaunch.openSnap(path: "area") }
    @objc private func snapFull() { CompanionLaunch.openSnap(path: "full") }
    @objc private func snapWindow() { CompanionLaunch.openSnap(path: "window") }
    @objc private func kadrCapture() { CompanionLaunch.openKadr(path: "capture") }
    @objc private func kadrDisplay() { CompanionLaunch.openKadr(path: "display") }
    @objc private func prefs() { onPreferences() }
    @objc private func quit() { onQuit() }
}
