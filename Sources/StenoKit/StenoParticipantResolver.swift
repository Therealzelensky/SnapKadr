import Foundation

public struct StenoNameHit: Equatable, Sendable {
    public var displayName: String
    public var source: StenoParticipantSource

    public init(displayName: String, source: StenoParticipantSource) {
        self.displayName = displayName
        self.source = source
    }
}

public enum StenoParticipantResolver {
    public static func mergeNames(ax: [StenoNameHit], ocr: [StenoNameHit]) -> [StenoParticipant] {
        var participants: [StenoParticipant] = []
        var normalizedToIndex: [String: Int] = [:]

        func normalized(_ name: String) -> String {
            name.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        }

        func appendParticipant(displayName: String, source: StenoParticipantSource) {
            let key = normalized(displayName)
            guard !key.isEmpty else { return }
            if let existingIndex = normalizedToIndex[key] {
                if source == .ocr && participants[existingIndex].source == .ax {
                    participants[existingIndex].source = .merged
                }
                return
            }
            let participant = StenoParticipant(
                id: UUID().uuidString,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                source: source
            )
            normalizedToIndex[key] = participants.count
            participants.append(participant)
        }

        for hit in ax {
            appendParticipant(displayName: hit.displayName, source: .ax)
        }
        for hit in ocr {
            let key = normalized(hit.displayName)
            guard !key.isEmpty else { continue }
            if normalizedToIndex[key] != nil {
                if let index = normalizedToIndex[key], participants[index].source == .ax {
                    participants[index].source = .merged
                }
            } else {
                appendParticipant(displayName: hit.displayName, source: .ocr)
            }
        }

        return participants
    }

    public static func mapVoices(
        speakers: [String],
        names: [StenoParticipant]
    ) -> [StenoParticipant] {
        var result = names
        for (index, speakerId) in speakers.enumerated() where index < result.count {
            result[index].speakerId = speakerId
        }
        return result
    }

    public static func voiceLabel(speakerId: String) -> String {
        if let number = Int(speakerId) {
            return "Голос \(number)"
        }
        return "Голос \(speakerId)"
    }
}
