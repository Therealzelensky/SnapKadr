import Foundation

public enum ProjectCloudRemoteKind: String, Codable, CaseIterable, Sendable {
    case none
    case webdav
    case s3
    case yandex
}

/// Non-secret cloud storage prefs (UserDefaults). Passwords / tokens live in Keychain only.
public enum ProjectCloudSettings {
    private static let d = UserDefaults.standard

    private enum Key {
        static let remoteKind = "cloud.remoteKind"
        static let autoUploadAfterSession = "cloud.autoUploadAfterSession"
        static let webdavBaseURL = "cloud.webdav.baseURL"
        static let webdavUsername = "cloud.webdav.username"
        static let webdavPathPrefix = "cloud.webdav.pathPrefix"
        static let s3Endpoint = "cloud.s3.endpoint"
        static let s3Region = "cloud.s3.region"
        static let s3Bucket = "cloud.s3.bucket"
        static let s3AccessKeyId = "cloud.s3.accessKeyId"
        static let s3PathPrefix = "cloud.s3.pathPrefix"
        static let yandexAccountLabel = "cloud.yandex.accountLabel"
        static let yandexPathPrefix = "cloud.yandex.pathPrefix"
    }

    public static var remoteKind: ProjectCloudRemoteKind {
        get {
            guard let raw = d.string(forKey: Key.remoteKind),
                  let kind = ProjectCloudRemoteKind(rawValue: raw)
            else { return .none }
            return kind
        }
        set { d.set(newValue.rawValue, forKey: Key.remoteKind) }
    }

    /// Default ON when key is missing.
    public static var autoUploadAfterSession: Bool {
        get { d.object(forKey: Key.autoUploadAfterSession) as? Bool ?? true }
        set { d.set(newValue, forKey: Key.autoUploadAfterSession) }
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

    public static var yandexAccountLabel: String {
        get { d.string(forKey: Key.yandexAccountLabel) ?? "" }
        set { d.set(newValue, forKey: Key.yandexAccountLabel) }
    }

    public static var yandexPathPrefix: String {
        get { d.string(forKey: Key.yandexPathPrefix) ?? "" }
        set { d.set(newValue, forKey: Key.yandexPathPrefix) }
    }

    /// When kind changes: UI deactivates old fields; optionally clear previous kind secrets.
    public static func setRemoteKind(_ kind: ProjectCloudRemoteKind, clearingPreviousSecrets: Bool) {
        let previous = remoteKind
        remoteKind = kind
        guard clearingPreviousSecrets, previous != kind, previous != .none else { return }
        try? ProjectCloudKeychain.clear(kind: previous)
    }
}
