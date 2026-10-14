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
        return connectedNeedles.contains { hay.contains($0) }
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
                tracks: &tracks
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
        tracks: inout Set<String>
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
        for kid in kids.prefix(120) {
            collect(
                from: kid,
                depth: depth + 1,
                maxDepth: maxDepth,
                labels: &labels,
                participantCount: &participantCount,
                tracks: &tracks
            )
        }
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
