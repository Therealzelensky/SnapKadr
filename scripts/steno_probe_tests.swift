import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoProbeTests {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let probe = try! String(
            contentsOf: root.appendingPathComponent("Sources/StenoKit/StenoWindowProbe.swift"),
            encoding: .utf8
        )
        expect(probe.contains("matchingPIDs"), "pid filter")

        let det = try! String(
            contentsOf: root.appendingPathComponent("Sources/StenoKit/StenoDetector.swift"),
            encoding: .utf8
        )
        expect(
            det.contains("runningApplications") || det.contains("matchingPIDs"),
            "detector restricts probe"
        )

        exit(failures == 0 ? 0 : 1)
    }
}
