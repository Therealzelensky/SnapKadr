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
            return ["ru.keepcoder.Telegram"]
        case .telemost:
            return Self.browserBundleIDs + ["ru.yandex.telemost"]
        case .bitrixSync:
            return []
        }
    }

    public var titleNeedles: [String] {
        switch self {
        case .zoom:
            return []
        case .googleMeet:
            return ["meet.google", "google meet", "meet -"]
        case .telegram:
            return ["call", "звонок", "группов"]
        case .telemost:
            return ["телемост", "telemost"]
        case .bitrixSync:
            return ["bitrix24"]
        }
    }

    static let browserBundleIDs: [String] = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.apple.Safari",
        "org.mozilla.firefox",
        "ru.yandex.desktop",
        "ru.yandex.browser",
    ]
}

public struct StenoWindowSnapshot: Equatable, Sendable {
    public var windowID: UInt32
    public var bundleID: String
    public var title: String
    public var ownerName: String

    public init(windowID: UInt32, bundleID: String, title: String, ownerName: String) {
        self.windowID = windowID
        self.bundleID = bundleID
        self.title = title
        self.ownerName = ownerName
    }
}
