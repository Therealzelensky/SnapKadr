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
        // Yandex UI titles often use NBSP between words.
        let haystack = (snap.title + " " + snap.ownerName)
            .lowercased()
            .replacingOccurrences(of: "\u{00a0}", with: " ")
        switch source {
        case .zoom:
            let isZoom = bundle.hasPrefix("us.zoom.") || source.bundleIDs.contains(bundle)
            return isZoom && containsAny(haystack, source.titleNeedles)
        case .telegram:
            return source.bundleIDs.contains(bundle) && containsAny(haystack, source.titleNeedles)
        case .googleMeet:
            return StenoSource.isBrowser(bundle) && containsAny(haystack, source.titleNeedles)
        case .telemost:
            // Native app: lobby title stays "Яндекс Телемост" — require in-call AX chrome.
            if bundle.contains("telemost") {
                return StenoTelemostCallState.isInCall(pid: snap.ownerPID)
            }
            return StenoSource.isBrowser(bundle) && containsAny(haystack, source.titleNeedles)
        case .bitrixSync:
            let looksLikeBitrix = bundle.lowercased().contains("bitrix")
                || haystack.contains("bitrix24")
                || haystack.contains("битрикс24")
                || haystack.contains("чат и звонки")
                || haystack.contains("chat and calls")
            guard looksLikeBitrix else { return false }
            if containsAny(haystack, source.titleNeedles) { return true }
            // Live Sync keeps the IM tab title; in-call chrome is in AX of that window.
            return StenoBitrixCallState.isInCall(pid: snap.ownerPID, windowTitle: snap.title)
        case .yandexMessenger:
            // Native Electron: window title stays «Яндекс Мессенджер» — require in-call AX.
            if bundle == "ru.yandex.yamb" || bundle.hasSuffix(".yamb") {
                return StenoYandexMessengerCallState.isInCall(pid: snap.ownerPID)
            }
            guard StenoSource.isBrowser(bundle) else { return false }
            guard messengerContext(haystack) else { return false }
            return containsAny(haystack, source.titleNeedles)
        }
    }

    private static func messengerContext(_ haystack: String) -> Bool {
        haystack.contains("яндекс мессенджер")
            || haystack.contains("yandex messenger")
            || haystack.contains("yandex.ru/chat")
            || haystack.contains("messenger.yandex")
            || haystack.contains("messenger.360")
    }

    private static func containsAny(_ title: String, _ needles: [String]) -> Bool {
        needles.contains { title.contains($0) }
    }
}
