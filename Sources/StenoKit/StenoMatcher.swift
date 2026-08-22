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
        let title = snap.title.lowercased()
        switch source {
        case .zoom:
            return source.bundleIDs.contains(bundle)
        case .telegram:
            return source.bundleIDs.contains(bundle) && containsAny(title, source.titleNeedles)
        case .googleMeet:
            return StenoSource.browserBundleIDs.contains(bundle) && containsAny(title, source.titleNeedles)
        case .telemost:
            return source.bundleIDs.contains(bundle) && containsAny(title, source.titleNeedles)
        case .bitrixSync:
            if bundle.lowercased().contains("bitrix") { return true }
            let isBrowser = StenoSource.browserBundleIDs.contains(bundle)
            let hasBitrix24 = title.contains("bitrix24")
            let callish = title.contains("звонок") || title.contains("call")
                || title.contains("синк") || title.contains("sync")
            return isBrowser && hasBitrix24 && callish
        }
    }

    private static func containsAny(_ title: String, _ needles: [String]) -> Bool {
        needles.contains { title.contains($0) }
    }
}
