import Foundation
import Security

/// Destination-scoped cloud secrets. Never log returned values.
public enum StenoCloudKeychain {
    public static let service = "com.snapkadr.cloud"

    public static func accountName(destination: StenoCloudDestination, field: String) -> String {
        "\(destination.rawValue).\(field)"
    }

    public static func set(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    public static func get(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.unhandled(status)
        }
        return String(data: data, encoding: .utf8)
    }

    public static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }

    public static func clear(destination: StenoCloudDestination) throws {
        switch destination {
        case .webdav:
            try delete(account: accountName(destination: .webdav, field: "password"))
        case .s3:
            try delete(account: accountName(destination: .s3, field: "secretAccessKey"))
        case .yandex:
            try delete(account: accountName(destination: .yandex, field: "accessToken"))
            try delete(account: accountName(destination: .yandex, field: "refreshToken"))
            // Keep yandex.clientSecret so reconnect does not require re-entering the app secret.
        }
    }

    public enum KeychainError: Error {
        case unhandled(OSStatus)
    }
}
