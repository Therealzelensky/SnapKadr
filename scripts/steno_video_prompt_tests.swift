import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoVideoPromptTests {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let hud = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/SuiteNotchHUD.swift"),
            encoding: .utf8
        )
        expect(hud.contains("func showStenoVideoPrompt"), "video prompt API")
        expect(hud.contains("Записать видео окна?") || hud.contains("Record the call window?"), "video prompt copy")
        expect(hud.contains("systemSymbolName: \"video\""), "video SF Symbol")
        expect(hud.contains("onYes") && hud.contains("onNo"), "yes/no callbacks")

        exit(failures == 0 ? 0 : 1)
    }
}
