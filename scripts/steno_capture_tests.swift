import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoCaptureTests {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let capture = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoCapture.swift"),
            encoding: .utf8
        )
        expect(!capture.contains("fps:"), "Steno does not drop capture fps")
        expect(!capture.contains("maxLongEdge:"), "Steno does not shrink capture resolution")
        expect(capture.contains("recordsInputEvents: false"), "Steno skips cursor tap from SnapKadr")
        expect(capture.contains("presentsEditor: false"), "Steno does not open Kadr editor")

        let session = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoSessionController.swift"),
            encoding: .utf8
        )
        expect(session.contains("StenoCapture.windowRecord"), "session starts capture with SnapKadr light profile")
        expect(!session.contains("captureBudgetOverride = .steno"), "session does not set Kadr steno budget")

        exit(failures == 0 ? 0 : 1)
    }
}
