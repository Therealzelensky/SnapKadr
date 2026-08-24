import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

struct FakeLM: StenoLanguageModelClient {
    var isAvailable: Bool
    var result: Result<StenoDigest, Error>
    func summarize(transcript: String) async throws -> StenoDigest {
        try result.get()
    }
}

@main
enum StenoNotesTests {
    static func main() async {
        let skip = await StenoNotesEngine.makeDigest(
            transcript: "hello",
            client: FakeLM(isAvailable: false, result: .success(StenoDigest(theses: [
                StenoDigestThesis(text: "NO", startMs: 0, endMs: nil, trackHint: nil)
            ])))
        )
        expect(skip == nil, "unavailable → nil, no fake theses")

        enum E: Error { case fail }
        let err = await StenoNotesEngine.makeDigest(
            transcript: "hello",
            client: FakeLM(isAvailable: true, result: .failure(E.fail))
        )
        expect(err == nil, "error → nil")

        let okDigest = StenoDigest(theses: [
            StenoDigestThesis(text: "Итог", startMs: 10, endMs: nil, trackHint: "call")
        ])
        let ok = await StenoNotesEngine.makeDigest(
            transcript: "hello",
            client: FakeLM(isAvailable: true, result: .success(okDigest))
        )
        expect(ok?.theses.first?.text == "Итог", "success passes through")

        let empty = await StenoNotesEngine.makeDigest(
            transcript: "   ",
            client: FakeLM(isAvailable: true, result: .success(StenoDigest(theses: [
                StenoDigestThesis(text: "NO", startMs: 0, endMs: nil, trackHint: nil)
            ])))
        )
        expect(empty?.theses.isEmpty == true, "empty transcript → empty theses")

        exit(failures == 0 ? 0 : 1)
    }
}
