import Foundation
import AppKit

enum AppBranding {
    static var isBeta: Bool {
        if Bundle.main.object(forInfoDictionaryKey: "SnapKadrBetaBuild") as? Bool == true {
            return true
        }
        return Bundle.main.bundleIdentifier?.hasSuffix(".beta") == true
    }

    static var isRussianLocale: Bool {
        if let first = Locale.preferredLanguages.first?.lowercased(), first.hasPrefix("ru") {
            return true
        }
        return Locale.current.language.languageCode?.identifier == "ru"
    }

    static var displayName: String {
        if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !name.isEmpty {
            return name
        }
        if isRussianLocale {
            return isBeta ? "Щёлк.Кадр бета" : "Щёлк.Кадр"
        }
        return isBeta ? "Snap.Kadr Beta" : "Snap.Kadr"
    }

    static var shortVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.1"
    }

    static var build: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
    }

    static var siteURL: URL {
        URL(string: "https://therealzelensky.github.io/SnapKadr/")!
    }

    static var feedbackNewIssueURL: URL {
        var c = URLComponents(string: "https://github.com/Therealzelensky/app-feedback/issues/new")!
        c.queryItems = [
            URLQueryItem(name: "template", value: "beta_feedback.yml"),
            URLQueryItem(name: "title", value: "[\(isBeta ? "beta" : "release")] \(displayName) \(shortVersion) (\(build))")
        ]
        return c.url!
    }

    static var channelLabel: String { isBeta ? "beta" : "release" }

    static func applyApplicationIcon() {
        let img = NSImage(systemSymbolName: "square.split.2x1", accessibilityDescription: displayName)
            ?? NSImage(size: NSSize(width: 128, height: 128))
        NSApp.applicationIconImage = img
    }
}
