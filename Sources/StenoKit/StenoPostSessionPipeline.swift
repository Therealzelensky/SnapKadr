import Foundation

public enum StenoPipelineStage: String, Sendable {
    case ax, ocr, speech, diarization, map, digest, done
}

public struct StenoPipelineInput: Sendable {
    public var projectURL: URL
    public var windowID: UInt32?
    public var pid: pid_t
    public var namesEnabled: Bool
    public var separateSpeakers: Bool

    public init(
        projectURL: URL,
        windowID: UInt32?,
        pid: pid_t,
        namesEnabled: Bool,
        separateSpeakers: Bool
    ) {
        self.projectURL = projectURL
        self.windowID = windowID
        self.pid = pid
        self.namesEnabled = namesEnabled
        self.separateSpeakers = separateSpeakers
    }
}

public struct StenoPipelineDeps: Sendable {
    public var ax: StenoAXNameReading
    public var ocr: StenoOCRNameReading
    public var speech: @Sendable (URL) async throws -> [StenoCueDraft]
    public var notes: StenoLanguageModelClient
    public var writeSidecar: @Sendable (StenoSidecar) throws -> Void
    public var writeDigest: @Sendable (StenoDigest) throws -> Void
    public var writeTranscript: @Sendable ([StenoCueDraft]) async throws -> Void
    public var loadSidecar: @Sendable () throws -> StenoSidecar

    public init(
        ax: StenoAXNameReading,
        ocr: StenoOCRNameReading,
        speech: @escaping @Sendable (URL) async throws -> [StenoCueDraft],
        notes: StenoLanguageModelClient,
        writeSidecar: @escaping @Sendable (StenoSidecar) throws -> Void,
        writeDigest: @escaping @Sendable (StenoDigest) throws -> Void,
        writeTranscript: @escaping @Sendable ([StenoCueDraft]) async throws -> Void,
        loadSidecar: @escaping @Sendable () throws -> StenoSidecar
    ) {
        self.ax = ax
        self.ocr = ocr
        self.speech = speech
        self.notes = notes
        self.writeSidecar = writeSidecar
        self.writeDigest = writeDigest
        self.writeTranscript = writeTranscript
        self.loadSidecar = loadSidecar
    }
}

public final class StenoPostSessionPipeline: @unchecked Sendable {
    public private(set) var stages: [StenoPipelineStage] = []
    public var onStage: ((StenoPipelineStage) -> Void)?

    public init() {}

    public func run(input: StenoPipelineInput, deps: StenoPipelineDeps) async -> StenoPipelineStage {
        stages = []
        var participants: [StenoParticipant] = []
        var cues: [StenoCueDraft] = []

        func emit(_ stage: StenoPipelineStage) {
            stages.append(stage)
            onStage?(stage)
        }

        emit(.ax)
        emit(.ocr)
        if input.namesEnabled {
            participants = StenoParticipantResolver.resolveNames(
                namesEnabled: true,
                windowID: input.windowID,
                pid: input.pid,
                ax: deps.ax,
                ocr: deps.ocr
            )
        }

        emit(.speech)
        do {
            cues = try await deps.speech(input.projectURL)
        } catch is CancellationError {
            return .speech
        } catch {
            return .speech
        }

        if input.separateSpeakers {
            emit(.diarization)
            cues = StenoDiarizer.assignSpeakers(cues)

            emit(.map)
            let speakers = StenoDiarizer.uniqueSpeakerIds(in: cues)
            participants = StenoParticipantResolver.mapVoices(speakers: speakers, names: participants)
        }

        emit(.digest)
        let transcript = cues.map(\.text).joined(separator: " ")
        if let digest = await StenoNotesEngine.makeDigest(transcript: transcript, client: deps.notes) {
            do {
                try deps.writeDigest(digest)
            } catch {
                // keep going — transcript + participants still valuable
            }
        }

        do {
            let cuesToWrite = cues
            let participantsToWrite = participants
            try await deps.writeTranscript(cuesToWrite)
            var sidecar = try deps.loadSidecar()
            sidecar.participants = participantsToWrite
            try deps.writeSidecar(sidecar)
        } catch {
            return .digest
        }

        emit(.done)
        return .done
    }
}
