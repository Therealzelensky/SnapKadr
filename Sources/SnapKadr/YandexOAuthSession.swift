import AppKit
import Foundation

/// Yandex OAuth for Disk API.
///
/// Default flow matches Yandex console “Redirect URI =
/// https://oauth.yandex.ru/verification_code”: open the browser, user pastes
/// the confirmation code, we exchange it for tokens (needs Client Secret).
///
/// Client id: prefs `cloud.yandex.oauthClientID` → Info.plist → env.
/// Client secret: Keychain `yandex.clientSecret` (never UserDefaults).
public final class YandexOAuthSession: NSObject {
    public static let redirectURI = "https://oauth.yandex.ru/verification_code"
    public static let authorizeURL = URL(string: "https://oauth.yandex.ru/authorize")!
    public static let tokenURL = URL(string: "https://oauth.yandex.ru/token")!

    public static var clientID: String {
        let prefs = StenoCloudSettings.yandexOAuthClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.isUsableClientID(prefs) { return prefs }
        if let id = Bundle.main.object(forInfoDictionaryKey: "YandexDiskOAuthClientID") as? String {
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            if Self.isUsableClientID(trimmed) { return trimmed }
        }
        if let env = ProcessInfo.processInfo.environment["SNAPKADR_YANDEX_OAUTH_CLIENT_ID"] {
            let trimmed = env.trimmingCharacters(in: .whitespacesAndNewlines)
            if Self.isUsableClientID(trimmed) { return trimmed }
        }
        return ""
    }

    public static func isUsableClientID(_ id: String) -> Bool {
        !id.isEmpty && id != "YOUR_YANDEX_OAUTH_CLIENT_ID"
    }

    public static var clientSecretAccount: String {
        StenoCloudKeychain.accountName(destination: .yandex, field: "clientSecret")
    }

    public override init() {
        super.init()
    }

    @MainActor
    public func connect(presenter: NSWindow?) async throws {
        let clientID = Self.clientID
        guard !clientID.isEmpty else {
            throw StenoCloudError.missingYandexClientID
        }
        let secret = (try StenoCloudKeychain.get(account: Self.clientSecretAccount) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !secret.isEmpty else {
            throw StenoCloudError.network(
                Locale.preferredLanguages.first?.hasPrefix("ru") == true
                    ? "Укажите OAuth Client Secret (поле ниже) — нужен для кода с oauth.yandex.ru/verification_code"
                    : "Enter OAuth Client Secret below — required for oauth.yandex.ru/verification_code"
            )
        }

        var components = URLComponents(url: Self.authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "force_confirm", value: "yes")
        ]
        guard let url = components.url else {
            throw StenoCloudError.network("bad authorize URL")
        }

        NSWorkspace.shared.open(url)
        let code = try await Self.promptAuthorizationCode(presenter: presenter)
        let tokens = try await Self.exchangeAuthorizationCode(
            code,
            clientID: clientID,
            clientSecret: secret
        )
        try StenoCloudKeychain.set(
            tokens.access,
            account: StenoCloudKeychain.accountName(destination: .yandex, field: "accessToken")
        )
        if let refresh = tokens.refresh, !refresh.isEmpty {
            try StenoCloudKeychain.set(
                refresh,
                account: StenoCloudKeychain.accountName(destination: .yandex, field: "refreshToken")
            )
        } else {
            try? StenoCloudKeychain.delete(
                account: StenoCloudKeychain.accountName(destination: .yandex, field: "refreshToken")
            )
        }
        if StenoCloudSettings.yandexAccountLabel.isEmpty {
            StenoCloudSettings.yandexAccountLabel = "Яндекс Диск"
        }
    }

    public func disconnect() throws {
        try StenoCloudKeychain.clear(destination: .yandex)
        StenoCloudSettings.yandexAccountLabel = ""
    }

    public func validAccessToken() async throws -> String {
        if let access = try StenoCloudKeychain.get(
            account: StenoCloudKeychain.accountName(destination: .yandex, field: "accessToken")
        ), !access.isEmpty {
            return access
        }
        if let refresh = try StenoCloudKeychain.get(
            account: StenoCloudKeychain.accountName(destination: .yandex, field: "refreshToken")
        ), !refresh.isEmpty {
            throw StenoCloudError.authRequired
        }
        throw StenoCloudError.authRequired
    }

    @MainActor
    static func promptAuthorizationCode(presenter: NSWindow?) async throws -> String {
        let alert = NSAlert()
        alert.messageText = L10n.tr(
            "Код подтверждения Яндекса",
            "Yandex confirmation code"
        )
        alert.informativeText = L10n.tr(
            "Скопируйте код со страницы oauth.yandex.ru/verification_code и вставьте сюда.",
            "Copy the code from oauth.yandex.ru/verification_code and paste it here."
        )
        alert.addButton(withTitle: L10n.tr("Подключить", "Connect"))
        alert.addButton(withTitle: L10n.tr("Отмена", "Cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "code"
        alert.accessoryView = field

        let response: NSApplication.ModalResponse
        if let presenter {
            response = await withCheckedContinuation { cont in
                alert.beginSheetModal(for: presenter) { cont.resume(returning: $0) }
            }
        } else {
            response = alert.runModal()
        }
        guard response == .alertFirstButtonReturn else {
            throw StenoCloudError.cancelled
        }
        let code = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { throw StenoCloudError.authRequired }
        return code
    }

    static func exchangeAuthorizationCode(
        _ code: String,
        clientID: String,
        clientSecret: String
    ) async throws -> (access: String, refresh: String?) {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body: [URLQueryItem] = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "client_secret", value: clientSecret)
        ]
        var components = URLComponents()
        components.queryItems = body
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            let msg = String(data: data, encoding: .utf8) ?? "token exchange failed"
            throw StenoCloudError.server(status: status, message: msg)
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let access = json["access_token"] as? String,
            !access.isEmpty
        else {
            throw StenoCloudError.authRequired
        }
        return (access, json["refresh_token"] as? String)
    }

    /// Parses implicit-flow callback URLs (kept for tests / future custom scheme).
    static func parseAccessToken(from url: URL) throws -> String {
        let fragment = url.fragment ?? ""
        let query = url.query ?? ""
        let blob = fragment.isEmpty ? query : fragment
        var values: [String: String] = [:]
        for pair in blob.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            values[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
        }
        if let err = values["error"] {
            throw StenoCloudError.network(err)
        }
        guard let token = values["access_token"], !token.isEmpty else {
            throw StenoCloudError.authRequired
        }
        return token
    }
}
