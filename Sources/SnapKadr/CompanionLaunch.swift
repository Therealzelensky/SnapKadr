import AppKit

/// Opens Kadr companion via URL scheme until KadrKit embed (E2).
/// Prefer **release** Kadr so beta channels don't steal Carbon hotkeys from dogfood installs.
/// Snap capture is in-process via SnapKit — do not reintroduce snap URL launches here.
enum CompanionLaunch {
    static func openKadr(path: String = "capture") {
        for scheme in ["kadr", "kadr-beta"] {
            if let url = URL(string: "\(scheme)://\(path)"),
               NSWorkspace.shared.open(url) {
                return
            }
        }
        let alert = NSAlert()
        alert.messageText = AppBranding.isRussianLocale ? "Приложение не найдено" : "App not found"
        alert.informativeText = AppBranding.isRussianLocale
            ? "Установите Кадр (или бету) рядом с Щёлк.Кадр."
            : "Install Kadr (or beta) beside Snap.Kadr."
        alert.runModal()
    }
}
