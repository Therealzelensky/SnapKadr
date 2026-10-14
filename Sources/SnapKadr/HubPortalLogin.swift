import AppKit
import WebKit

/// Вход на портал Hub в окне приложения. Cookie `HubPortal` HttpOnly,
/// поэтому его нельзя прочитать из Safari — берём из WKWebView после формы.
@MainActor
final class HubPortalLogin: NSObject {
    static let shared = HubPortalLogin()

    private var window: NSWindow?
    private var webView: WKWebView?
    private var didCapture = false

    func present() {
        if let window, window.isVisible { return }

        let config = WKWebViewConfiguration()
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 440, height: 560), configuration: config)
        web.navigationDelegate = self

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = L10n.tr("Вход в Server Hub", "Sign in to Server Hub")
        win.contentView = web
        win.delegate = self
        win.center()
        win.level = .floating

        didCapture = false
        webView = web
        window = win
        config.websiteDataStore.httpCookieStore.add(self)

        let login = loginURL()
        web.load(URLRequest(url: login))
        NSApp.setActivationPolicy(.regular)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        StenoCloudLog.log("Hub login window \(login.absoluteString)")
    }

    fileprivate func capture(_ cookies: [HTTPCookie]) {
        guard !didCapture else { return }
        let host = URL(string: StenoCloudSettings.hubBaseURL)?.host ?? "ruserverhub.ru"
        guard let cookie = cookies.first(where: { item in
            item.name == "HubPortal"
                && !item.value.isEmpty
                && domain(item.domain, matches: host)
        }) else { return }

        didCapture = true
        StenoCloudSettings.hubSessionCookie = "HubPortal=\(cookie.value)"
        StenoCloudLog.log("Hub session saved, retry upload")
        // close/release WKWebView on the next turn. Doing it inside the cookie
        // callback crashes in objc_release (windowWillClose).
        let win = window
        window?.delegate = nil
        DispatchQueue.main.async {
            win?.orderOut(nil)
            win?.close()
            self.teardown()
            Task { await StenoCloudSync.shared.retryDestination(.hub) }
        }
    }

    private func loginURL() -> URL {
        let raw = StenoCloudSettings.hubBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = URL(string: raw) ?? URL(string: "https://ruserverhub.ru")!
        return base.appendingPathComponent("portal-auth/login")
    }

    private func domain(_ cookieDomain: String, matches host: String) -> Bool {
        let domain = cookieDomain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return host == domain || host.hasSuffix("." + domain) || domain.hasSuffix(host)
    }

    private func teardown() {
        if let webView {
            webView.configuration.websiteDataStore.httpCookieStore.remove(self)
        }
        webView = nil
        window = nil
    }
}

extension HubPortalLogin: WKHTTPCookieStoreObserver {
    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        DispatchQueue.main.async {
            cookieStore.getAllCookies { cookies in
                HubPortalLogin.shared.capture(cookies)
            }
        }
    }
}

extension HubPortalLogin: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                HubPortalLogin.shared.capture(cookies)
            }
        }
    }
}

extension HubPortalLogin: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            HubPortalLogin.shared.teardown()
        }
    }
}
