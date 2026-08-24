import AppKit
import CoreGraphics

public enum StenoWindowProbe {
    public static func snapshots(matchingPIDs: Set<pid_t>? = nil) -> [StenoWindowSnapshot] {
        if let matchingPIDs, matchingPIDs.isEmpty {
            return []
        }
        guard let info = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var result: [StenoWindowSnapshot] = []
        for entry in info {
            if let matchingPIDs {
                let pid = entry[kCGWindowOwnerPID as String] as? pid_t
                guard let pid, matchingPIDs.contains(pid) else { continue }
            }
            if let snap = makeSnapshot(entry) {
                result.append(snap)
            }
        }
        return result
    }

    /// Session hangup must see the captured window even if the editor covers it.
    public static func snapshot(windowID: UInt32) -> StenoWindowSnapshot? {
        guard let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]] else {
            return nil
        }
        return info.compactMap(makeSnapshot).first { $0.windowID == windowID }
    }

    public static func pinSession(_ snapshots: [StenoWindowSnapshot], windowID: UInt32) -> [StenoWindowSnapshot] {
        if snapshots.contains(where: { $0.windowID == windowID }) { return snapshots }
        if let pinned = snapshot(windowID: windowID) {
            return [pinned] + snapshots
        }
        return snapshots
    }

    private static func makeSnapshot(_ entry: [String: Any]) -> StenoWindowSnapshot? {
        let layer = entry[kCGWindowLayer as String] as? Int ?? 0
        if layer != 0 { return nil }
        guard let number = entry[kCGWindowNumber as String] as? UInt32 else { return nil }
        let owner = entry[kCGWindowOwnerName as String] as? String ?? ""
        if owner.isEmpty { return nil }
        let title = entry[kCGWindowName as String] as? String ?? ""
        let pid = entry[kCGWindowOwnerPID as String] as? pid_t
        let bundle: String
        if let pid, let app = NSRunningApplication(processIdentifier: pid) {
            bundle = app.bundleIdentifier ?? ""
        } else {
            bundle = ""
        }
        return StenoWindowSnapshot(
            windowID: number,
            bundleID: bundle,
            title: title,
            ownerName: owner,
            ownerPID: pid ?? 0
        )
    }

    public static func sourcePIDs(enabled: Set<StenoSource> = StenoSettings.enabledSources) -> Set<pid_t> {
        guard !enabled.isEmpty else { return [] }
        var pids: Set<pid_t> = []
        for app in NSWorkspace.shared.runningApplications {
            guard let bundle = app.bundleIdentifier, isCandidateBundle(bundle, enabled: enabled) else {
                continue
            }
            pids.insert(app.processIdentifier)
        }
        return pids
    }

    static func isCandidateBundle(_ bundle: String, enabled: Set<StenoSource>) -> Bool {
        for source in enabled {
            switch source {
            case .zoom:
                if bundle.hasPrefix("us.zoom.") { return true }
                if source.bundleIDs.contains(bundle) { return true }
            case .telegram:
                if source.bundleIDs.contains(bundle) { return true }
            case .googleMeet:
                if StenoSource.isBrowser(bundle) { return true }
            case .telemost:
                if bundle.lowercased().contains("telemost") { return true }
                if StenoSource.isBrowser(bundle) { return true }
            case .bitrixSync:
                if bundle.lowercased().contains("bitrix") { return true }
                if StenoSource.isBrowser(bundle) { return true }
            case .yandexMessenger:
                if bundle == "ru.yandex.yamb" || bundle.hasSuffix(".yamb") { return true }
                if StenoSource.isBrowser(bundle) { return true }
            }
        }
        return false
    }
}
