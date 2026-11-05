import ApplicationServices
import Foundation

/// Панель комнаты («Демонстрация», «Участники», «Выйти из встречи») есть и у одного человека.
/// Звонок начался, когда в комнате есть кто-то ещё, или на экране кнопки уже идущего разговора 1:1.
public enum StenoLiveCall {
    public static let connectedNeedles = [
        "завершить звонок",
        "end call",
        "открыть экран звонка",
    ]

    public static func isConnected(
        labels: [String],
        participantCount: Int?,
        videoTrackCount: Int,
        lobbyNeedles: [String] = []
    ) -> Bool {
        let hay = labels.joined(separator: " ")
            .lowercased()
            .replacingOccurrences(of: "\u{00a0}", with: " ")
        if lobbyNeedles.contains(where: { hay.contains($0) }) { return false }
        if let participantCount, participantCount >= 2 { return true }
        if videoTrackCount >= 2 { return true }
        if connectedNeedles.contains(where: { hay.contains($0) }) { return true }
        return labels.contains { bannerCall($0) }
    }

    /// Живой созвон. Голое «12 участников» — размер группового чата, не звонок.
    private static func bannerCall(_ raw: String) -> Bool {
        let label = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\u{00a0}", with: " ")
        guard !label.isEmpty, label.count <= 80 else { return false }
        if label == "звонок в яндекс телемосте" || label == "звонок в телемосте" { return true }
        if label == "на встрече" || label == "вернуться к звонку" { return true }
        if label == "идёт групповой звонок" || label == "идет групповой звонок" { return true }
        guard label.count <= 40 else { return false }
        return label.range(
            of: #"\d{1,2}:\d{2}\s*[·•]\s*\d{1,3}\s*участник"#,
            options: .regularExpression
        ) != nil
    }

    /// Любое окно процесса. Текст лобби в одном окне не отменяет живой звонок в другом.
    public static func isInCall(pid: pid_t, lobbyNeedles: [String] = []) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        guard let windows = copyAttr(app, kAXWindowsAttribute as String) as? [AXUIElement], !windows.isEmpty else {
            return false
        }
        for window in windows {
            var labels: [String] = []
            var participantCount: Int?
            var tracks = Set<String>()
            collect(
                from: window,
                depth: 0,
                maxDepth: 20,
                labels: &labels,
                participantCount: &participantCount,
                tracks: &tracks,
                ancestors: []
            )
            if isConnected(
                labels: labels,
                participantCount: participantCount,
                videoTrackCount: tracks.count,
                lobbyNeedles: lobbyNeedles
            ) {
                return true
            }
        }
        return false
    }

    private static func collect(
        from el: AXUIElement,
        depth: Int,
        maxDepth: Int,
        labels: inout [String],
        participantCount: inout Int?,
        tracks: inout Set<String>,
        ancestors: [String]
    ) {
        if depth > maxDepth { return }
        if let role = stringAttr(el, kAXRoleAttribute as String),
           role == (kAXMenuBarRole as String) || role == (kAXMenuBarItemRole as String) || role == (kAXMenuRole as String) {
            return
        }
        let ident = stringAttr(el, kAXIdentifierAttribute as String) ?? ""
        if let key = videoTrackKey(ident) {
            tracks.insert(key)
        }
        if ident.contains("participantsButton.BadgeLabel") {
            let title = stringAttr(el, kAXTitleAttribute as String) ?? ""
            let value = stringAttr(el, kAXValueAttribute as String) ?? ""
            if let n = intToken(title) ?? intToken(value) {
                participantCount = max(participantCount ?? n, n)
            }
        }
        let title = stringAttr(el, kAXTitleAttribute as String) ?? ""
        let desc = stringAttr(el, kAXDescriptionAttribute as String) ?? ""
        let value = stringAttr(el, kAXValueAttribute as String) ?? ""
        if !title.isEmpty { appendCallLabel(title, ancestors: ancestors, labels: &labels) }
        if !desc.isEmpty { appendCallLabel(desc, ancestors: ancestors, labels: &labels) }
        if !value.isEmpty, value.count < 80 { appendCallLabel(value, ancestors: ancestors, labels: &labels) }
        let childAncestors = ancestors + [title, desc, value].filter { !$0.isEmpty }
        guard let kids = copyAttr(el, kAXChildrenAttribute as String) as? [AXUIElement] else { return }
        for kid in kids.prefix(120) {
            collect(
                from: kid,
                depth: depth + 1,
                maxDepth: maxDepth,
                labels: &labels,
                participantCount: &participantCount,
                tracks: &tracks,
                ancestors: childAncestors
            )
        }
    }

    /// «На встрече» в шапке чата — статус («На встрече• был 2 минуты назад»), не баннер созвона.
    private static func appendCallLabel(_ raw: String, ancestors: [String], labels: inout [String]) {
        let label = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\u{00a0}", with: " ")
        if label == "на встрече", ancestors.contains(where: isPresenceStatus) {
            return
        }
        labels.append(raw)
    }

    private static func isPresenceStatus(_ raw: String) -> Bool {
        let label = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\u{00a0}", with: " ")
        return label.range(of: #"на встрече\s*[•·∙]"#, options: .regularExpression) != nil
    }

    /// Один локальный превью и его дочерние виджеты — это один трек.
    private static func videoTrackKey(_ ident: String) -> String? {
        guard let range = ident.range(of: "VideoTrackWidget") else { return nil }
        return String(ident[..<range.upperBound])
    }

    private static func intToken(_ raw: String) -> Int? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return Int(t)
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
