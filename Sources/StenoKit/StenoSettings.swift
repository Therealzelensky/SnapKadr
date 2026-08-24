import Foundation

public enum StenoSettings {
    public static var defaults: UserDefaults = .standard
    private static let key = "steno.enabledSources"
    private static let enabledKey = "steno.isEnabled"
    private static let recordShareKey = "steno.recordShare"
    private static let namesFromCallWindowKey = "speech.stenoNamesFromCallWindow"
    private static let separateSpeakersKey = "speech.stenoSeparateSpeakers"

    public static var isEnabled: Bool {
        get {
            if defaults.object(forKey: enabledKey) == nil { return true }
            return defaults.bool(forKey: enabledKey)
        }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    public static var recordShare: Bool {
        get {
            if defaults.object(forKey: recordShareKey) == nil { return true }
            return defaults.bool(forKey: recordShareKey)
        }
        set { defaults.set(newValue, forKey: recordShareKey) }
    }

    public static var namesFromCallWindow: Bool {
        get {
            if defaults.object(forKey: namesFromCallWindowKey) == nil { return true }
            return defaults.bool(forKey: namesFromCallWindowKey)
        }
        set { defaults.set(newValue, forKey: namesFromCallWindowKey) }
    }

    public static var separateSpeakers: Bool {
        get {
            if defaults.object(forKey: separateSpeakersKey) == nil { return true }
            return defaults.bool(forKey: separateSpeakersKey)
        }
        set { defaults.set(newValue, forKey: separateSpeakersKey) }
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
