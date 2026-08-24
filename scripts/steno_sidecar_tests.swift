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

        let p = StenoParticipant(
            id: "p1", displayName: "Аня", source: .merged, speakerId: "1"
        )
        var sidecar = StenoSidecar(source: "zoom", windowTitle: "Standup", createdAt: created)
        sidecar.participants = [p]
        do {
            let data = try StenoSidecarIO.encode(sidecar)
            let round = try StenoSidecarIO.decode(data)
            expect(round.participants.count == 1, "participants round-trip count")
            expect(round.participants[0].displayName == "Аня", "participant name")
            expect(round.participants[0].source == .merged, "participant source")
            expect(round.participants[0].speakerId == "1", "participant speakerId")

            let legacy = #"{"source":"zoom","windowTitle":"X","createdAt":"2023-11-14T22:13:20Z"}"#.data(using: .utf8)!
            let legacySidecar = try StenoSidecarIO.decode(legacy)
            expect(legacySidecar.participants.isEmpty, "legacy steno.json → empty participants")

            let digest = StenoDigest(theses: [
                StenoDigestThesis(text: "Итог", startMs: 1200, endMs: 5000, trackHint: "call")
            ])
            let dData = try StenoDigestIO.encode(digest)
            let dRound = try StenoDigestIO.decode(dData)
            expect(dRound.theses.count == 1 && dRound.theses[0].startMs == 1200, "digest round-trip")
            expect(
                StenoDigestIO.jsonURL(inProject: project).path.hasSuffix("Demo.kadr/steno-digest.json"),
                "digest path"
            )
        } catch {
            failures += 1
            print("FAIL  participants/digest \(error)")
        }

        exit(failures == 0 ? 0 : 1)
    }
}
