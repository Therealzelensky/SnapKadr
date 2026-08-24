import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoDiarizerTests {
    static func main() {
        let tight = [
            StenoCueDraft(startMs: 0, endMs: 500, text: "a", speakerId: nil),
            StenoCueDraft(startMs: 600, endMs: 1000, text: "b", speakerId: nil),
        ]
        let one = StenoDiarizer.assignSpeakers(tight)
        expect(one.allSatisfy { $0.speakerId == "1" }, "tight gaps → one speaker")

        let gapped = [
            StenoCueDraft(startMs: 0, endMs: 500, text: "a", speakerId: nil),
            StenoCueDraft(startMs: 3000, endMs: 3500, text: "b", speakerId: nil),
            StenoCueDraft(startMs: 3600, endMs: 4000, text: "c", speakerId: nil),
            StenoCueDraft(startMs: 6000, endMs: 6500, text: "d", speakerId: nil),
        ]
        let many = StenoDiarizer.assignSpeakers(gapped)
        expect(many.map(\.speakerId) == ["1", "2", "2", "3"], "gap increments speaker id")

        exit(failures == 0 ? 0 : 1)
    }
}
