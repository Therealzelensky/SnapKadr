import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoW4HookTests {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let session = try! String(contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoSessionController.swift"), encoding: .utf8)
        expect(session.contains("StenoCloudSync"), "cloud hook")
        expect(session.contains("handlePostSession"), "post session upload")
        expect(session.contains("StenoPostSessionPipeline"), "W3 still runs")
        let runRange = session.range(of: "pipeline.run") ?? session.range(of: "StenoPostSessionPipeline")!
        let upRange = session.range(of: "handlePostSession")!
        expect(runRange.lowerBound < upRange.lowerBound, "upload after pipeline")
        let app = try! String(contentsOf: root.appendingPathComponent("Sources/SnapKadr/AppDelegate.swift"), encoding: .utf8)
        expect(app.contains("retryPendingOnLaunch"), "launch retry")
        for name in ["WebDAVClient.swift", "S3CompatibleClient.swift", "YandexDiskClient.swift"] {
            let src = try! String(contentsOf: root.appendingPathComponent("Sources/SnapKadr/\(name)"), encoding: .utf8)
            expect(!src.lowercased().contains("bitrix"), "\(name) no bitrix")
        }
        let hud = try! String(contentsOf: root.appendingPathComponent("Sources/SnapKadr/SuiteNotchHUD.swift"), encoding: .utf8)
        expect(hud.contains("загрузить позже") || hud.contains("showCloudUploadDeferred"), "deferred toast")
        let sync = try! String(contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoCloudSync.swift"), encoding: .utf8)
        expect(sync.contains("presentDeferredUploadToast") || sync.contains("presentDeferred"), "store toasts")
        expect(sync.contains("authRequired"), "auth path")
        exit(failures == 0 ? 0 : 1)
    }
}
