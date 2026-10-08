import Foundation

/// Снимок текущего созвона из AutoFocus (`current_call_context.json`).
/// Опциональная интеграция: если AutoFocus не установлен или файла нет — `load` = nil, SnapKadr работает как обычно.
public struct AutoFocusCallContext: Sendable {
    public var active: Bool
    public var companyId: String?
    public var company: String?
    public var companySource: String?
    public var hubProjectId: String?
    public var domain: String?
    public var app: String?

    public static var isAutoFocusContextAvailable: Bool {
        FileManager.default.fileExists(atPath: defaultURL.path)
    }

    public static func load(
        from url: URL = AutoFocusCallContext.defaultURL
    ) -> AutoFocusCallContext? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return AutoFocusCallContext(
            active: obj["active"] as? Bool ?? false,
            companyId: obj["companyId"] as? String,
            company: obj["company"] as? String,
            companySource: obj["companySource"] as? String,
            hubProjectId: obj["hubProjectId"] as? String,
            domain: obj["domain"] as? String,
            app: obj["app"] as? String
        )
    }

    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Automation/HammerspoonState/current_call_context.json")
    }

    /// Hub project id: из контекста или маппинг companyId.
    public var resolvedHubProjectId: String? {
        if let hubProjectId, !hubProjectId.isEmpty { return hubProjectId }
        guard let companyId, !companyId.isEmpty else { return nil }
        switch companyId.lowercased() {
        case "gexa": return "gexa"
        case "fhm": return "fhm"
        case "lab-industries", "lab": return "lab"
        case "мать-и-дитя", "mamadeti", "mit": return "mit"
        case "gor-stroy", "gorstroy": return "gorstroy"
        default: return nil
        }
    }
}
