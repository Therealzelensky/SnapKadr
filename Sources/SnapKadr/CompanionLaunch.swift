import AppKit

/// Opens companion apps via URL schemes when installed; suite keeps its own chrome.
enum CompanionLaunch {
    static func openSnap(path: String = "area") {
        open(schemeCandidates: ["snap-beta", "snap"], path: path)
    }

    static func openKadr(path: String = "capture") {
        open(schemeCandidates: ["kadr-beta", "kadr"], path: path)
    }

    private static func open(schemeCandidates: [String], path: String) {
        for scheme in schemeCandidates {
            if let url = URL(string: "\(scheme)://\(path)"),
               NSWorkspace.shared.open(url) {
                return
            }
        }
        let alert = NSAlert()
        alert.messageText = AppBranding.isRussianLocale ? "Приложение не найдено" : "App not found"
        alert.informativeText = AppBranding.isRussianLocale
            ? "Установите Щёлк / Кадр (или их беты) рядом с Щёлк.Кадр."
            : "Install Snap / Kadr (or betas) beside Snap.Kadr."
        alert.runModal()
    }
}
