import Foundation

/// Strips Whisper hallucination tags and English filler that leak into Russian calls.
public enum StenoTranscriptCleanup {
    public static func clean(_ cues: [StenoCueDraft]) -> [StenoCueDraft] {
        cues.compactMap { cue in
            let text = sanitize(cue.text)
            guard !text.isEmpty else { return nil }
            var next = cue
            next.text = text
            return next
        }
    }

    public static func sanitize(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        if let tokenRegex = try? NSRegularExpression(pattern: #"<\|[^|>]+\|>"#) {
            text = tokenRegex.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: ""
            )
        }
        if let bracketRegex = try? NSRegularExpression(
            pattern: #"\[(?:\s*(?:BLANK_AUDIO|Silence|NOISE|INAUDIBLE|MUSIC|музыка|Продолжение субтитров|PYTANIE|Silence)\s*)\]"#,
            options: [.caseInsensitive]
        ) {
            text = bracketRegex.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: ""
            )
        }
        if let parenRegex = try? NSRegularExpression(
            pattern: #"\((?:\s*(?:BLANK_AUDIO|Silence|NOISE|INAUDIBLE|MUSIC|музыка)\s*)\)"#,
            options: [.caseInsensitive]
        ) {
            text = parenRegex.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: ""
            )
        }

        for phrase in hallucinationPhrases {
            text = text.replacingOccurrences(of: phrase, with: "", options: [.caseInsensitive, .diacriticInsensitive])
        }

        text = text.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix(".") && text.dropLast().trimmingCharacters(in: .whitespaces).hasSuffix(".") {
            text = String(text.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        // Lone trailing "you" after Russian speech.
        if let youRegex = try? NSRegularExpression(pattern: #"(?i)(?:^|\s)you\.?\s*$"#) {
            text = youRegex.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: ""
            )
        }
        text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ",;")))
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let lower = text.lowercased()
        let dropExact = [
            "[music]", "(music)", "[blank_audio]", "[silence]", "[noise]",
            "[inaudible]", "[музыка]", "[продолжение субтитров]",
            "thanks for watching!", "thank you.", "thank you",
        ]
        if dropExact.contains(where: { lower == $0 }) { return "" }

        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        if letters < 2 { return "" }
        return text
    }

    private static let hallucinationPhrases = [
        "Thanks for watching!",
        "Thanks for watching",
        "Thank you for watching!",
        "Thank you for watching",
        "Thank you. you",
        "Thank you.",
        "Thank you",
        "Subtitles by the Amara.org community",
        "Продолжение следует...",
        "Продолжение следует",
    ]
}
