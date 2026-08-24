import ApplicationServices
import CoreGraphics
import Foundation
import Vision

public struct StenoNameHit: Equatable, Sendable {
    public var displayName: String
    public var source: StenoParticipantSource

    public init(displayName: String, source: StenoParticipantSource) {
        self.displayName = displayName
        self.source = source
    }
}

public protocol StenoAXNameReading: Sendable {
    func readNames(windowID: UInt32, pid: pid_t) -> [StenoNameHit]
}

public protocol StenoOCRNameReading: Sendable {
    func readNames(windowID: UInt32) -> [StenoNameHit]
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

    /// When `namesEnabled == false` → empty, do not call readers.
    /// When true → always call OCR after AX (even if AX non-empty), then mergeNames.
    /// When `windowID == nil` → empty without calling readers.
    public static func resolveNames(
        namesEnabled: Bool,
        windowID: UInt32?,
        pid: pid_t,
        ax: StenoAXNameReading,
        ocr: StenoOCRNameReading
    ) -> [StenoParticipant] {
        guard namesEnabled, let windowID else { return [] }
        let axHits = ax.readNames(windowID: windowID, pid: pid)
        let ocrHits = ocr.readNames(windowID: windowID)
        return mergeNames(ax: axHits, ocr: ocrHits)
    }

    static func nameHits(from labels: [String], source: StenoParticipantSource) -> [StenoNameHit] {
        var seen: Set<String> = []
        var hits: [StenoNameHit] = []
        for label in labels {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard looksLikeName(trimmed) else { continue }
            let key = trimmed.localizedLowercase
            guard seen.insert(key).inserted else { continue }
            hits.append(StenoNameHit(displayName: trimmed, source: source))
        }
        return hits
    }

    static func looksLikeName(_ text: String) -> Bool {
        guard (2...40).contains(text.count) else { return false }
        let lower = text.localizedLowercase
        let blocked = [
            "участники", "participants", "демонстрация", "screen share",
            "mute", "unmute", "leave", "chat", "чат", "stop", "стоп",
            "выйти", "share", "unmute"
        ]
        if blocked.contains(where: { lower.contains($0) }) { return false }
        return text.rangeOfCharacter(from: .letters) != nil
    }
}

public struct StenoLiveAXNameReader: StenoAXNameReading {
    public init() {}

    public func readNames(windowID: UInt32, pid: pid_t) -> [StenoNameHit] {
        let app = AXUIElementCreateApplication(pid)
        var labels: [String] = []
        Self.collect(from: app, depth: 0, maxDepth: 8, into: &labels)
        return StenoParticipantResolver.nameHits(from: labels, source: .ax)
    }

    private static func collect(from el: AXUIElement, depth: Int, maxDepth: Int, into labels: inout [String]) {
        if depth > maxDepth { return }
        if let title = stringAttr(el, kAXTitleAttribute as String), !title.isEmpty {
            labels.append(title)
        }
        if let desc = stringAttr(el, kAXDescriptionAttribute as String), !desc.isEmpty {
            labels.append(desc)
        }
        if let value = stringAttr(el, kAXValueAttribute as String), !value.isEmpty, value.count < 80 {
            labels.append(value)
        }
        guard let kids = copyAttr(el, kAXChildrenAttribute as String) as? [AXUIElement] else { return }
        for kid in kids.prefix(50) {
            collect(from: kid, depth: depth + 1, maxDepth: maxDepth, into: &labels)
        }
    }

    private static func stringAttr(_ el: AXUIElement, _ name: String) -> String? {
        guard let v = copyAttr(el, name) else { return nil }
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return nil
    }

    private static func copyAttr(_ el: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(el, name as CFString, &value)
        return err == .success ? value : nil
    }
}

public struct StenoLiveOCRNameReader: StenoOCRNameReading {
    public init() {}

    public func readNames(windowID: UInt32) -> [StenoNameHit] {
        guard let image = StenoWindowCapture.image(windowID: windowID) else {
            return []
        }

        var strings: [String] = []
        let request = VNRecognizeTextRequest { request, _ in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                strings.append(candidate.string)
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        return StenoParticipantResolver.nameHits(from: strings, source: .ocr)
    }
}

private enum StenoWindowCapture {
    private typealias CreateImageFn = @convention(c) (
        CGRect,
        UInt32,
        UInt32,
        UInt32
    ) -> Unmanaged<CGImage>?

    private static let createImage: CreateImageFn? = {
        guard let symbol = dlsym(dlopen(nil, RTLD_LAZY), "CGWindowListCreateImage") else { return nil }
        return unsafeBitCast(symbol, to: CreateImageFn.self)
    }()

    static func image(windowID: UInt32) -> CGImage? {
        guard let createImage else { return nil }
        guard let unmanaged = createImage(
            .null,
            1 << 0, // kCGWindowListOptionIncludingWindow
            windowID,
            (1 << 0) | (1 << 8) // boundsIgnoreFraming | bestResolution
        ) else { return nil }
        return unmanaged.takeRetainedValue()
    }
}
