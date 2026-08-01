import AppKit

enum InstallLocationGuard {
    private static let dismissedKey = "installLocationGuard.dismissed"

    static func warnIfNeeded() {
        if UserDefaults.standard.bool(forKey: dismissedKey) { return }
        let path = Bundle.main.bundlePath
        // Allow /Applications and ~/Applications
        let inApps = path.hasPrefix("/Applications/")
            || path.hasPrefix(NSHomeDirectory() + "/Applications/")
        if inApps { return }

        let alert = NSAlert()
        alert.messageText = L10n.tr(
            "Перенеси Snap.Kadr Beta в «Программы»",
            "Move Snap.Kadr Beta to Applications"
        )
        alert.informativeText = L10n.tr(
            "Сейчас приложение запущено не из папки «Программы». Обновления и разрешения могут работать неправильно. Перетащи SnapKadrBeta в «Программы» и открой его оттуда.",
            "This app is not running from Applications. Updates and permissions may misbehave. Drag SnapKadrBeta into Applications and open it from there."
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.tr("Понятно", "OK"))
        alert.addButton(withTitle: L10n.tr("Больше не напоминать", "Don’t remind me"))
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            UserDefaults.standard.set(true, forKey: dismissedKey)
        }
    }
}
