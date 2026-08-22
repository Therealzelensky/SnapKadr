import Foundation

public struct StenoSidecar: Codable, Equatable, Sendable {
    public var source: String
    public var windowTitle: String
    public var createdAt: Date

    public init(source: String, windowTitle: String, createdAt: Date) {
        self.source = source
        self.windowTitle = windowTitle
        self.createdAt = createdAt
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
