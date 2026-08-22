import Foundation

public enum StenoSessionEnd {
    /// Hangup / leave: the window we started on is gone, or it is no longer a call.
    public static func shouldStop(
        sessionWindowID: UInt32,
        snapshots: [StenoWindowSnapshot],
        enabled: Set<StenoSource>
    ) -> Bool {
        guard let snap = snapshots.first(where: { $0.windowID == sessionWindowID }) else {
            return true
        }
        return StenoMatcher.match(snap, enabled: enabled) == nil
    }
}
