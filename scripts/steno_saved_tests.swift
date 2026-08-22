import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoSavedTests {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let hud = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/SuiteNotchHUD.swift"),
            encoding: .utf8
        )
        expect(hud.contains("showStenoFailure"), "notch failure")
        expect(hud.contains("showStenoSaved"), "notch saved")

        let session = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoSessionController.swift"),
            encoding: .utf8
        )
        expect(session.contains("lastProjectURL"), "remembers project")
        expect(session.contains("showStenoFailure"), "routes errors to notch")
        expect(session.contains("onCaptureFinished"), "observes capture finish")
        expect(session.contains("activateFileViewerSelecting"), "reveals project in Finder after save")
        expect(session.contains("func openLastProject"), "open last project API")
        expect(!session.contains("openProject(at: url)"), "Steno open uses Finder, not Kadr editor")

        let panel = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/SuiteControlPanelView.swift"),
            encoding: .utf8
        )
        expect(panel.contains("В Finder") || panel.contains("In Finder"), "panel reveal in Finder")

        let capture = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoCapture.swift"),
            encoding: .utf8
        )
        expect(capture.contains("presentsAlerts: false"), "steno suppresses kadr alerts")

        exit(failures == 0 ? 0 : 1)
    }
}
