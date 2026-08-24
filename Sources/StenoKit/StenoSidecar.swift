import Foundation

public enum StenoParticipantSource: String, Codable, Sendable {
    case ax, ocr, merged, manual
}

public struct StenoParticipant: Codable, Equatable, Sendable {
    public var id: String
    public var displayName: String
    public var source: StenoParticipantSource
    public var speakerId: String?

    public init(id: String, displayName: String, source: StenoParticipantSource, speakerId: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.source = source
        self.speakerId = speakerId
    }
}

public struct StenoDigestThesis: Codable, Equatable, Sendable {
    public var text: String
    public var startMs: Double
    public var endMs: Double?
    public var trackHint: String?

    public init(text: String, startMs: Double, endMs: Double? = nil, trackHint: String? = nil) {
        self.text = text
        self.startMs = startMs
        self.endMs = endMs
        self.trackHint = trackHint
    }
}

public struct StenoDigest: Codable, Equatable, Sendable {
    public var theses: [StenoDigestThesis]

    public init(theses: [StenoDigestThesis]) {
        self.theses = theses
    }
}

public struct StenoSidecar: Codable, Equatable, Sendable {
    public var source: String
    public var windowTitle: String
    public var createdAt: Date
    public var participants: [StenoParticipant]

    enum CodingKeys: String, CodingKey {
        case source, windowTitle, createdAt, participants
    }

    public init(
        source: String,
        windowTitle: String,
        createdAt: Date,
        participants: [StenoParticipant] = []
    ) {
        self.source = source
        self.windowTitle = windowTitle
        self.createdAt = createdAt
        self.participants = participants
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(String.self, forKey: .source)
        windowTitle = try container.decode(String.self, forKey: .windowTitle)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        participants = try container.decodeIfPresent([StenoParticipant].self, forKey: .participants) ?? []
    }
}

public enum StenoSidecarIO {
    public static func jsonURL(inProject url: URL) -> URL {
        url.appendingPathComponent("steno.json")
    }

    public static func encode(_ sidecar: StenoSidecar) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(sidecar)
    }

    public static func decode(_ data: Data) throws -> StenoSidecar {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StenoSidecar.self, from: data)
    }

    public static func write(_ sidecar: StenoSidecar, inProject url: URL) throws {
        try encode(sidecar).write(to: jsonURL(inProject: url), options: .atomic)
    }
}

public enum StenoDigestIO {
    public static func jsonURL(inProject url: URL) -> URL {
        url.appendingPathComponent("steno-digest.json")
    }

    public static func encode(_ digest: StenoDigest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(digest)
    }

    public static func decode(_ data: Data) throws -> StenoDigest {
        try JSONDecoder().decode(StenoDigest.self, from: data)
    }

    public static func write(_ digest: StenoDigest, inProject url: URL) throws {
        try encode(digest).write(to: jsonURL(inProject: url), options: .atomic)
    }

    public static func read(inProject url: URL) throws -> StenoDigest? {
        let fileURL = jsonURL(inProject: url)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try decode(Data(contentsOf: fileURL))
    }
}
