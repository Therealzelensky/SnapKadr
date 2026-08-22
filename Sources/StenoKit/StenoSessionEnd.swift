import Foundation

public enum StenoSessionEnd {
    /// Hangup / leave: the window we started on is gone, reused, or no longer a call.
    public static func shouldStop(
        sessionWindowID: UInt32,
        sessionPID: pid_t,
        sessionBundleID: String,
        snapshots: [StenoWindowSnapshot],
        enabled: Set<StenoSource>
    ) -> Bool {
        guard let snap = snapshots.first(where: { $0.windowID == sessionWindowID }) else {
            return true
        }
        if sessionPID != 0, snap.ownerPID != sessionPID { return true }
        if !sessionBundleID.isEmpty, snap.bundleID != sessionBundleID { return true }
        return StenoMatcher.match(snap, enabled: enabled) == nil
    }
}
