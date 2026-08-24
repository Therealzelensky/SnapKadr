import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

struct FakeAX: StenoAXNameReading {
    func readNames(windowID: UInt32, pid: pid_t) -> [StenoNameHit] { [] }
}

final class CountingOCR: StenoOCRNameReading {
    func readNames(windowID: UInt32) -> [StenoNameHit] { [] }
}

struct FakeLM: StenoLanguageModelClient {
    var isAvailable: Bool
    func summarize(transcript: String) async throws -> StenoDigest {
        StenoDigest(theses: [StenoDigestThesis(text: "ok", startMs: 0, endMs: nil, trackHint: nil)])
    }
}

@main
enum StenoPipelineTests {
    static func main() async {
        let projectURL = URL(fileURLWithPath: "/tmp/Test.kadr")
        var digestWritten = false

        let deps = StenoPipelineDeps(
            ax: FakeAX(),
            ocr: CountingOCR(),
            speech: { _ in
                [StenoCueDraft(startMs: 0, endMs: 500, text: "hello")]
            },
            notes: FakeLM(isAvailable: true),
            writeSidecar: { _ in },
            writeDigest: { _ in digestWritten = true },
            writeTranscript: { _ in },
            loadSidecar: {
                StenoSidecar(source: "zoom", windowTitle: "x", createdAt: Date())
            }
        )

        var log: [String] = []
        let pipe = StenoPostSessionPipeline()
        pipe.onStage = { log.append($0.rawValue) }
        _ = await pipe.run(
            input: StenoPipelineInput(
                projectURL: projectURL,
                windowID: 1,
                pid: 1,
                namesEnabled: true,
                separateSpeakers: true
            ),
            deps: deps
        )
        expect(log == ["ax", "ocr", "speech", "diarization", "map", "digest", "done"], "strict order")
        expect(digestWritten, "digest written on success")

        var logOff = [String]()
        digestWritten = false
        let pipeOff = StenoPostSessionPipeline()
        pipeOff.onStage = { logOff.append($0.rawValue) }
        _ = await pipeOff.run(
            input: StenoPipelineInput(
                projectURL: projectURL,
                windowID: 1,
                pid: 1,
                namesEnabled: true,
                separateSpeakers: false
            ),
            deps: deps
        )
        expect(logOff == ["ax", "ocr", "speech", "digest", "done"], "no diarization/map when speakers off")

        enum SpeechErr: Error { case boom }
        var logSpeechFail = [String]()
        digestWritten = false
        let depsFail = StenoPipelineDeps(
            ax: FakeAX(),
            ocr: CountingOCR(),
            speech: { _ in throw SpeechErr.boom },
            notes: FakeLM(isAvailable: true),
            writeSidecar: { _ in },
            writeDigest: { _ in digestWritten = true },
            writeTranscript: { _ in },
            loadSidecar: {
                StenoSidecar(source: "zoom", windowTitle: "x", createdAt: Date())
            }
        )
        let pipeFail = StenoPostSessionPipeline()
        pipeFail.onStage = { logSpeechFail.append($0.rawValue) }
        _ = await pipeFail.run(
            input: StenoPipelineInput(
                projectURL: projectURL,
                windowID: 1,
                pid: 1,
                namesEnabled: true,
                separateSpeakers: true
            ),
            deps: depsFail
        )
        expect(logSpeechFail == ["ax", "ocr", "speech"], "speech failure stops pipeline")
        expect(!digestWritten, "no digest on speech failure")

        exit(failures == 0 ? 0 : 1)
    }
}
