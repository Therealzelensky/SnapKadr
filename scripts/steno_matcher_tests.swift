import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoMatcherTests {
    static func main() {
        let all = Set(StenoSource.allCases)
        let zoom = StenoWindowSnapshot(windowID: 1, bundleID: "us.zoom.xos", title: "Zoom Meeting", ownerName: "zoom.us")
        expect(StenoMatcher.match(zoom, enabled: all) == .zoom, "zoom bundle")
        expect(StenoMatcher.match(zoom, enabled: [.telegram]) == nil, "zoom disabled")

        let chat = StenoWindowSnapshot(windowID: 2, bundleID: "ru.keepcoder.Telegram", title: "Saved Messages", ownerName: "Telegram")
        expect(StenoMatcher.match(chat, enabled: all) == nil, "telegram chat ignored")
        let tgCall = StenoWindowSnapshot(windowID: 3, bundleID: "ru.keepcoder.Telegram", title: "Anna (звонок)", ownerName: "Telegram")
        expect(StenoMatcher.match(tgCall, enabled: all) == .telegram, "telegram call")

        let meet = StenoWindowSnapshot(windowID: 4, bundleID: "com.google.Chrome", title: "Standup - Google Meet", ownerName: "Chrome")
        expect(StenoMatcher.match(meet, enabled: all) == .googleMeet, "meet chrome")
        let chromeNews = StenoWindowSnapshot(windowID: 5, bundleID: "com.google.Chrome", title: "Hacker News", ownerName: "Chrome")
        expect(StenoMatcher.match(chromeNews, enabled: all) == nil, "chrome without meet")

        let tm = StenoWindowSnapshot(windowID: 6, bundleID: "com.apple.Safari", title: "Планерка — Телемост", ownerName: "Safari")
        expect(StenoMatcher.match(tm, enabled: all) == .telemost, "telemost safari")

        let tmApp = StenoWindowSnapshot(
            windowID: 11,
            bundleID: "ru.yandex.desktop.telemost",
            title: "Яндекс Телемост",
            ownerName: "Яндекс Телемост"
        )
        expect(StenoMatcher.match(tmApp, enabled: all) == .telemost, "telemost desktop app")
        let tmAppBlank = StenoWindowSnapshot(
            windowID: 12,
            bundleID: "ru.yandex.desktop.telemost",
            title: "",
            ownerName: "Яндекс Телемост"
        )
        expect(StenoMatcher.match(tmAppBlank, enabled: all) == .telemost, "telemost desktop empty title")

        let b24 = StenoWindowSnapshot(windowID: 7, bundleID: "com.bitrixsoft.Bitrix24", title: "Видеозвонок", ownerName: "Bitrix24")
        expect(StenoMatcher.match(b24, enabled: all) == .bitrixSync, "bitrix desktop in-call")

        let b24BrowserCall = StenoWindowSnapshot(
            windowID: 28,
            bundleID: "com.apple.Safari",
            title: "Гекса — Видеозвонок — Bitrix24",
            ownerName: "Safari"
        )
        expect(StenoMatcher.match(b24BrowserCall, enabled: all) == .bitrixSync, "bitrix safari in-call")

        let safariSync = StenoWindowSnapshot(
            windowID: 8,
            bundleID: "com.apple.Safari",
            title: "Гекса — (16) Чат и звонки",
            ownerName: "Safari"
        )
        expect(StenoMatcher.match(safariSync, enabled: all) == nil, "bitrix chat tab is not a live call")
        expect(StenoMatcher.match(safariSync, enabled: [.zoom]) == nil, "bitrix safari disabled")

        let safariCRM = StenoWindowSnapshot(
            windowID: 9,
            bundleID: "com.apple.Safari",
            title: "Гекса — тестовая Первый вход в ЛПУ",
            ownerName: "Safari"
        )
        expect(StenoMatcher.match(safariCRM, enabled: all) == nil, "bitrix crm tab ignored")

        let chromeEN = StenoWindowSnapshot(
            windowID: 10,
            bundleID: "com.google.Chrome",
            title: "Acme — (3) Chat and Calls",
            ownerName: "Chrome"
        )
        expect(StenoMatcher.match(chromeEN, enabled: all) == nil, "bitrix chrome english im is not a live call")

        let zoomBlank = StenoWindowSnapshot(windowID: 13, bundleID: "us.zoom.xos", title: "", ownerName: "zoom.us")
        expect(StenoMatcher.match(zoomBlank, enabled: all) == nil, "zoom empty title is not a call")
        let zoomMain = StenoWindowSnapshot(windowID: 27, bundleID: "us.zoom.xos", title: "Zoom", ownerName: "zoom.us")
        expect(StenoMatcher.match(zoomMain, enabled: all) == nil, "zoom main window ignored")
        let zoomClips = StenoWindowSnapshot(windowID: 14, bundleID: "us.zoom.ZoomPresence", title: "", ownerName: "Zoom")
        expect(StenoMatcher.match(zoomClips, enabled: all) == nil, "zoom presence empty title")

        let tgVideo = StenoWindowSnapshot(
            windowID: 15,
            bundleID: "ru.keepcoder.Telegram",
            title: "Маша (видеозвонок)",
            ownerName: "Telegram"
        )
        expect(StenoMatcher.match(tgVideo, enabled: all) == .telegram, "telegram video call")
        let tgDesktop = StenoWindowSnapshot(
            windowID: 16,
            bundleID: "org.telegram.desktop",
            title: "Group call",
            ownerName: "Telegram"
        )
        expect(StenoMatcher.match(tgDesktop, enabled: all) == .telegram, "telegram desktop fork")
        let tgBlank = StenoWindowSnapshot(
            windowID: 17,
            bundleID: "ru.keepcoder.Telegram",
            title: "",
            ownerName: "Telegram"
        )
        expect(StenoMatcher.match(tgBlank, enabled: all) == nil, "telegram empty title is chat")

        let meetEmDash = StenoWindowSnapshot(
            windowID: 18,
            bundleID: "com.google.Chrome",
            title: "Meet – Weekly standup",
            ownerName: "Google Chrome"
        )
        expect(StenoMatcher.match(meetEmDash, enabled: all) == .googleMeet, "meet en-dash in-call title")
        let meetYandex = StenoWindowSnapshot(
            windowID: 19,
            bundleID: "ru.yandex.desktop.yandex-browser",
            title: "Встреча – Google Meet",
            ownerName: "Yandex"
        )
        expect(StenoMatcher.match(meetYandex, enabled: all) == .googleMeet, "meet in real Yandex Browser bundle")
        let meetPWA = StenoWindowSnapshot(
            windowID: 20,
            bundleID: "com.google.Chrome.app.kjeghcllcfmcjgembblinckiojfklkkb",
            title: "Meet – abc-defg-hij",
            ownerName: "Google Meet"
        )
        expect(StenoMatcher.match(meetPWA, enabled: all) == .googleMeet, "meet chrome pwa")
        let meetEdge = StenoWindowSnapshot(
            windowID: 21,
            bundleID: "com.microsoft.edgemac",
            title: "Google Meet",
            ownerName: "Microsoft Edge"
        )
        expect(StenoMatcher.match(meetEdge, enabled: all) == .googleMeet, "meet edge")

        let tmYandex = StenoWindowSnapshot(
            windowID: 22,
            bundleID: "ru.yandex.desktop.yandex-browser",
            title: "Совещание — telemost.yandex.ru",
            ownerName: "Yandex"
        )
        expect(StenoMatcher.match(tmYandex, enabled: all) == .telemost, "telemost in Yandex Browser")

        let b24WebApp = StenoWindowSnapshot(
            windowID: 23,
            bundleID: "com.apple.Safari.WebApp.927C1839-8229-476C-99F6-6AEB5FEAC285",
            title: "Б24 Гекса — (16) Чат и звонки",
            ownerName: "Б24 Гекса [ prod ]"
        )
        expect(StenoMatcher.match(b24WebApp, enabled: all) == nil, "bitrix safari web app chat is not a live call")
        let b24Gost = StenoWindowSnapshot(
            windowID: 24,
            bundleID: "ru.cryptopro.chromium-gost",
            title: "ГорСтрой — (6) Чат и звонки",
            ownerName: "Chromium-Gost"
        )
        expect(StenoMatcher.match(b24Gost, enabled: all) == nil, "bitrix chromium-gost chat is not a live call")
        let b24DesktopBlank = StenoWindowSnapshot(
            windowID: 25,
            bundleID: "com.bitrixsoft.Bitrix24",
            title: "",
            ownerName: "Bitrix24"
        )
        expect(StenoMatcher.match(b24DesktopBlank, enabled: all) == nil, "bitrix desktop empty title is not a call")
        let b24WebAppCRM = StenoWindowSnapshot(
            windowID: 26,
            bundleID: "com.apple.Safari.WebApp.927C1839-8229-476C-99F6-6AEB5FEAC285",
            title: "Сделка 2019",
            ownerName: "Б24 Гекса [ prod ]"
        )
        expect(StenoMatcher.match(b24WebAppCRM, enabled: all) == nil, "bitrix web app crm not a call")

        exit(failures == 0 ? 0 : 1)
    }
}
