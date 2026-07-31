import Foundation

/// Suite-owned prefs that live on the Общие / Версия tabs.
/// Snap-overlapping keys use the same raw names as Snap `AppSettings` so in-process SnapKit can read them later.
enum SuiteSharedSettings {
    private static let d = UserDefaults.standard

    static var showSplash: Bool {
        get { d.object(forKey: "showSplash") as? Bool ?? true }
        set { d.set(newValue, forKey: "showSplash") }
    }

    static var hideMenubarIcon: Bool {
        get { d.bool(forKey: "hideMenubarIcon") }
        set { d.set(newValue, forKey: "hideMenubarIcon") }
    }

    static var urlSchemeEnabled: Bool {
        get { d.object(forKey: "urlSchemeEnabled") as? Bool ?? true }
        set { d.set(newValue, forKey: "urlSchemeEnabled") }
    }

    static var allowDiagnostics: Bool {
        get { d.object(forKey: "allowDiagnostics") as? Bool ?? true }
        set { d.set(newValue, forKey: "allowDiagnostics") }
    }

    static var confirmationStyleRaw: String {
        get { d.string(forKey: "confirmationStyle") ?? "notch" }
        set { d.set(newValue, forKey: "confirmationStyle") }
    }

    static var autoCheckUpdates: Bool {
        get { d.object(forKey: "shared.autoCheckUpdates") as? Bool ?? true }
        set {
            d.set(newValue, forKey: "shared.autoCheckUpdates")
            UpdateService.shared.automaticallyChecksForUpdates = newValue
        }
    }
}

enum SuiteConfirmationStyle: String, CaseIterable, Identifiable {
    case notch, alert, none
    var id: String { rawValue }

    var title: String {
        switch self {
        case .notch: return L10n.tr("Уведомление (Dynamic Island)", "Notification (Dynamic Island)")
        case .alert: return L10n.tr("Системное окно", "System alert")
        case .none: return L10n.tr("Без подтверждения", "None")
        }
    }
}
