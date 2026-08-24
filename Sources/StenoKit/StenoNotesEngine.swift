import Foundation

public protocol StenoLanguageModelClient: Sendable {
    var isAvailable: Bool { get }
    func summarize(transcript: String) async throws -> StenoDigest
}

public enum StenoNotesEngine {
    public static func makeDigest(
        transcript: String,
        client: StenoLanguageModelClient
    ) async -> StenoDigest? {
        if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard client.isAvailable else { return nil }
            return StenoDigest(theses: [])
        }
        guard client.isAvailable else { return nil }
        do {
            return try await client.summarize(transcript: transcript)
        } catch {
            return nil
        }
    }
}

public struct StenoFoundationModelsClient: StenoLanguageModelClient {
    public init() {}

    public var isAvailable: Bool {
        if #available(macOS 26.0, *) {
            return true
        }
        return false
    }

    public func summarize(transcript: String) async throws -> StenoDigest {
        if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return StenoDigest(theses: [])
        }
        // W3: real FM integration when SystemLanguageModel API is wired; unavailable path returns via isAvailable.
        throw StenoNotesError.unavailable
    }
}

private enum StenoNotesError: Error {
    case unavailable
}
