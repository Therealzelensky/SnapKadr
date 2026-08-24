import ApplicationServices
import Foundation

/// Distinguishes Yandex Messenger chat (app open) from an actual call via Accessibility chrome.
/// Group calls reuse Telemost UI; 1:1 calls expose Messenger end-call controls.
public enum StenoYandexMessengerCallState {
    private static let inCallNeedles = [
        "завершить звонок",
        "end call",
        "открыть экран звонка",
        "звонок в яндекс телемосте",
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
            .replacingOccurrences(of: "\u{00a0}", with: " ")
        return inCallNeedles.contains(where: { hay.contains($0) })
    }

    public static func isInCall(pid: pid_t) -> Bool {
        isInCall(axLabels: collectLabels(pid: pid))
    }

    private static func collectLabels(pid: pid_t) -> [String] {
        let app = AXUIElementCreateApplication(pid)
        var labels: [String] = []
        // Walk windows, not the application: the menu bar is huge and the
        // Electron call chrome lives ~12 levels down inside AXWebArea.
        if let windows = copyAttr(app, kAXWindowsAttribute as String) as? [AXUIElement], !windows.isEmpty {
            for window in windows {
                collect(from: window, depth: 0, maxDepth: 20, into: &labels)
            }
            return labels
        }
        collect(from: app, depth: 0, maxDepth: 20, into: &labels)
        return labels
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
