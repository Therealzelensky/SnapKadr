// swiftc -parse-as-library Sources/SnapKadr/StenoCloudSettings.swift Sources/SnapKadr/StenoCloudClient.swift \
//   Sources/SnapKadr/WebDAVClient.swift scripts/steno_w4_webdav_tests.swift -o /tmp/steno_w4_webdav && /tmp/steno_w4_webdav
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
        expect(
            WebDAVPath.connectionProbeURL(base: base, prefix: "Kadr") == base,
            "test connection probes base, not missing prefix"
        )

        let fm = FileManager.default
        let pkg = fm.temporaryDirectory.appendingPathComponent("QA-W4-rel.kadr", isDirectory: true)
        try? fm.removeItem(at: pkg)
        try! fm.createDirectory(at: pkg, withIntermediateDirectories: true)
        let file = pkg.appendingPathComponent("steno-digest.json")
        try! "x".write(to: file, atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(at: pkg) }
        let nested = try! fm.contentsOfDirectory(
            at: pkg,
            includingPropertiesForKeys: nil
        ).first { $0.lastPathComponent == "steno-digest.json" }!
        expect(
            StenoCloudPackage.relativePath(of: nested, inside: pkg) == "steno-digest.json",
            "relative path survives /var → /private/var"
        )
        exit(failures == 0 ? 0 : 1)
    }
}
