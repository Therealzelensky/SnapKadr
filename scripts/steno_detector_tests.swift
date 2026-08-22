import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoDetectorTests {
    static func main() {
        var state = StenoSnoozeState()
        expect(!state.isSnoozed(10), "fresh not snoozed")
        state.snooze(10)
        expect(state.isSnoozed(10), "snoozed id")
        expect(!state.isSnoozed(11), "other id")

        state.reap(presentIDs: [10, 11])
        expect(state.isSnoozed(10), "still present keeps snooze")

        state.reap(presentIDs: [11])
        expect(!state.isSnoozed(10), "gone window drops snooze")

        state.snooze(11)
        state.reap(presentIDs: [])
        expect(!state.isSnoozed(11), "empty probe clears snooze")

        let all = Set(StenoSource.allCases)
        let zoom = StenoWindowSnapshot(windowID: 42, bundleID: "us.zoom.xos", title: "Zoom Meeting", ownerName: "zoom.us")
        expect(
            !StenoSessionEnd.shouldStop(sessionWindowID: 42, snapshots: [zoom], enabled: all),
            "live zoom window keeps session"
        )
        expect(
            StenoSessionEnd.shouldStop(sessionWindowID: 42, snapshots: [], enabled: all),
            "closed call window ends session"
        )
        let leftover = StenoWindowSnapshot(
            windowID: 42,
            bundleID: "com.apple.Safari",
            title: "Hacker News",
            ownerName: "Safari"
        )
        expect(
            StenoSessionEnd.shouldStop(sessionWindowID: 42, snapshots: [leftover], enabled: all),
            "window still open but no longer a call ends session"
        )
        let otherCall = StenoWindowSnapshot(
            windowID: 99,
            bundleID: "us.zoom.xos",
            title: "Other meeting",
            ownerName: "zoom.us"
        )
        expect(
            StenoSessionEnd.shouldStop(sessionWindowID: 42, snapshots: [otherCall], enabled: all),
            "a different call window does not keep this session"
        )

        exit(failures == 0 ? 0 : 1)
    }
}
