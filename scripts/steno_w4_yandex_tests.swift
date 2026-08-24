// swiftc -parse-as-library Sources/SnapKadr/StenoCloudSettings.swift Sources/SnapKadr/StenoCloudKeychain.swift \
//   Sources/SnapKadr/StenoCloudClient.swift Sources/SnapKadr/YandexOAuthSession.swift \
//   Sources/SnapKadr/YandexDiskClient.swift scripts/steno_w4_yandex_tests.swift \
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
        expect(YandexDiskPath.remoteFolder(prefix: "Kadr", project: "A.kadr") == "disk:/Kadr/A.kadr", "path form")
        expect(YandexDiskPath.join(prefix: "", project: "A.kadr") == "disk:/SnapKadr/A.kadr", "empty prefix → SnapKadr")
        expect(YandexDiskPath.appRoot == "disk:/SnapKadr", "app root")
        expect(YandexDiskPath.filePath(prefix: "Kadr", project: "A.kadr", relative: "steno.json") == "disk:/Kadr/A.kadr/steno.json", "file path")
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let settings = try! String(contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoCloudSettings.swift"), encoding: .utf8)
        expect(!settings.contains("yandex.accessToken"), "token not in UD")
        expect(settings.contains("SnapKadr"), "default folder name in settings")
        let client = try! String(contentsOf: root.appendingPathComponent("Sources/SnapKadr/YandexDiskClient.swift"), encoding: .utf8)
        expect(client.contains("ensureAppRootFolder"), "ensure app folder API")
        let oauth = try! String(contentsOf: root.appendingPathComponent("Sources/SnapKadr/YandexOAuthSession.swift"), encoding: .utf8)
        expect(oauth.contains("ensureAppRootFolder"), "connect creates folder")
        expect(oauth.contains("verification_code"), "oauth flow")
        expect(oauth.contains("YandexDiskOAuthClientID"), "client id plist key")
        expect(oauth.contains("StenoCloudSettings.yandexOAuthClientID"), "prefs client id override")
        expect(oauth.contains("missingYandexClientID"), "missing client id error")
        expect(oauth.contains("isUsableClientID"), "rejects placeholder id")
        expect(oauth.contains("exchangeAuthorizationCode"), "code exchange")
        expect(oauth.contains("oauth.yandex.ru/verification_code"), "verification redirect")
        expect(oauth.contains("response_type") && oauth.contains("token"), "implicit token on verification page")
        expect(oauth.contains("extractAccessToken"), "paste URL/token parse")
        exit(failures == 0 ? 0 : 1)
    }
}
