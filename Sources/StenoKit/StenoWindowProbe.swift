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
            let layer = entry[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { continue }
            guard let number = entry[kCGWindowNumber as String] as? UInt32 else { continue }
            let owner = entry[kCGWindowOwnerName as String] as? String ?? ""
            if owner.isEmpty { continue }
            let title = entry[kCGWindowName as String] as? String ?? ""
            let pid = entry[kCGWindowOwnerPID as String] as? pid_t
            if let matchingPIDs {
                guard let pid, matchingPIDs.contains(pid) else { continue }
            }
            let bundle: String
            if let pid, let app = NSRunningApplication(processIdentifier: pid) {
                bundle = app.bundleIdentifier ?? ""
            } else {
                bundle = ""
            }
            result.append(StenoWindowSnapshot(
                windowID: number,
                bundleID: bundle,
                title: title,
                ownerName: owner,
                ownerPID: pid ?? 0
            ))
        }
        return result
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
            }
        }
        return false
    }
}
