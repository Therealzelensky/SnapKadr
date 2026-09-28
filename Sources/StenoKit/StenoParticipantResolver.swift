import ApplicationServices
import CoreGraphics
import Darwin
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
    func readNames(windowID: UInt32, pid: pid_t, windowTitle: String) -> [StenoNameHit]
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
        windowTitle: String = "",
        ax: StenoAXNameReading,
        ocr: StenoOCRNameReading
    ) -> [StenoParticipant] {
        guard namesEnabled, let windowID else { return [] }
        let axHits = ax.readNames(windowID: windowID, pid: pid, windowTitle: windowTitle)
        let ocrHits = ocr.readNames(windowID: windowID)
        return mergeNames(ax: axHits, ocr: ocrHits)
    }

    public static func nameHits(from labels: [String], source: StenoParticipantSource) -> [StenoNameHit] {
        var seen: Set<String> = []
        var hits: [StenoNameHit] = []
        for label in labels {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\u{00a0}", with: " ")
            guard looksLikeName(trimmed) else { continue }
            let key = trimmed.localizedLowercase
            guard seen.insert(key).inserted else { continue }
            hits.append(StenoNameHit(displayName: trimmed, source: source))
        }
        return hits
    }

    public static func looksLikeName(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00a0}", with: " ")
        guard (3...48).contains(trimmed.count) else { return false }
        if trimmed.rangeOfCharacter(from: .decimalDigits) != nil { return false }
        let bannedChars = CharacterSet(charactersIn: "—–·•|/\\[](){}<>@#$%^*=+")
        if trimmed.unicodeScalars.contains(where: { bannedChars.contains($0) }) { return false }

        let words = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        // Real call tiles are «Имя Фамилия» (2–4 tokens). Single tokens are almost always chrome.
        guard (2...4).contains(words.count) else { return false }

        let nameToken = #"^[A-ZА-ЯЁ][A-Za-zА-Яа-яЁё\-']+$"#
        for word in words {
            guard word.range(of: nameToken, options: .regularExpression) != nil else { return false }
            // ALL-CAPS nav labels (CRM, etc.)
            if word.count > 3, word.uppercased() == word, word.lowercased() != word { return false }
        }

        let lower = words.map { $0.localizedLowercase }.joined(separator: " ")
        let blockedTokens: Set<String> = [
            "меню", "битрикс", "портал", "лента", "почта", "диск", "группы",
            "сотрудники", "уведомления", "пригласить", "тариф", "помощь", "профиль",
            "поиск", "настройки", "задачи", "проекты", "каналы", "чаты", "чат",
            "мессенджер", "messenger", "yandex", "bitrixgpt", "разделу", "перейти",
            "главное", "совместная", "работа", "обучение", "тестирование",
            "автоматизация", "контакт", "центр", "показать", "новые", "новая",
            "вкладка", "вкладки", "история", "загрузки", "поделиться", "напечатать",
            "перевод", "доступен", "safari", "finder", "яндекс", "телемост",
            "telemost", "zoom", "telegram", "meet", "google", "apple", "localhost",
            "superpowers", "brainstorming", "server", "hub", "traffic", "releases",
            "метрик", "power", "власть", "ночном", "городе", "личный", "обзор",
            "завершён", "завершен", "отвечает", "ответил", "участники", "participants",
            "демонстрация", "микрофон", "камера", "запись", "выйти", "leave",
            "window", "edit", "help", "services", "activity", "monitor",
        ]
        if words.contains(where: { blockedTokens.contains($0.localizedLowercase) }) { return false }
        if blockedTokens.contains(where: { lower.contains($0) && $0.count > 4 }) {
            // only apply multi-char contains for phrases that aren't substrings of names
            let phraseBlocks = [
                "не отвечает", "звонок заверш", "главное меню", "чат и звонки",
                "новых сообщ", "в finder", "bitrix24", "яндекс мессенджер",
                "яндекс телемост", "screen share", "google meet",
            ]
            if phraseBlocks.contains(where: { lower.contains($0) }) { return false }
        }

        return true
    }
}

public struct StenoLiveAXNameReader: StenoAXNameReading {
    public init() {}

    public func readNames(windowID: UInt32, pid: pid_t, windowTitle: String) -> [StenoNameHit] {
        let app = AXUIElementCreateApplication(pid)
        var labels: [String] = []
        // Menubar is full of Edit/Window/Finder chrome — walk call windows only.
        if let windows = copyAttr(app, kAXWindowsAttribute as String) as? [AXUIElement], !windows.isEmpty {
            let want = normalize(windowTitle)
            let matched: [AXUIElement]
            if want.isEmpty {
                matched = windows
            } else {
                let exact = windows.filter { normalize(stringAttr($0, kAXTitleAttribute as String) ?? "") == want }
                if !exact.isEmpty {
                    matched = exact
                } else {
                    // Title may drift (unread badge); keep windows that share a portal/prefix token.
                    let token = want.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).prefix(2).joined(separator: " ")
                    matched = windows.filter {
                        let t = normalize(stringAttr($0, kAXTitleAttribute as String) ?? "")
                        return !token.isEmpty && t.contains(token)
                    }
                }
            }
            for window in (matched.isEmpty ? windows : matched) {
                collect(from: window, depth: 0, maxDepth: 14, into: &labels)
            }
        } else {
            collect(from: app, depth: 0, maxDepth: 8, into: &labels)
        }
        return StenoParticipantResolver.nameHits(from: labels, source: .ax)
    }

    private func normalize(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "\u{00a0}", with: " ")
    }

    private func collect(from el: AXUIElement, depth: Int, maxDepth: Int, into labels: inout [String]) {
        if depth > maxDepth { return }
        if let role = stringAttr(el, kAXRoleAttribute as String),
           role == (kAXMenuBarRole as String)
            || role == (kAXMenuBarItemRole as String)
            || role == (kAXMenuRole as String)
            || role == (kAXMenuItemRole as String) {
            return
        }
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
        for kid in kids.prefix(80) {
            collect(from: kid, depth: depth + 1, maxDepth: maxDepth, into: &labels)
        }
    }

    private func stringAttr(_ el: AXUIElement, _ name: String) -> String? {
        guard let v = copyAttr(el, name) else { return nil }
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return nil
    }

    private func copyAttr(_ el: AXUIElement, _ name: String) -> AnyObject? {
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
