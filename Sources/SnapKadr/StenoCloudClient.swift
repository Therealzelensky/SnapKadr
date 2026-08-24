import Foundation

public enum StenoCloudError: Error, Equatable {
    case destinationDisabled
    case autoUploadDisabled
    case notAPackage
    case authRequired
    case missingYandexClientID
    case network(String)
    case server(status: Int, message: String)
    case cancelled
}

extension StenoCloudError: LocalizedError {
    public var errorDescription: String? {
        let ru = Locale.preferredLanguages.first?.hasPrefix("ru") == true
        switch self {
        case .destinationDisabled:
            return ru ? "Назначение выключено" : "Destination disabled"
        case .autoUploadDisabled:
            return ru ? "Автозагрузка выключена" : "Auto-upload disabled"
        case .notAPackage:
            return ru ? "Это не пакет .kadr" : "Not a .kadr package"
        case .authRequired:
            return ru ? "Нужна авторизация" : "Authorization required"
        case .missingYandexClientID:
            return ru
                ? "Укажите OAuth Client ID приложения Яндекса (поле ниже). Redirect URI: snapkadr://yandex-oauth"
                : "Enter a Yandex OAuth Client ID below. Redirect URI: snapkadr://yandex-oauth"
        case .network(let message):
            return message
        case .server(let status, let message):
            return "HTTP \(status): \(message)"
        case .cancelled:
            return ru ? "Отменено" : "Cancelled"
        }
    }
}

public protocol StenoCloudClient: AnyObject {
    var destination: StenoCloudDestination { get }
    func testConnection() async throws
    func uploadPackage(localProjectURL: URL) async throws
    func cancel()
}

public protocol StenoCloudPresenting: AnyObject {
    @MainActor func presentDeferredUploadToast(for destination: StenoCloudDestination)
    @MainActor func presentAuthRequiredToast(for destination: StenoCloudDestination)
}
