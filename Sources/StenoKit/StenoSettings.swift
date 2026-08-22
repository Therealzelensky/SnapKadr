import Foundation

public enum StenoSettings {
    public static var defaults: UserDefaults = .standard
    private static let key = "steno.enabledSources"
    private static let enabledKey = "steno.isEnabled"

    public static var isEnabled: Bool {
        get {
            if defaults.object(forKey: enabledKey) == nil { return true }
            return defaults.bool(forKey: enabledKey)
        }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    public static var enabledSources: Set<StenoSource> {
        get {
            guard let raw = defaults.array(forKey: key) as? [String] else {
                return Set(StenoSource.allCases)
            }
            return Set(raw.compactMap(StenoSource.init(rawValue:)))
        }
        set {
            defaults.set(newValue.map(\.rawValue).sorted(), forKey: key)
        }
    }

    public static func isEnabled(_ source: StenoSource) -> Bool {
        enabledSources.contains(source)
    }

    public static func setEnabled(_ source: StenoSource, _ on: Bool) {
        var s = enabledSources
        if on { s.insert(source) } else { s.remove(source) }
        enabledSources = s
    }
}
