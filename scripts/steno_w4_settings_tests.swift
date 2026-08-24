// swiftc -parse-as-library scripts/steno_w4_settings_tests.swift -o /tmp/steno_w4_settings && /tmp/steno_w4_settings
import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoW4SettingsTests {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let settings = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoCloudSettings.swift"),
            encoding: .utf8
        )
        expect(settings.contains("cloud.autoUploadAfterSession"), "auto key")
        expect(settings.contains("cloud.webdav.enabled"), "webdav enable")
        expect(settings.contains("cloud.s3.enabled"), "s3 enable")
        expect(settings.contains("cloud.yandex.enabled"), "yandex enable")
        expect(settings.contains("enabledDestinations"), "enabled list helper")
        expect(!settings.contains("remoteKind"), "no single-kind picker")
        expect(!settings.contains("defaults.set") || !settings.lowercased().contains("\"password\""), "no password in UD")
        expect(!settings.contains("yandex.accessToken"), "token not in UD")

        let g = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/PrefsGeneralView.swift"),
            encoding: .utf8
        )
        expect(g.contains("Хранилище проектов") || g.contains("Project storage"), "section")
        expect(g.contains("webdavEnabled") || g.contains("cloud.webdav.enabled"), "webdav toggle")
        expect(g.contains("s3Enabled") || g.contains("cloud.s3.enabled"), "s3 toggle")
        expect(g.contains("yandexEnabled") || g.contains("cloud.yandex.enabled"), "yandex toggle")
        expect(g.contains("Автозагрузка после сессии") || g.contains("Auto-upload after session"), "auto")
        expect(g.contains("Проверить соединение") || g.contains("Test connection"), "test")
        expect(g.contains("Загрузить сейчас") || g.contains("Upload now"), "flush")
        expect(g.contains("StenoCloudSync") || g.contains("flushQueue"), "flush wiring")
        expect(!g.contains("recordCallVideo"), "no call video")

        let kadr = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/PrefsKadrView.swift"),
            encoding: .utf8
        )
        expect(!kadr.contains("folderSection") && !kadr.contains("Папка проектов"), "folder moved")

        let steno = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/PrefsStenoView.swift"),
            encoding: .utf8
        )
        expect(!steno.contains("WebDAV") && !steno.contains("StenoCloudSync"), "no cloud on Steno tab")

        exit(failures == 0 ? 0 : 1)
    }
}
