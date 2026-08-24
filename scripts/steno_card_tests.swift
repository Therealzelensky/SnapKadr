import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoCardTests {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let card = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoCardView.swift"),
            encoding: .utf8
        )
        expect(card.contains("struct StenoCardModel"), "card model")
        expect(card.contains("struct StenoCardView"), "card view")
        expect(card.contains("isRecording"), "rec flag")
        expect(card.contains("shareActive"), "share flag")
        expect(card.contains("shareFailed"), "share failed")
        expect(card.contains("onStop"), "stop callback")
        expect(card.contains("Идёт конспект") || card.contains("Noting the call"), "rec copy")
        expect(card.contains("Шару не записали") || card.contains("Share not recorded"), "share fail copy")

        let panel = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoOverlayPanel.swift"),
            encoding: .utf8
        )
        expect(panel.contains("final class StenoOverlayPanel"), "overlay panel")
        expect(panel.contains("func show("), "show")
        expect(panel.contains("func update("), "update")
        expect(panel.contains("func reposition("), "reposition")
        expect(panel.contains("func hide()"), "hide")
        expect(panel.contains("sharingType = .none"), "private from framebuffer")
        expect(panel.contains("anchorWindowID"), "anchor window")

        exit(failures == 0 ? 0 : 1)
    }
}
