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

    /// Suite menu bar template (Snap frame + iris silhouette).
    static var menuBarIcon: NSImage {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let base = NSImage(contentsOf: url) {
            let image = NSImage(size: NSSize(width: 18, height: 18))
            image.isTemplate = true
            if let tiff = base.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff) {
                rep.size = NSSize(width: 18, height: 18)
                image.addRepresentation(rep)
            }
            if let url2x = Bundle.main.url(forResource: "MenuBarIcon@2x", withExtension: "png"),
               let img2x = NSImage(contentsOf: url2x),
               let tiff2 = img2x.tiffRepresentation,
               let rep2 = NSBitmapImageRep(data: tiff2) {
                rep2.size = NSSize(width: 18, height: 18)
                image.addRepresentation(rep2)
            }
            return image
        }
        let fallback = NSImage(systemSymbolName: "camera.aperture", accessibilityDescription: displayName)
            ?? NSImage(size: NSSize(width: 18, height: 18))
        fallback.isTemplate = true
        return fallback
    }

    static func applyApplicationIcon() {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = img
            return
        }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = img
            return
        }
        NSApp.applicationIconImage = menuBarIcon
    }
}
