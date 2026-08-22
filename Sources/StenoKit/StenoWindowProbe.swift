import AppKit
import CoreGraphics

public enum StenoWindowProbe {
    public static func snapshots() -> [StenoWindowSnapshot] {
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
            let bundle: String
            if let pid, let app = NSRunningApplication(processIdentifier: pid) {
                bundle = app.bundleIdentifier ?? ""
            } else {
                bundle = ""
            }
            result.append(StenoWindowSnapshot(windowID: number, bundleID: bundle, title: title, ownerName: owner))
        }
        return result
    }
}
