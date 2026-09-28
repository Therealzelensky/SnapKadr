import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoTranscriptCleanupTests {
    static func main() {
        expect(
            StenoTranscriptCleanup.sanitize("да привет привет Thank you. you") == "да привет привет",
            "strip thank-you hallucination"
        )
        expect(
            StenoTranscriptCleanup.sanitize("Это ваше производство уже. Thanks for watching!")
                == "Это ваше производство уже.",
            "strip thanks-for-watching"
        )
        expect(
            StenoTranscriptCleanup.sanitize("каждый день, плюс один. [ Silence ] С апреля-то?")
                == "каждый день, плюс один. С апреля-то?",
            "strip silence tag mid-cue"
        )
        expect(
            StenoTranscriptCleanup.sanitize("в неё, не касалась. Да! [BLANK_AUDIO]")
                == "в неё, не касалась. Да!",
            "strip blank audio tag"
        )
        expect(
            StenoTranscriptCleanup.sanitize("[NOISE]").isEmpty,
            "noise-only cue becomes empty"
        )
        expect(
            StenoTranscriptCleanup.sanitize("[музыка]").isEmpty,
            "music tag only becomes empty"
        )
        expect(
            StenoTranscriptCleanup.sanitize("[Продолжение субтитров]").isEmpty,
            "subtitle continuation tag dropped"
        )
        expect(
            StenoTranscriptCleanup.sanitize("[INAUDIBLE]").isEmpty,
            "inaudible tag dropped"
        )
        expect(
            StenoTranscriptCleanup.sanitize("[PYTANIE] Jeszcze raz. [PYTANIE]") == "Jeszcze raz.",
            "strip bracket tags keep speech"
        )
        expect(
            StenoTranscriptCleanup.sanitize("Если нужно чтобы они были в админке, то надо завести их в админку.")
                == "Если нужно чтобы они были в админке, то надо завести их в админку.",
            "clean russian cue untouched"
        )

        let cleaned = StenoTranscriptCleanup.clean([
            StenoCueDraft(startMs: 0, endMs: 1000, text: "[BLANK_AUDIO]", speakerId: nil),
            StenoCueDraft(startMs: 1000, endMs: 2000, text: "Да. Thanks for watching!", speakerId: "1"),
            StenoCueDraft(startMs: 2000, endMs: 3000, text: "Ок", speakerId: "2"),
        ])
        expect(cleaned.count == 2, "drop empty tech cues")
        expect(cleaned[0].text == "Да." && cleaned[0].speakerId == "1", "cleaned first kept cue")
        expect(cleaned[1].text == "Ок", "second cue unchanged")

        exit(failures == 0 ? 0 : 1)
    }
}
