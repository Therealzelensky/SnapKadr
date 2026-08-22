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

        let b24 = StenoWindowSnapshot(windowID: 7, bundleID: "com.bitrixsoft.Bitrix24", title: "Видеозвонок", ownerName: "Bitrix24")
        expect(StenoMatcher.match(b24, enabled: all) == .bitrixSync, "bitrix desktop")

        exit(failures == 0 ? 0 : 1)
    }
}
