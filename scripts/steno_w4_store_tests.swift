// swiftc -parse-as-library \
//   Sources/SnapKadr/ProjectCloudSettings.swift \
//   Sources/SnapKadr/ProjectCloudKeychain.swift \
//   Sources/SnapKadr/ProjectCloudUploadQueue.swift \
//   Sources/SnapKadr/ProjectCloudAdapter.swift \
//   Sources/SnapKadr/ProjectCloudStore.swift \
//   scripts/steno_w4_store_tests.swift \
//   -framework Security -o /tmp/steno_w4_store && /tmp/steno_w4_store
import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

final class FakeAdapter: ProjectCloudAdapter {
    var uploads: [URL] = []
    var failPaths: Set<String> = []
    var authFail = false

    func testConnection() async throws {}

    func uploadPackage(localProjectURL: URL) async throws {
        if authFail { throw ProjectCloudError.authRequired }
        if failPaths.contains(localProjectURL.path) {
            throw ProjectCloudError.network("down")
        }
        uploads.append(localProjectURL)
    }

    func cancel() {}
}

@main
enum StenoW4StoreTests {
    static func main() async {
        let older = URL(fileURLWithPath: "/tmp/Older.kadr", isDirectory: true)
        let newer = URL(fileURLWithPath: "/tmp/Newer.kadr", isDirectory: true)

        let savedKind = ProjectCloudSettings.remoteKind
        let savedAuto = ProjectCloudSettings.autoUploadAfterSession
        defer {
            ProjectCloudSettings.remoteKind = savedKind
            ProjectCloudSettings.autoUploadAfterSession = savedAuto
        }

        let qURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("steno-w4-store-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: qURL) }

        let q = ProjectCloudUploadQueue(fileURL: qURL)
        _ = q.enqueue(projectURL: older)
        let fake = FakeAdapter()
        let store = ProjectCloudStore(queue: q) { kind in
            kind == .webdav ? fake : nil
        }
        ProjectCloudSettings.remoteKind = .webdav
        ProjectCloudSettings.autoUploadAfterSession = true
        await store.handlePostSession(projectURL: newer)
        expect(
            fake.uploads.map(\.lastPathComponent) == ["Older.kadr", "Newer.kadr"],
            "drain then current"
        )
        expect(q.pendingCount() == 0, "queue empty after success")

        fake.uploads = []
        ProjectCloudSettings.autoUploadAfterSession = false
        await store.handlePostSession(projectURL: newer)
        expect(fake.uploads.isEmpty, "auto off no upload")

        ProjectCloudSettings.autoUploadAfterSession = true
        ProjectCloudSettings.remoteKind = .none
        await store.handlePostSession(projectURL: newer)
        expect(fake.uploads.isEmpty, "none no upload")

        let q2URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("steno-w4-store2-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: q2URL) }
        let qFail = ProjectCloudUploadQueue(fileURL: q2URL)
        _ = qFail.enqueue(projectURL: older)
        let fake2 = FakeAdapter()
        fake2.failPaths = [older.path]
        let store2 = ProjectCloudStore(queue: qFail) { _ in fake2 }
        ProjectCloudSettings.remoteKind = .webdav
        ProjectCloudSettings.autoUploadAfterSession = true
        await store2.handlePostSession(projectURL: newer)
        expect(fake2.uploads.map(\.lastPathComponent) == ["Newer.kadr"], "continue after drain fail")
        expect(qFail.pendingCount() == 1, "failed older kept")
        expect(qFail.peekAll().first?.displayName == "Older.kadr", "older still queued")

        exit(failures == 0 ? 0 : 1)
    }
}
