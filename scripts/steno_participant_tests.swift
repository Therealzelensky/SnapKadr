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

        exit(failures == 0 ? 0 : 1)
    }
}
