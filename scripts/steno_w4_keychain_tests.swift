// swiftc -parse-as-library Sources/SnapKadr/StenoCloudSettings.swift Sources/SnapKadr/StenoCloudKeychain.swift \
//   scripts/steno_w4_keychain_tests.swift -framework Security -o /tmp/steno_w4_keychain && /tmp/steno_w4_keychain
import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoW4KeychainTests {
    static func main() {
        expect(StenoCloudKeychain.accountName(destination: .webdav, field: "password") == "webdav.password", "webdav acct")
        expect(StenoCloudKeychain.accountName(destination: .s3, field: "secretAccessKey") == "s3.secretAccessKey", "s3 acct")
        expect(StenoCloudKeychain.accountName(destination: .yandex, field: "accessToken") == "yandex.accessToken", "ya access")
        expect(StenoCloudKeychain.accountName(destination: .yandex, field: "refreshToken") == "yandex.refreshToken", "ya refresh")
        exit(failures == 0 ? 0 : 1)
    }
}
