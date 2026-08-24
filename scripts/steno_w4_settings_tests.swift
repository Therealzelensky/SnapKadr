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
        let settingsPath = root.appendingPathComponent("Sources/SnapKadr/ProjectCloudSettings.swift")
        expect(FileManager.default.fileExists(atPath: settingsPath.path), "settings file")

        let settings = (try? String(contentsOf: settingsPath, encoding: .utf8)) ?? ""
        expect(settings.contains("cloud.remoteKind"), "kind key")
        expect(settings.contains("cloud.autoUploadAfterSession"), "auto key")
        expect(
            settings.contains("case none")
                && settings.contains("webdav")
                && settings.contains("s3")
                && settings.contains("yandex"),
            "kinds"
        )
        expect(
            !settings.contains("defaults.set") || !settings.lowercased().contains("\"password\""),
            "no password defaults"
        )
        expect(!settings.contains("yandex.accessToken"), "token not in settings UD keys")

        exit(failures == 0 ? 0 : 1)
    }
}
