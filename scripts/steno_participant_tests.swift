import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoParticipantTests {
    static func main() {
        let ax = [
            StenoNameHit(displayName: "Аня", source: .ax),
            StenoNameHit(displayName: "Боря", source: .ax)
        ]
        let ocr = [
            StenoNameHit(displayName: "аня", source: .ocr),
            StenoNameHit(displayName: "Вика", source: .ocr)
        ]
        let merged = StenoParticipantResolver.mergeNames(ax: ax, ocr: ocr)
        expect(merged.count == 3, "dedupe Аня")
        expect(merged[0].source == .merged && merged[0].displayName == "Аня", "AX+OCR → merged keeps AX display")
        expect(merged[1].displayName == "Боря" && merged[1].source == .ax, "AX only")
        expect(merged[2].displayName == "Вика" && merged[2].source == .ocr, "OCR only")

        let mapped = StenoParticipantResolver.mapVoices(speakers: ["1", "2"], names: merged)
        expect(mapped[0].speakerId == "1" && mapped[1].speakerId == "2", "zip speakers")
        expect(mapped[2].speakerId == nil, "extra name unbound")
        expect(StenoParticipantResolver.voiceLabel(speakerId: "1") == "Голос 1", "label")

        struct FakeAX: StenoAXNameReading {
            var hits: [StenoNameHit]
            func readNames(windowID: UInt32, pid: pid_t) -> [StenoNameHit] { hits }
        }
        final class FakeOCR: StenoOCRNameReading {
            var hits: [StenoNameHit]
            private(set) var callCount = 0
            init(hits: [StenoNameHit]) { self.hits = hits }
            func readNames(windowID: UInt32) -> [StenoNameHit] {
                callCount += 1
                return hits
            }
        }

        expect(
            StenoParticipantResolver.resolveNames(
                namesEnabled: false, windowID: 1, pid: 1,
                ax: FakeAX(hits: [StenoNameHit(displayName: "X", source: .ax)]),
                ocr: FakeOCR(hits: [StenoNameHit(displayName: "Y", source: .ocr)])
            ).isEmpty,
            "names pref off → skip"
        )

        let ocrFake = FakeOCR(hits: [StenoNameHit(displayName: "Y", source: .ocr)])
        let axHits = [StenoNameHit(displayName: "X", source: .ax)]
        let result = StenoParticipantResolver.resolveNames(
            namesEnabled: true, windowID: 42, pid: 7,
            ax: FakeAX(hits: axHits), ocr: ocrFake
        )
        expect(ocrFake.callCount == 1, "OCR always when names on")
        expect(result.map(\.displayName).sorted() == ["X", "Y"].sorted(), "merged")

        let noWindowOCR = FakeOCR(hits: [])
        let noWindow = StenoParticipantResolver.resolveNames(
            namesEnabled: true, windowID: nil, pid: 0,
            ax: FakeAX(hits: axHits), ocr: noWindowOCR
        )
        expect(noWindow.isEmpty, "missing window → empty (readers not useful)")
        expect(noWindowOCR.callCount == 0, "missing window → no OCR call")

        exit(failures == 0 ? 0 : 1)
    }
}
