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

        exit(failures == 0 ? 0 : 1)
    }
}
