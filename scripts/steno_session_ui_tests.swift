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
        expect(session.contains("showStenoStopConfirm"), "stop asks for confirmation")
        expect(session.contains("requestStopConfirm"), "user stop and hangup share confirm")
        expect(session.contains("willSleepNotification"), "sleep stops session")
        expect(session.contains("hangupArmedAt"), "hangup grace after start")
        expect(session.contains("replacementWindowID"), "retarget replaced call window")
        expect(session.contains("sessionTitle"), "hangup pinned to call title")
        expect(session.contains("pinSession"), "hangup keeps the captured window")
        expect(!session.contains("StenoOverlayPanel"), "no floating card overlay")
        expect(session.contains("updateStenoRecording"), "share status goes to live activity")
        expect(session.contains("StenoShareProbe"), "session probes share")
        expect(session.contains("startAdditionalWindowRecording"), "session starts share track")
        expect(!session.contains("StenoSettings.showCard"), "no showCard pref")
        expect(session.contains("StenoSettings.recordShare"), "respects recordShare pref")
        expect(session.contains("StenoPostSessionPipeline"), "session kicks pipeline")
        expect(session.contains("showStenoPostSessionProgress"), "progress UI")
        expect(session.contains("pipelineWindowID"), "stashes window for pipeline")
        expect(!session.contains("StenoNotesEngine.makeDigest"), "FM not in session hot path")
        expect(!session.contains("StenoDiarizer"), "no diarizer in session file")

        let hud = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/SuiteNotchHUD.swift"),
            encoding: .utf8
        )
        expect(hud.contains("showStenoRecording"), "notch rec chrome")
        expect(hud.contains("func showStenoStopConfirm"), "stop confirm API")
        expect(hud.contains("Остановить конспект?") || hud.contains("Stop noting?"), "stop confirm copy")
        expect(hud.contains("Продолжить") || hud.contains("Keep going"), "stop confirm continue")
        expect(hud.contains("Остановить") || hud.contains("Stop noting the call"), "stop confirm action")
        expect(hud.contains("Похоже, звонок закончился") || hud.contains("Looks like the call ended"), "hangup confirm copy")
        expect(hud.contains("updateStenoRecording"), "live activity updates in place")
        expect(hud.contains("showStenoPostSessionProgress"), "post-session progress")
        expect(hud.contains("Не сейчас") || hud.contains("Not now"), "later copy")
        expect(hud.contains("keyEquivalent"), "escape later")
        expect(hud.contains("Шары нет") || hud.contains("No share"), "share idle copy in live activity")
        expect(hud.contains("Шара пишется") || hud.contains("Share recording"), "share active copy in live activity")
        expect(hud.contains("Шару не записали") || hud.contains("Share not recorded"), "share fail copy in live activity")

        let panel = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/SuiteControlPanelView.swift"),
            encoding: .utf8
        )
        expect(panel.contains("stopFromUser"), "panel stop")
        expect(!panel.contains("Стоп — в панели Кадра"), "no kadr hud copy")

        exit(failures == 0 ? 0 : 1)
    }
}
