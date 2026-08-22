import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoSidecarTests {
    static func main() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let original = StenoSidecar(source: "zoom", windowTitle: "Standup", createdAt: created)
        do {
            let data = try StenoSidecarIO.encode(original)
            let round = try StenoSidecarIO.decode(data)
            expect(round.source == "zoom", "source")
            expect(round.windowTitle == "Standup", "title")
            expect(abs(round.createdAt.timeIntervalSince1970 - created.timeIntervalSince1970) < 1, "date")
        } catch {
            failures += 1
            print("FAIL  round-trip \(error)")
        }

        let project = URL(fileURLWithPath: "/tmp/Demo.kadr")
        expect(
            StenoSidecarIO.jsonURL(inProject: project).path.hasSuffix("Demo.kadr/steno.json"),
            "sidecar path"
        )

        exit(failures == 0 ? 0 : 1)
    }
}
