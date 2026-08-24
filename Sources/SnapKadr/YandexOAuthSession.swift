import AppKit
import Foundation

/// Yandex OAuth for Disk API.
///
/// With Redirect URI `https://oauth.yandex.ru/verification_code` Yandex shows the
/// result in the browser. For `response_type=token` the page URL contains
/// `#access_token=…` (see Yandex “obtain a token manually”). The user pastes
/// that URL or the token itself — no Client Secret required for this path.
///
/// Fallback: short confirmation codes are exchanged via `authorization_code`
/// (needs Client Secret in Keychain).
///
/// Client id: prefs → Info.plist → env.
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

        var components = URLComponents(url: Self.authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "token"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "force_confirm", value: "yes")
        ]
        guard let url = components.url else {
            throw StenoCloudError.network("bad authorize URL")
        }

        NSWorkspace.shared.open(url)
        let pasted = try await Self.promptPaste(
            presenter: presenter,
            title: L10n.tr("Токен Яндекса", "Yandex token"),
            message: L10n.tr(
                "После «Разрешить» откроется страница verification_code. Скопируйте адрес из строки браузера (или сам access_token) и вставьте сюда.",
                "After Allow, the verification_code page opens. Paste the browser URL (or the access_token) here."
            )
        )

        let token: String
        if let fromURL = Self.extractAccessToken(fromPasted: pasted) {
            token = fromURL
        } else if Self.looksLikeAccessToken(pasted) {
            token = pasted
        } else if Self.looksLikeConfirmationCode(pasted) {
            let secret = (try StenoCloudKeychain.get(account: Self.clientSecretAccount) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !secret.isEmpty else {
                throw StenoCloudError.network(
                    L10n.tr(
                        "Это код подтверждения — нужен Client Secret, либо вставьте URL/#access_token со страницы.",
                        "That’s a confirmation code — enter Client Secret, or paste the page URL/#access_token instead."
                    )
                )
            }
            let tokens = try await Self.exchangeAuthorizationCode(
                pasted,
                clientID: clientID,
                clientSecret: secret
            )
            token = tokens.access
            if let refresh = tokens.refresh, !refresh.isEmpty {
                try StenoCloudKeychain.set(
                    refresh,
                    account: StenoCloudKeychain.accountName(destination: .yandex, field: "refreshToken")
                )
            }
        } else {
            throw StenoCloudError.network(
                L10n.tr(
                    "Не похоже на токен или код. Вставьте URL страницы verification_code целиком.",
                    "Doesn’t look like a token or code. Paste the full verification_code page URL."
                )
            )
        }

        try Self.storeAccessToken(token)
        try await YandexDiskClient(oauth: self).ensureAppRootFolder(token: token)
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

    static func storeAccessToken(_ token: String) throws {
        try StenoCloudKeychain.set(
            token,
            account: StenoCloudKeychain.accountName(destination: .yandex, field: "accessToken")
        )
        if StenoCloudSettings.yandexAccountLabel.isEmpty {
            StenoCloudSettings.yandexAccountLabel = "Яндекс Диск"
        }
    }

    static func extractAccessToken(fromPasted pasted: String) -> String? {
        let trimmed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let token = try? parseAccessToken(from: url) {
            return token
        }
        // Browser may copy "…verification_code#access_token=…&expires_in=…"
        if trimmed.contains("access_token=") {
            let fake = URL(string: "https://oauth.yandex.ru/verification_code?\(trimmed.replacingOccurrences(of: "#", with: "&"))")
                ?? URL(string: "https://oauth.yandex.ru/verification_code#\(trimmed)")
            if let fake, let token = try? parseAccessToken(from: fake) {
                return token
            }
            // Parse fragment-style blob without a full URL.
            if let token = parseTokenBlob(trimmed) {
                return token
            }
        }
        return nil
    }

    static func looksLikeAccessToken(_ value: String) -> Bool {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // Yandex tokens are long opaque strings; confirmation codes are short.
        return v.count >= 20 && !v.contains(" ") && !v.contains("=") && !v.contains("://")
    }

    static func looksLikeConfirmationCode(_ value: String) -> Bool {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return (6...12).contains(v.count) && v.allSatisfy(\.isNumber)
    }

    @MainActor
    static func promptPaste(presenter: NSWindow?, title: String, message: String) async throws -> String {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: L10n.tr("Подключить", "Connect"))
        alert.addButton(withTitle: L10n.tr("Отмена", "Cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        field.placeholderString = "https://oauth.yandex.ru/verification_code#access_token=…"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        // Prefer app-modal so sheet attachment quirks on prefs panels don’t swallow the result.
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        field.window?.makeFirstResponder(nil)
        guard response == .alertFirstButtonReturn else {
            throw StenoCloudError.cancelled
        }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw StenoCloudError.network(
                L10n.tr("Пустое поле — вставьте URL или токен со страницы.", "Empty — paste the page URL or token.")
            )
        }
        return value
    }

    static func exchangeAuthorizationCode(
        _ code: String,
        clientID: String,
        clientSecret: String
    ) async throws -> (access: String, refresh: String?) {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(status) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? String
            {
                let desc = json["error_description"] as? String ?? body
                throw StenoCloudError.server(status: status, message: "\(err): \(desc)")
            }
            throw StenoCloudError.server(status: status, message: body.isEmpty ? "token exchange failed" : body)
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

    static func parseAccessToken(from url: URL) throws -> String {
        if let token = parseTokenBlob(url.fragment ?? "") { return token }
        if let token = parseTokenBlob(url.query ?? "") { return token }
        throw StenoCloudError.authRequired
    }

    private static func parseTokenBlob(_ blob: String) -> String? {
        guard !blob.isEmpty else { return nil }
        var values: [String: String] = [:]
        for pair in blob.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            values[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
        }
        if values["error"] != nil { return nil }
        if let token = values["access_token"], !token.isEmpty { return token }
        return nil
    }
}
