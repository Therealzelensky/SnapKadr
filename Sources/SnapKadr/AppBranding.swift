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

    /// Ship tag for UI (e.g. `v0.1.0-beta.8`). Falls back to marketing short version.
    static var releaseLabel: String {
        if let tag = Bundle.main.object(forInfoDictionaryKey: "SnapKadrReleaseTag") as? String {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return shortVersion
    }

    static var siteURL: URL {
        URL(string: "https://therealzelensky.github.io/SnapKadr/")!
    }

    static var developerGitHubURL: URL {
        URL(string: "https://github.com/Therealzelensky")!
    }

    static var snapReleasesURL: URL {
        URL(string: "https://github.com/Therealzelensky/Snap/releases")!
    }

    static var kadrReleasesURL: URL {
        URL(string: "https://github.com/Therealzelensky/Kadr/releases")!
    }

    static var suiteReleasesURL: URL {
        URL(string: "https://github.com/Therealzelensky/SnapKadr/releases")!
    }

    static var feedbackNewIssueURL: URL {
        var c = URLComponents(string: "https://github.com/Therealzelensky/app-feedback/issues/new")!
        c.queryItems = [
            URLQueryItem(name: "template", value: "beta_feedback.yml"),
            URLQueryItem(name: "title", value: "[\(isBeta ? "beta" : "release")] \(displayName) \(releaseLabel) (\(build))")
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
