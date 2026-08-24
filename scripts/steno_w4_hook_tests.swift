// swiftc -parse-as-library scripts/steno_w4_hook_tests.swift -o /tmp/steno_w4_hook && /tmp/steno_w4_hook
import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoW4HookTests {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let session = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/StenoSessionController.swift"),
            encoding: .utf8
        )
        expect(session.contains("ProjectCloudStore"), "cloud store hook")
        expect(session.contains("handlePostSession"), "post session upload")
        expect(session.contains("StenoPostSessionPipeline"), "still runs W3 first")
        let runIdx = session.range(of: "pipeline.run")!.lowerBound
        let upIdx = session.range(of: "handlePostSession")!.lowerBound
        expect(runIdx < upIdx, "upload after pipeline")

        let app = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/AppDelegate.swift"),
            encoding: .utf8
        )
        expect(app.contains("retryPendingOnLaunch"), "launch retry")

        let storeSrc = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/ProjectCloudStore.swift"),
            encoding: .utf8
        )
        expect(!storeSrc.lowercased().contains("bitrix"), "store has no bitrix")

        let adapters = ["WebDAVCloudAdapter.swift", "S3CloudAdapter.swift", "YandexDiskCloudAdapter.swift"]
        for name in adapters {
            let src = try! String(
                contentsOf: root.appendingPathComponent("Sources/SnapKadr/\(name)"),
                encoding: .utf8
            )
            expect(!src.lowercased().contains("bitrix"), "\(name) no bitrix")
        }

        let hud = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/SuiteNotchHUD.swift"),
            encoding: .utf8
        )
        expect(hud.contains("загрузить позже") || hud.contains("showCloudUploadDeferred"), "deferred toast")
        expect(hud.contains("presentDeferredUploadToast") || hud.contains("showCloudUploadDeferred"), "store toasts")
        expect(hud.contains("authRequired") || hud.contains("presentAuthRequired") || hud.contains("showCloudAuthRequired"), "auth path")

        let store = try! String(
            contentsOf: root.appendingPathComponent("Sources/SnapKadr/ProjectCloudStore.swift"),
            encoding: .utf8
        )
        expect(store.contains("presentDeferredUploadToast") || store.contains("showCloudUploadDeferred"), "store toasts")
        expect(store.contains("authRequired") || store.contains("presentAuthRequired"), "auth path")

        exit(failures == 0 ? 0 : 1)
    }
}
