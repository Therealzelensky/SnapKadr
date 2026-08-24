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
        expect(prefs.contains("StenoSettings.recordShare"), "prefs share")
        expect(prefs.contains("StenoSettings.showCard"), "prefs card")
        expect(prefs.contains("Писать шару") || prefs.contains("Record screen share"), "share copy")
        expect(prefs.contains("Показывать карточку") || prefs.contains("Show floating card"), "card copy")
        expect(
            prefs.contains("Яндекс Мессенджер") || prefs.contains("Yandex Messenger"),
            "prefs yandex messenger source"
        )

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
        expect(
            session.contains("case .yandexMessenger:") && session.contains("Мессенджер"),
            "session project label for yandex messenger"
        )

        let speech = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/PrefsSpeechView.swift"),
            encoding: .utf8
        )
        expect(speech.contains("StenoSettings.namesFromCallWindow"), "speech prefs names binding")
        expect(speech.contains("StenoSettings.separateSpeakers"), "speech prefs speakers binding")
        expect(
            speech.contains("Имена из окна звонка") || speech.contains("Names from call window"),
            "names copy"
        )
        expect(
            speech.contains("Разделять голоса") || speech.contains("Separate speakers"),
            "speakers copy"
        )
        expect(!speech.contains("stenoOCR"), "no OCR toggle key")
        expect(!speech.contains("cloudLLM") && !speech.contains("Cloud LLM"), "no cloud LLM UI")
        expect(!speech.contains("recordCallVideo"), "speech prefs no call video")

        exit(failures == 0 ? 0 : 1)
    }
}
