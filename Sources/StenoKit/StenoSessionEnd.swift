import Foundation

public enum StenoSessionEnd {
    /// Hangup / leave: the window we started on is gone, reused, or no longer a call.
    /// If the host recreates the call window (same PID), that is NOT a hangup.
    public static func shouldStop(
        sessionWindowID: UInt32,
        sessionPID: pid_t,
        sessionBundleID: String,
        snapshots: [StenoWindowSnapshot],
        enabled: Set<StenoSource>
    ) -> Bool {
        if let snap = snapshots.first(where: { $0.windowID == sessionWindowID }) {
            if sessionPID != 0, snap.ownerPID != sessionPID { return true }
            if !sessionBundleID.isEmpty, snap.bundleID != sessionBundleID { return true }
            return StenoMatcher.match(snap, enabled: enabled) == nil
        }
        return replacementWindowID(
            sessionWindowID: sessionWindowID,
            sessionPID: sessionPID,
            sessionBundleID: sessionBundleID,
            snapshots: snapshots,
            enabled: enabled
        ) == nil
    }

    /// When the original window id disappears but the same process still has a call window.
    public static func replacementWindowID(
        sessionWindowID: UInt32,
        sessionPID: pid_t,
        sessionBundleID: String,
        snapshots: [StenoWindowSnapshot],
        enabled: Set<StenoSource>
    ) -> UInt32? {
        if snapshots.contains(where: { $0.windowID == sessionWindowID }) { return nil }
        if sessionPID != 0 {
            return snapshots.first(where: { snap in
                snap.ownerPID == sessionPID && StenoMatcher.match(snap, enabled: enabled) != nil
            })?.windowID
        }
        if !sessionBundleID.isEmpty {
            return snapshots.first(where: { snap in
                snap.bundleID == sessionBundleID && StenoMatcher.match(snap, enabled: enabled) != nil
            })?.windowID
        }
        return nil
    }
}
