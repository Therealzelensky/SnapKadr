import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoCardTests {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        expect(
            !FileManager.default.fileExists(
                atPath: root.appendingPathComponent("Sources/SnapKadr/StenoOverlayPanel.swift").path
            ),
            "floating overlay panel removed"
        )
        expect(
            !FileManager.default.fileExists(
                atPath: root.appendingPathComponent("Sources/SnapKadr/StenoCardView.swift").path
            ),
            "floating card view removed"
        )

        let hud = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/SuiteNotchHUD.swift"),
            encoding: .utf8
        )
        expect(hud.contains("shareStatusLine"), "share copy lives on live activity")
        expect(hud.contains("Шару не записали") || hud.contains("Share not recorded"), "share fail copy")
        expect(hud.contains("updateStenoRecording"), "live activity updates share line")

        let session = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoSessionController.swift"),
            encoding: .utf8
        )
        expect(session.contains("Идёт конспект") || session.contains("Noting the call"), "rec copy")

        exit(failures == 0 ? 0 : 1)
    }
}
