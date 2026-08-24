// swiftc -parse-as-library \
//   Sources/SnapKadr/WebDAVCloudAdapter.swift \
//   scripts/steno_w4_webdav_tests.swift \
//   -o /tmp/steno_w4_webdav && /tmp/steno_w4_webdav
import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoW4WebDAVTests {
    static func main() {
        let base = URL(string: "https://nas.example/remote.php/dav/files/user/")!
        let u = WebDAVPath.join(base, prefix: "Kadr", components: "Demo.kadr")
        expect(u.absoluteString.contains("Kadr"), "prefix")
        expect(u.lastPathComponent == "Demo.kadr", "name")
        expect(WebDAVPath.tempName(forFinal: "Demo.kadr") == "Demo.kadr.uploading", "temp")
        exit(failures == 0 ? 0 : 1)
    }
}
