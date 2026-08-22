import Foundation

public struct StenoShareHit: Equatable, Sendable {
    public var windowID: UInt32
    public var title: String

    public init(windowID: UInt32, title: String) {
        self.windowID = windowID
        self.title = title
    }
}

public enum StenoShareProbe {
    /// Among `snapshots`, find a screen-share window belonging to the same call process/source.
    public static func findShare(
        call: StenoDetectedCall,
        callPID: pid_t,
        snapshots: [StenoWindowSnapshot]
    ) -> StenoShareHit? {
        if call.source == .telegram { return nil }

        let needles = shareNeedles(for: call.source)
        for snap in snapshots {
            guard snap.windowID != call.windowID else { continue }
            guard belongsToCall(snap, call: call, callPID: callPID) else { continue }
            let lower = snap.title.lowercased()
            guard needles.contains(where: { lower.contains($0) }) else { continue }
            return StenoShareHit(windowID: snap.windowID, title: snap.title)
        }
        return nil
    }

    private static func shareNeedles(for source: StenoSource) -> [String] {
        switch source {
        case .zoom:
            return ["sharing", "screen share", "демонстрац", "you are sharing"]
        case .googleMeet, .telemost, .bitrixSync:
            return ["presenting", "you are presenting", "демонстрац", "sharing screen", "sharing"]
        case .telegram:
            return []
        }
    }

    private static func belongsToCall(
        _ snap: StenoWindowSnapshot,
        call: StenoDetectedCall,
        callPID: pid_t
    ) -> Bool {
        if callPID != 0, snap.ownerPID == callPID { return true }
        // Zoom may spawn share UI under a sibling Zoom process.
        if call.source == .zoom {
            return snap.bundleID.contains("us.zoom.")
        }
        return false
    }
}
