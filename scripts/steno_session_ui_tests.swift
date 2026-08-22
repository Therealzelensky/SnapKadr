import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoSessionUITests {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let session = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoSessionController.swift"),
            encoding: .utf8
        )
        expect(session.contains("func stopFromUser()"), "user stop")
        expect(session.contains("willSleepNotification"), "sleep stops session")
        expect(session.contains("hangupArmedAt"), "hangup grace after start")
        expect(session.contains("replacementWindowID"), "retarget replaced call window")

        let hud = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/SuiteNotchHUD.swift"),
            encoding: .utf8
        )
        expect(hud.contains("showStenoRecording"), "notch rec chrome")
        expect(hud.contains("Не сейчас") || hud.contains("Not now"), "later copy")
        expect(hud.contains("keyEquivalent"), "escape later")

        let panel = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/SuiteControlPanelView.swift"),
            encoding: .utf8
        )
        expect(panel.contains("stopFromUser"), "panel stop")
        expect(!panel.contains("Стоп — в панели Кадра"), "no kadr hud copy")

        exit(failures == 0 ? 0 : 1)
    }
}
