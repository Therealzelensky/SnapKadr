import SwiftUI

enum PrefsTab: String, CaseIterable, Identifiable {
    case general, kadr, snap, hotkeys, notifications, version
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return L10n.tr("Общие", "General")
        case .kadr: return L10n.tr("Кадр", "Kadr")
        case .snap: return L10n.tr("Щёлк", "Snap")
        case .hotkeys: return L10n.tr("Горячие клавиши", "Hotkeys")
        case .notifications: return L10n.tr("Уведомления", "Notifications")
        case .version: return L10n.tr("Версия", "Version")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .kadr: return "video"
        case .snap: return "camera"
        case .hotkeys: return "keyboard"
        case .notifications: return "bell"
        case .version: return "info.circle"
        }
    }
}

enum L10n {
    static func tr(_ ru: String, _ en: String) -> String {
        AppBranding.isRussianLocale ? ru : en
    }
}

@MainActor
final class PrefsRootModel: ObservableObject {
    @Published var selectedTab: PrefsTab = .general
}
