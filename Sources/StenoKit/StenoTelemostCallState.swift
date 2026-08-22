import ApplicationServices
import Foundation

/// Distinguishes Telemost lobby (app open) from an actual meeting via Accessibility chrome.
public enum StenoTelemostCallState {
    private static let lobbyNeedles = [
        "новая видеовстреча",
        "подключиться",
        "запланировать",
        "новая трансляция",
        "new meeting",
        "join meeting",
        "schedule",
        "new livestream",
    ]

    private static let inCallNeedles = [
        "демонстрация",
        "участники",
        "participants",
        "screen share",
        "share screen",
        "share your screen",
    ]

    /// Pure rule for tests — titles/labels collected from AX (or fixtures).
    public static func isInCall(axLabels: [String]) -> Bool {
        let hay = axLabels.joined(separator: " ").lowercased()
        if lobbyNeedles.contains(where: { hay.contains($0) }) { return false }
        return inCallNeedles.contains(where: { hay.contains($0) })
    }

    public static func isInCall(pid: pid_t) -> Bool {
        isInCall(axLabels: collectLabels(pid: pid))
    }

    private static func collectLabels(pid: pid_t) -> [String] {
        let app = AXUIElementCreateApplication(pid)
        var labels: [String] = []
        collect(from: app, depth: 0, maxDepth: 8, into: &labels)
        return labels
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
