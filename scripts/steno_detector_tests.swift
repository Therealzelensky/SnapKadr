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
        let zoom = StenoWindowSnapshot(
            windowID: 42,
            bundleID: "us.zoom.xos",
            title: "Zoom Meeting",
            ownerName: "zoom.us",
            ownerPID: 99
        )
        expect(
            !StenoSessionEnd.shouldStop(
                sessionWindowID: 42,
                sessionPID: 99,
                sessionBundleID: "us.zoom.xos",
                snapshots: [zoom],
                enabled: all
            ),
            "live zoom window keeps session"
        )
        expect(
            StenoSessionEnd.shouldStop(
                sessionWindowID: 42,
                sessionPID: 99,
                sessionBundleID: "us.zoom.xos",
                snapshots: [],
                enabled: all
            ),
            "closed call window ends session"
        )
        let leftover = StenoWindowSnapshot(
            windowID: 42,
            bundleID: "com.apple.Safari",
            title: "Hacker News",
            ownerName: "Safari",
            ownerPID: 99
        )
        expect(
            StenoSessionEnd.shouldStop(
                sessionWindowID: 42,
                sessionPID: 99,
                sessionBundleID: "us.zoom.xos",
                snapshots: [leftover],
                enabled: all
            ),
            "window still open but no longer a call ends session"
        )
        let otherCall = StenoWindowSnapshot(
            windowID: 99,
            bundleID: "us.zoom.xos",
            title: "Other meeting",
            ownerName: "zoom.us",
            ownerPID: 50
        )
        expect(
            StenoSessionEnd.shouldStop(
                sessionWindowID: 42,
                sessionPID: 99,
                sessionBundleID: "us.zoom.xos",
                snapshots: [otherCall],
                enabled: all
            ),
            "a different call window does not keep this session"
        )
        let reused = StenoWindowSnapshot(
            windowID: 42,
            bundleID: "com.apple.Safari",
            title: "News",
            ownerName: "Safari",
            ownerPID: 100
        )
        expect(
            StenoSessionEnd.shouldStop(
                sessionWindowID: 42,
                sessionPID: 99,
                sessionBundleID: "us.zoom.xos",
                snapshots: [reused],
                enabled: all
            ),
            "reused window id ends session"
        )

        let replaced = StenoWindowSnapshot(
            windowID: 77,
            bundleID: "us.zoom.xos",
            title: "Zoom Meeting",
            ownerName: "zoom.us",
            ownerPID: 99
        )
        expect(
            !StenoSessionEnd.shouldStop(
                sessionWindowID: 42,
                sessionPID: 99,
                sessionBundleID: "us.zoom.xos",
                snapshots: [replaced],
                enabled: all
            ),
            "same PID new window id still a call keeps session"
        )
        expect(
            StenoSessionEnd.replacementWindowID(
                sessionWindowID: 42,
                sessionPID: 99,
                sessionBundleID: "us.zoom.xos",
                snapshots: [replaced],
                enabled: all
            ) == 77,
            "replacement window id for retarget"
        )

        let safariCall = StenoWindowSnapshot(
            windowID: 42,
            bundleID: "com.apple.Safari",
            title: "Ортобум — (23) Чат и звонки",
            ownerName: "Safari",
            ownerPID: 1545
        )
        let safariOtherTab = StenoWindowSnapshot(
            windowID: 42,
            bundleID: "com.apple.Safari",
            title: "ГорСтрой — прототипы",
            ownerName: "Safari",
            ownerPID: 1545
        )
        expect(
            !StenoSessionEnd.shouldStop(
                sessionWindowID: 42,
                sessionPID: 1545,
                sessionBundleID: "com.apple.Safari",
                snapshots: [safariOtherTab],
                enabled: all,
                sessionTitle: safariCall.title,
                sessionSource: .bitrixSync
            ),
            "browser tab switch in the session window is not hangup"
        )
        let editorTabs = [
            StenoWindowSnapshot(
                windowID: 88,
                bundleID: "com.apple.Safari",
                title: "Hacker News",
                ownerName: "Safari",
                ownerPID: 1545
            ),
            StenoWindowSnapshot(
                windowID: 90,
                bundleID: "com.apple.Safari",
                title: "Standup - Google Meet",
                ownerName: "Safari",
                ownerPID: 1545
            ),
            safariOtherTab,
        ]
        expect(
            !StenoSessionEnd.shouldStop(
                sessionWindowID: 42,
                sessionPID: 1545,
                sessionBundleID: "com.apple.Safari",
                snapshots: editorTabs,
                enabled: all,
                sessionTitle: safariCall.title,
                sessionSource: .bitrixSync
            ),
            "other safari tabs in the editor do not end the pinned session"
        )
        expect(
            StenoSessionEnd.replacementWindowID(
                sessionWindowID: 41,
                sessionPID: 1545,
                sessionBundleID: "com.apple.Safari",
                snapshots: editorTabs,
                enabled: all,
                sessionTitle: safariCall.title,
                sessionSource: .bitrixSync
            ) == nil,
            "do not retarget hangup to an unrelated safari tab"
        )
        let samePortal = StenoWindowSnapshot(
            windowID: 77,
            bundleID: "com.apple.Safari",
            title: "Ортобум — Видеозвонок — Bitrix24",
            ownerName: "Safari",
            ownerPID: 1545
        )
        expect(
            StenoSessionEnd.replacementWindowID(
                sessionWindowID: 41,
                sessionPID: 1545,
                sessionBundleID: "com.apple.Safari",
                snapshots: editorTabs + [samePortal],
                enabled: all,
                sessionTitle: safariCall.title,
                sessionSource: .bitrixSync
            ) == 77,
            "retarget only to the same bitrix call identity"
        )
        expect(
            StenoSessionEnd.isSameCallIdentity(
                sessionTitle: "Ортобум — (23) Чат и звонки",
                otherTitle: "Ортобум — (24) Чат и звонки",
                source: .bitrixSync
            ),
            "unread badge change is the same bitrix tab"
        )
        expect(
            !StenoSessionEnd.isSameCallIdentity(
                sessionTitle: "Ортобум — (23) Чат и звонки",
                otherTitle: "Гекса — (16) Чат и звонки",
                source: .bitrixSync
            ),
            "another portal chat tab is not this call"
        )

        exit(failures == 0 ? 0 : 1)
    }
}
