import Foundation

public enum StenoSource: String, CaseIterable, Sendable {
    case zoom
    case googleMeet
    case telegram
    case telemost
    case bitrixSync

    public var bundleIDs: [String] {
        switch self {
        case .zoom:
            return ["us.zoom.xos", "us.zoom.ZoomPresence"]
        case .googleMeet:
            return Self.browserBundleIDs
        case .telegram:
            return ["ru.keepcoder.Telegram", "org.telegram.desktop", "com.tdesktop.Telegram"]
        case .telemost:
            return Self.browserBundleIDs + ["ru.yandex.telemost", "ru.yandex.desktop.telemost"]
        case .bitrixSync:
            return []
        }
    }

    public var titleNeedles: [String] {
        switch self {
        case .zoom:
            return ["zoom meeting", "zoom webinar", "meeting", "webinar", "конференц", "вебинар"]
        case .googleMeet:
            // In-call Chrome tab is often "Meet – …" (en dash), not "Meet -".
            return ["meet.google", "google meet", "meet -", "meet –", "meet—"]
        case .telegram:
            return ["call", "звонок", "звонки", "группов", "видеозвон"]
        case .telemost:
            return ["телемост", "telemost"]
        case .bitrixSync:
            return ["видеозвонок", "video call", "идёт звонок", "идет звонок", "incoming call", "исходящ"]
        }
    }

    static let browserBundleIDs: [String] = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
        "com.apple.Safari",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "ru.yandex.desktop",
        "ru.yandex.browser",
        "ru.yandex.desktop.yandex-browser",
        "ru.cryptopro.chromium-gost",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
    ]

    public static func isBrowser(_ bundle: String) -> Bool {
        if browserBundleIDs.contains(bundle) { return true }
        if bundle.hasPrefix("com.apple.Safari.WebApp.") { return true }
        if bundle.hasPrefix("com.google.Chrome.app.") { return true }
        if bundle.hasPrefix("com.microsoft.edgemac") { return true }
        return false
    }
}

public struct StenoWindowSnapshot: Equatable, Sendable {
    public var windowID: UInt32
    public var bundleID: String
    public var title: String
    public var ownerName: String
    public var ownerPID: pid_t

    public init(windowID: UInt32, bundleID: String, title: String, ownerName: String, ownerPID: pid_t = 0) {
        self.windowID = windowID
        self.bundleID = bundleID
        self.title = title
        self.ownerName = ownerName
        self.ownerPID = ownerPID
    }
}
