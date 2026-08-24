import Foundation

public enum StenoSessionEnd {
    /// Hangup / leave: the window we started on is gone, reused, or no longer a call.
    /// If the host recreates the call window (same PID), that is NOT a hangup.
    /// Browser sessions stay pinned to the call tab: a different Safari tab in the
    /// same window (or other tabs the editor lists) is not hangup.
    public static func shouldStop(
        sessionWindowID: UInt32,
        sessionPID: pid_t,
        sessionBundleID: String,
        snapshots: [StenoWindowSnapshot],
        enabled: Set<StenoSource>,
        sessionTitle: String = "",
        sessionSource: StenoSource? = nil
    ) -> Bool {
        if let snap = snapshots.first(where: { $0.windowID == sessionWindowID }) {
            if sessionPID != 0, snap.ownerPID != sessionPID { return true }
            if !sessionBundleID.isEmpty, snap.bundleID != sessionBundleID { return true }
            if isBrowserTabSwitch(
                sessionTitle: sessionTitle,
                currentTitle: snap.title,
                sessionBundleID: sessionBundleID,
                currentBundleID: snap.bundleID,
                sessionSource: sessionSource
            ) {
                return false
            }
            return StenoMatcher.match(snap, enabled: enabled) == nil
        }
        return replacementWindowID(
            sessionWindowID: sessionWindowID,
            sessionPID: sessionPID,
            sessionBundleID: sessionBundleID,
            snapshots: snapshots,
            enabled: enabled,
            sessionTitle: sessionTitle,
            sessionSource: sessionSource
        ) == nil
    }

    /// When the original window id disappears but the same process still has a call window.
    public static func replacementWindowID(
        sessionWindowID: UInt32,
        sessionPID: pid_t,
        sessionBundleID: String,
        snapshots: [StenoWindowSnapshot],
        enabled: Set<StenoSource>,
        sessionTitle: String = "",
        sessionSource: StenoSource? = nil
    ) -> UInt32? {
        if snapshots.contains(where: { $0.windowID == sessionWindowID }) { return nil }
        let pinToIdentity = !sessionTitle.isEmpty && isBrowserBundle(sessionBundleID)
        let candidates: [StenoWindowSnapshot]
        if sessionPID != 0 {
            candidates = snapshots.filter { snap in
                snap.ownerPID == sessionPID && StenoMatcher.match(snap, enabled: enabled) != nil
            }
        } else if !sessionBundleID.isEmpty {
            candidates = snapshots.filter { snap in
                snap.bundleID == sessionBundleID && StenoMatcher.match(snap, enabled: enabled) != nil
            }
        } else {
            return nil
        }
        if pinToIdentity {
            return candidates.first(where: {
                isSameCallIdentity(sessionTitle: sessionTitle, otherTitle: $0.title, source: sessionSource)
            })?.windowID
        }
        return candidates.first?.windowID
    }

    public static func isSameCallIdentity(
        sessionTitle: String,
        otherTitle: String,
        source: StenoSource?
    ) -> Bool {
        let a = normalize(sessionTitle)
        let b = normalize(otherTitle)
        if a.isEmpty || b.isEmpty { return false }
        if a == b { return true }
        switch source {
        case .bitrixSync:
            return sameBitrixIdentity(a, b)
        case .googleMeet:
            return looksLikeMeet(a) && looksLikeMeet(b)
        case .telemost:
            return looksLikeTelemost(a) && looksLikeTelemost(b)
        case .yandexMessenger:
            return looksLikeMessenger(a) && looksLikeMessenger(b)
        default:
            return false
        }
    }

    private static func isBrowserTabSwitch(
        sessionTitle: String,
        currentTitle: String,
        sessionBundleID: String,
        currentBundleID: String,
        sessionSource: StenoSource?
    ) -> Bool {
        guard isBrowserBundle(sessionBundleID) || isBrowserBundle(currentBundleID) else { return false }
        guard !sessionTitle.isEmpty else { return false }
        return !isSameCallIdentity(
            sessionTitle: sessionTitle,
            otherTitle: currentTitle,
            source: sessionSource
        )
    }

    private static func isBrowserBundle(_ bundle: String) -> Bool {
        !bundle.isEmpty && StenoSource.isBrowser(bundle)
    }

    private static func sameBitrixIdentity(_ a: String, _ b: String) -> Bool {
        guard looksLikeBitrixTab(a), looksLikeBitrixTab(b) else { return false }
        let pa = bitrixPortal(a)
        let pb = bitrixPortal(b)
        if pa.isEmpty || pb.isEmpty { return false }
        return pa == pb
    }

    private static func looksLikeBitrixTab(_ s: String) -> Bool {
        s.contains("чат и звонки")
            || s.contains("chat and calls")
            || s.contains("видеозвонок")
            || s.contains("video call")
            || s.contains("bitrix24")
            || s.contains("битрикс24")
    }

    private static func bitrixPortal(_ s: String) -> String {
        var t = s
        for cut in ["чат и звонки", "chat and calls", "видеозвонок", "video call", "bitrix24", "битрикс24"] {
            if let r = t.range(of: cut) {
                t = String(t[..<r.lowerBound])
            }
        }
        let token = t.split { !$0.isLetter && !$0.isNumber }.first.map(String.init) ?? ""
        return token
    }

    private static func looksLikeMeet(_ s: String) -> Bool {
        s.contains("meet.google") || s.contains("google meet") || s.contains("meet -")
            || s.contains("meet –") || s.contains("meet—")
    }

    private static func looksLikeTelemost(_ s: String) -> Bool {
        s.contains("telemost") || s.contains("телемост")
    }

    private static func looksLikeMessenger(_ s: String) -> Bool {
        s.contains("яндекс мессенджер") || s.contains("yandex messenger")
            || s.contains("yandex.ru/chat") || s.contains("messenger.yandex")
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "\u{00a0}", with: " ")
    }
}
