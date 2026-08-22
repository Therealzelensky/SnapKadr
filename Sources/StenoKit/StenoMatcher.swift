import Foundation

public enum StenoMatcher {
    public static func match(_ snap: StenoWindowSnapshot, enabled: Set<StenoSource>) -> StenoSource? {
        for source in StenoSource.allCases where enabled.contains(source) {
            if matches(snap, source: source) { return source }
        }
        return nil
    }

    private static func matches(_ snap: StenoWindowSnapshot, source: StenoSource) -> Bool {
        let bundle = snap.bundleID
        let haystack = (snap.title + " " + snap.ownerName).lowercased()
        switch source {
        case .zoom:
            let isZoom = bundle.hasPrefix("us.zoom.") || source.bundleIDs.contains(bundle)
            return isZoom && containsAny(haystack, source.titleNeedles)
        case .telegram:
            return source.bundleIDs.contains(bundle) && containsAny(haystack, source.titleNeedles)
        case .googleMeet:
            return StenoSource.isBrowser(bundle) && containsAny(haystack, source.titleNeedles)
        case .telemost:
            if bundle.contains("telemost") { return true }
            return StenoSource.isBrowser(bundle) && containsAny(haystack, source.titleNeedles)
        case .bitrixSync:
            guard containsAny(haystack, source.titleNeedles) else { return false }
            if bundle.lowercased().contains("bitrix") { return true }
            guard StenoSource.isBrowser(bundle) else { return false }
            return haystack.contains("bitrix24") || haystack.contains("битрикс24")
        }
    }

    private static func containsAny(_ title: String, _ needles: [String]) -> Bool {
        needles.contains { title.contains($0) }
    }
}
