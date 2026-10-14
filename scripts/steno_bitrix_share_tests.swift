import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoBitrixShareTests {
    static func main() {
        expect(
            StenoBitrixCallState.isSharing(axLabels: [
                "Микрофон", "Экран", "Завершить", "BitrixGPT Follow-Up"
            ]) == false,
            "bitrix call chrome without share is not a share"
        )
        expect(
            StenoBitrixCallState.isSharing(axLabels: [
                "Микрофон", "Экран", "Закрепить", "Завершить"
            ]),
            "bitrix in-window share exposes Закрепить"
        )
        expect(
            StenoBitrixCallState.isSharing(axLabels: [
                "Остановить демонстрацию", "Вы демонстрируете экран"
            ]),
            "bitrix local share stop control"
        )
        print("=== bitrix share: \(failures) failed ===")
        exit(failures == 0 ? 0 : 1)
    }
}
