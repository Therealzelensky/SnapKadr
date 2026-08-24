import AppKit
import AuthenticationServices
import Foundation

/// Yandex OAuth via ASWebAuthenticationSession.
///
/// Register a Yandex OAuth app and put the client id in Info.plist key
/// `YandexDiskOAuthClientID` (or env `SNAPKADR_YANDEX_OAUTH_CLIENT_ID` at build time).
/// Redirect URI must be `snapkadr://yandex-oauth` (CFBundleURLTypes).
/// Prefer public native app; no client secret is committed. Token response uses
/// `response_type=token` (implicit); refresh token slot is reserved for a future
/// authorization-code + PKCE upgrade when the registered app supports it.
public final class YandexOAuthClient: NSObject {
    public static let redirectURI = "snapkadr://yandex-oauth"
    public static let authorizeURL = URL(string: "https://oauth.yandex.ru/authorize")!
    public static let tokenURL = URL(string: "https://oauth.yandex.ru/token")!

    public static var clientID: String {
        if let id = Bundle.main.object(forInfoDictionaryKey: "YandexDiskOAuthClientID") as? String,
           !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           id != "YOUR_YANDEX_OAUTH_CLIENT_ID"
        {
            return id.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Placeholder — Connect will throw authRequired until a real client id is set.
        return ""
    }

    private var session: ASWebAuthenticationSession?
    private let presentation = YandexOAuthPresentation()

    public override init() {
        super.init()
    }

    @MainActor
    public func connect(presenter: NSWindow?) async throws {
        let clientID = Self.clientID
        guard !clientID.isEmpty else {
            throw ProjectCloudError.network(
                "Yandex OAuth client id missing — set Info.plist YandexDiskOAuthClientID"
            )
        }

        var components = URLComponents(url: Self.authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "token"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "force_confirm", value: "yes")
        ]
        guard let url = components.url else {
            throw ProjectCloudError.network("bad authorize URL")
        }

        presentation.anchorWindow = presenter

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let auth = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "snapkadr"
            ) { callback, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let callback else {
                    cont.resume(throwing: ProjectCloudError.authRequired)
                    return
                }
                cont.resume(returning: callback)
            }
            auth.presentationContextProvider = self.presentation
            auth.prefersEphemeralWebBrowserSession = false
            self.session = auth
            if !auth.start() {
                cont.resume(throwing: ProjectCloudError.network("OAuth session failed to start"))
            }
        }

        let token = try Self.parseAccessToken(from: callbackURL)
        try ProjectCloudKeychain.set(
            token,
            account: ProjectCloudKeychain.accountName(kind: .yandex, field: "accessToken")
        )
        // Implicit flow has no refresh token; clear stale refresh if any.
        try? ProjectCloudKeychain.delete(
            account: ProjectCloudKeychain.accountName(kind: .yandex, field: "refreshToken")
        )
        if ProjectCloudSettings.yandexAccountLabel.isEmpty {
            ProjectCloudSettings.yandexAccountLabel = "Яндекс Диск"
        }
    }

    public func disconnect() throws {
        try ProjectCloudKeychain.clear(kind: .yandex)
        ProjectCloudSettings.yandexAccountLabel = ""
    }

    public func validAccessToken() async throws -> String {
        if let access = try ProjectCloudKeychain.get(
            account: ProjectCloudKeychain.accountName(kind: .yandex, field: "accessToken")
        ), !access.isEmpty {
            return access
        }
        // Future: use refreshToken against tokenURL when code+PKCE is wired.
        if let refresh = try ProjectCloudKeychain.get(
            account: ProjectCloudKeychain.accountName(kind: .yandex, field: "refreshToken")
        ), !refresh.isEmpty {
            throw ProjectCloudError.authRequired
        }
        throw ProjectCloudError.authRequired
    }

    static func parseAccessToken(from url: URL) throws -> String {
        // Implicit: snapkadr://yandex-oauth#access_token=...&token_type=bearer&expires_in=...
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
            throw ProjectCloudError.network(err)
        }
        guard let token = values["access_token"], !token.isEmpty else {
            throw ProjectCloudError.authRequired
        }
        return token
    }
}

private final class YandexOAuthPresentation: NSObject, ASWebAuthenticationPresentationContextProviding {
    weak var anchorWindow: NSWindow?

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let anchorWindow { return anchorWindow }
        if let key = NSApp.keyWindow { return key }
        if let first = NSApp.windows.first { return first }
        return NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
    }
}
