import ApplicationServices
import Foundation

/// Bitrix24 Sync often keeps the tab title «Чат и звонки» during a live call.
/// In-call chrome (return-to-call / follow-up) lives in the page AX tree.
public enum StenoBitrixCallState {
    private static let inCallNeedles = [
        "вернуться в звонок",
        "return to call",
        "завершить звонок",
        "end call",
        "bitrixgpt follow-up",
        "идёт звонок",
        "идет звонок",
    ]

    public static func isInCall(axLabels: [String]) -> Bool {
        let hay = axLabels.joined(separator: " ").lowercased()
            .replacingOccurrences(of: "\u{00a0}", with: " ")
        return inCallNeedles.contains(where: { hay.contains($0) })
    }

    public static func isInCall(pid: pid_t, windowTitle: String) -> Bool {
        isInCall(axLabels: collectLabels(pid: pid, windowTitle: windowTitle))
    }

    /// Pick the AX window that belongs to this Bitrix tab, not the first «Чат и звонки».
    public static func pickWindowIndex(want: String, axTitles: [String]) -> Int? {
        let nwant = normalize(want)
        if nwant.isEmpty { return nil }
        if let exact = axTitles.firstIndex(where: { normalize($0) == nwant }) {
            return exact
        }
        let wantPortal = bitrixPortal(nwant)
        guard !wantPortal.isEmpty else { return nil }
        return axTitles.firstIndex { title in
            let t = normalize(title)
            guard looksLikeBitrixTab(t) else { return false }
            return bitrixPortal(t) == wantPortal
        }
    }

    private static func collectLabels(pid: pid_t, windowTitle: String) -> [String] {
        let app = AXUIElementCreateApplication(pid)
        var labels: [String] = []
        guard let windows = copyAttr(app, kAXWindowsAttribute as String) as? [AXUIElement] else {
            return labels
        }
        let titles = windows.map { stringAttr($0, kAXTitleAttribute as String) ?? "" }
        guard let idx = pickWindowIndex(want: windowTitle, axTitles: titles), windows.indices.contains(idx) else {
            return labels
        }
        collect(from: windows[idx], depth: 0, maxDepth: 20, into: &labels)
        return labels
    }

    private static func looksLikeBitrixTab(_ s: String) -> Bool {
        s.contains("чат и звонки")
            || s.contains("chat and calls")
            || s.contains("видеозвонок")
            || s.contains("video call")
            || s.contains("bitrix24")
            || s.contains("битрикс24")
    }

    private static func bitrixPortal(_ s: String) -> String {
        var t = s
        for cut in ["чат и звонки", "chat and calls", "видеозвонок", "video call", "bitrix24", "битрикс24"] {
            if let r = t.range(of: cut) {
                t = String(t[..<r.lowerBound])
            }
        }
        return t.split { !$0.isLetter && !$0.isNumber }.first.map(String.init) ?? ""
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "\u{00a0}", with: " ")
    }

    private static func collect(from el: AXUIElement, depth: Int, maxDepth: Int, into labels: inout [String]) {
        if depth > maxDepth { return }
        if let role = stringAttr(el, kAXRoleAttribute as String),
           role == (kAXMenuBarRole as String) || role == (kAXMenuBarItemRole as String) || role == (kAXMenuRole as String) {
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
        for kid in kids.prefix(120) {
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
