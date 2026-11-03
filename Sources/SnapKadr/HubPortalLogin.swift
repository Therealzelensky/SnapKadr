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
    private var didDismiss = false

    /// Окно входа нельзя уничтожать на такте run loop. `WKWebView` при
    /// `stopLoading` / снятии с окна / `dealloc` освобождает объекты, которые
    /// текущий autorelease pool ещё отдаёт в `objc_release` — SIGSEGV.
    /// Держим спрятанное окно до выхода процесса.
    private static var parkedWebViews: [WKWebView] = []
    private static var parkedWindows: [NSWindow] = []

    func present() {
        if let window, window.isVisible { return }
        didDismiss = false

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
        win.isReleasedWhenClosed = false
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
        // getAllCookies ещё держит объекты WebKit в пуле этого такта.
        DispatchQueue.main.async {
            self.parkLoginInterface()
            Task { await StenoCloudSync.shared.retryDestination(.hub) }
        }
    }

    /// Спрятать окно, не уничтожая его. `close()`, `stopLoading` и снятие
    /// WKWebView с иерархии на такте run loop уже давали SIGSEGV в objc_release.
    private func parkLoginInterface() {
        guard !didDismiss else { return }
        didDismiss = true

        let web = webView
        let win = window
        web?.navigationDelegate = nil
        win?.delegate = nil

        if let web {
            Self.parkedWebViews.append(web)
        }
        if let win {
            Self.parkedWindows.append(win)
        }
        webView = nil
        window = nil

        DispatchQueue.main.async {
            win?.orderOut(nil)
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
    nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
        DispatchQueue.main.async {
            HubPortalLogin.shared.parkLoginInterface()
        }
        return false
    }
}
