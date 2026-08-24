import Foundation

public enum StenoCloudDestination: String, Codable, CaseIterable, Sendable {
    case webdav
    case s3
    case yandex
}

public enum StenoCloudSettings {
    private static let d = UserDefaults.standard

    private enum Key {
        static let autoUploadAfterSession = "cloud.autoUploadAfterSession"
        static let webdavEnabled = "cloud.webdav.enabled"
        static let webdavBaseURL = "cloud.webdav.baseURL"
        static let webdavUsername = "cloud.webdav.username"
        static let webdavPathPrefix = "cloud.webdav.pathPrefix"
        static let s3Enabled = "cloud.s3.enabled"
        static let s3Endpoint = "cloud.s3.endpoint"
        static let s3Region = "cloud.s3.region"
        static let s3Bucket = "cloud.s3.bucket"
        static let s3AccessKeyId = "cloud.s3.accessKeyId"
        static let s3PathPrefix = "cloud.s3.pathPrefix"
        static let yandexEnabled = "cloud.yandex.enabled"
        static let yandexAccountLabel = "cloud.yandex.accountLabel"
        static let yandexPathPrefix = "cloud.yandex.pathPrefix"
        /// Public OAuth client id (not a secret). Overrides Info.plist placeholder for local/beta builds.
        static let yandexOAuthClientID = "cloud.yandex.oauthClientID"
    }

    public static var autoUploadAfterSession: Bool {
        get { d.object(forKey: Key.autoUploadAfterSession) as? Bool ?? true }
        set { d.set(newValue, forKey: Key.autoUploadAfterSession) }
    }

    public static var webdavEnabled: Bool {
        get { d.object(forKey: Key.webdavEnabled) as? Bool ?? false }
        set { d.set(newValue, forKey: Key.webdavEnabled) }
    }

    public static var webdavBaseURL: String {
        get { d.string(forKey: Key.webdavBaseURL) ?? "" }
        set { d.set(newValue, forKey: Key.webdavBaseURL) }
    }

    public static var webdavUsername: String {
        get { d.string(forKey: Key.webdavUsername) ?? "" }
        set { d.set(newValue, forKey: Key.webdavUsername) }
    }

    public static var webdavPathPrefix: String {
        get { d.string(forKey: Key.webdavPathPrefix) ?? "" }
        set { d.set(newValue, forKey: Key.webdavPathPrefix) }
    }

    public static var s3Enabled: Bool {
        get { d.object(forKey: Key.s3Enabled) as? Bool ?? false }
        set { d.set(newValue, forKey: Key.s3Enabled) }
    }

    public static var s3Endpoint: String {
        get { d.string(forKey: Key.s3Endpoint) ?? "" }
        set { d.set(newValue, forKey: Key.s3Endpoint) }
    }

    public static var s3Region: String {
        get { d.string(forKey: Key.s3Region) ?? "" }
        set { d.set(newValue, forKey: Key.s3Region) }
    }

    public static var s3Bucket: String {
        get { d.string(forKey: Key.s3Bucket) ?? "" }
        set { d.set(newValue, forKey: Key.s3Bucket) }
    }

    public static var s3AccessKeyId: String {
        get { d.string(forKey: Key.s3AccessKeyId) ?? "" }
        set { d.set(newValue, forKey: Key.s3AccessKeyId) }
    }

    public static var s3PathPrefix: String {
        get { d.string(forKey: Key.s3PathPrefix) ?? "" }
        set { d.set(newValue, forKey: Key.s3PathPrefix) }
    }

    public static var yandexEnabled: Bool {
        get { d.object(forKey: Key.yandexEnabled) as? Bool ?? false }
        set { d.set(newValue, forKey: Key.yandexEnabled) }
    }

    public static var yandexAccountLabel: String {
        get { d.string(forKey: Key.yandexAccountLabel) ?? "" }
        set { d.set(newValue, forKey: Key.yandexAccountLabel) }
    }

    public static var yandexPathPrefix: String {
        get {
            let raw = d.string(forKey: Key.yandexPathPrefix) ?? ""
            let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return trimmed.isEmpty ? "SnapKadr" : trimmed
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            d.set(trimmed.isEmpty ? "SnapKadr" : trimmed, forKey: Key.yandexPathPrefix)
        }
    }

    public static var yandexOAuthClientID: String {
        get { d.string(forKey: Key.yandexOAuthClientID) ?? "" }
        set { d.set(newValue, forKey: Key.yandexOAuthClientID) }
    }

    public static func enabledDestinations() -> [StenoCloudDestination] {
        StenoCloudDestination.allCases.filter { isEnabled($0) }
    }

    public static func isEnabled(_ destination: StenoCloudDestination) -> Bool {
        switch destination {
        case .webdav: return webdavEnabled
        case .s3: return s3Enabled
        case .yandex: return yandexEnabled
        }
    }
}
