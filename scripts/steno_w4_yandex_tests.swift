// swiftc -parse-as-library \
//   Sources/SnapKadr/ProjectCloudSettings.swift \
//   Sources/SnapKadr/ProjectCloudKeychain.swift \
//   Sources/SnapKadr/ProjectCloudAdapter.swift \
//   Sources/SnapKadr/YandexOAuthClient.swift \
//   Sources/SnapKadr/YandexDiskCloudAdapter.swift \
//   scripts/steno_w4_yandex_tests.swift \
//   -framework Security -framework AuthenticationServices -framework AppKit \
//   -o /tmp/steno_w4_yandex && /tmp/steno_w4_yandex
import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoW4YandexTests {
    static func main() {
        expect(
            YandexDiskPath.join(prefix: "Kadr", project: "A.kadr") == "disk:/Kadr/A.kadr",
            "path"
        )
        expect(
            YandexDiskPath.join(prefix: "", project: "A.kadr") == "disk:/A.kadr",
            "path no prefix"
        )
        expect(
            YandexDiskPath.filePath(prefix: "Kadr", project: "A.kadr", relative: "steno.json")
                == "disk:/Kadr/A.kadr/steno.json",
            "file path"
        )

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let settingsSrc = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/ProjectCloudSettings.swift"),
            encoding: .utf8
        )
        expect(!settingsSrc.contains("yandex.accessToken"), "token not in settings UD keys as stored value field")

        let oauth = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/YandexOAuthClient.swift"),
            encoding: .utf8
        )
        expect(
            oauth.contains("ASWebAuthenticationSession") || oauth.contains("AuthenticationServices"),
            "oauth session"
        )
        expect(oauth.contains("refreshToken") || oauth.contains("yandex.refreshToken"), "refresh")
        expect(oauth.contains("YandexDiskOAuthClientID"), "client id plist key")

        exit(failures == 0 ? 0 : 1)
    }
}
