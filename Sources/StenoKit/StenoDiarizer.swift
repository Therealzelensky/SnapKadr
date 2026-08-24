import Foundation

public struct StenoCueDraft: Equatable, Sendable {
    public var startMs: Double
    public var endMs: Double
    public var text: String
    public var speakerId: String?

    public init(startMs: Double, endMs: Double, text: String, speakerId: String? = nil) {
        self.startMs = startMs
        self.endMs = endMs
        self.text = text
        self.speakerId = speakerId
    }
}

public enum StenoDiarizer {
    public static func assignSpeakers(
        _ cues: [StenoCueDraft],
        gapMs: Double = 1400,
        maxSpeakers: Int = 8
    ) -> [StenoCueDraft] {
        guard !cues.isEmpty else { return [] }
        var result = cues
        var currentSpeaker = 1
        result[0].speakerId = String(currentSpeaker)

        for index in 1..<result.count {
            let gap = result[index].startMs - result[index - 1].endMs
            if gap >= gapMs {
                currentSpeaker = min(currentSpeaker + 1, maxSpeakers)
            }
            result[index].speakerId = String(currentSpeaker)
        }
        return result
    }

    public static func uniqueSpeakerIds(in cues: [StenoCueDraft]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for cue in cues {
            guard let speakerId = cue.speakerId else { continue }
            if seen.insert(speakerId).inserted {
                ordered.append(speakerId)
            }
        }
        return ordered
    }
}
