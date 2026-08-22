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
            return bundle.hasPrefix("us.zoom.") || source.bundleIDs.contains(bundle)
        case .telegram:
            return source.bundleIDs.contains(bundle) && containsAny(haystack, source.titleNeedles)
        case .googleMeet:
            return StenoSource.isBrowser(bundle) && containsAny(haystack, source.titleNeedles)
        case .telemost:
            if bundle.contains("telemost") { return true }
            return StenoSource.isBrowser(bundle) && containsAny(haystack, source.titleNeedles)
        case .bitrixSync:
            if bundle.lowercased().contains("bitrix") { return true }
            guard StenoSource.isBrowser(bundle) else { return false }
            if containsAny(haystack, ["чат и звонки", "chat and calls"]) { return true }
            let hasBitrix24 = haystack.contains("bitrix24") || haystack.contains("битрикс24")
            let callish = haystack.contains("звонок") || haystack.contains("звонки")
                || haystack.contains("call") || haystack.contains("синк") || haystack.contains("sync")
            return hasBitrix24 && callish
        }
    }

    private static func containsAny(_ title: String, _ needles: [String]) -> Bool {
        needles.contains { title.contains($0) }
    }
}
