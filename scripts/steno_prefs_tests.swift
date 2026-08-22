import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoPrefsTests {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let prefs = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/PrefsStenoView.swift"),
            encoding: .utf8
        )
        expect(prefs.contains("Enable Steno") || prefs.contains("Включить Стено"), "prefs master")
        expect(!prefs.contains("recordCallVideo"), "prefs has no video toggle")
        expect(!prefs.contains("Писать видео окна звонка") && !prefs.contains("Record call window video"), "prefs copy has no video toggle")
        expect(prefs.contains("applyEnabledFromSettings"), "prefs stops detector")

        let det = try! String(
            contentsOf: root.appendingPathComponent("Sources/StenoKit/StenoDetector.swift"),
            encoding: .utf8
        )
        expect(det.contains("activeCall = nil"), "stop clears published call")

        let session = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoSessionController.swift"),
            encoding: .utf8
        )
        expect(session.contains("func applyEnabledFromSettings()"), "session applies master switch")
        expect(session.contains("StenoSettings.isEnabled"), "session checks master")

        exit(failures == 0 ? 0 : 1)
    }
}
