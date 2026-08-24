// swiftc -parse-as-library \
//   Sources/SnapKadr/StenoCloudSettings.swift \
//   Sources/SnapKadr/StenoCloudKeychain.swift \
//   Sources/SnapKadr/StenoCloudClient.swift \
//   Sources/SnapKadr/StenoCloudUploadQueue.swift \
//   Sources/SnapKadr/WebDAVClient.swift \
//   Sources/SnapKadr/S3CompatibleClient.swift \
//   Sources/SnapKadr/YandexOAuthSession.swift \
//   Sources/SnapKadr/YandexDiskClient.swift \
//   Sources/SnapKadr/StenoCloudSync.swift \
//   scripts/steno_w4_sync_tests.swift \
//   -framework Security -framework AuthenticationServices -framework AppKit \
//   -o /tmp/steno_w4_sync && /tmp/steno_w4_sync
import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

final class FakeClient: StenoCloudClient {
    let destination: StenoCloudDestination
    var uploads: [URL] = []
    var fail = false
    var authFail = false

    init(_ d: StenoCloudDestination) { destination = d }

    func testConnection() async throws {}

    func uploadPackage(localProjectURL: URL) async throws {
        if authFail { throw StenoCloudError.authRequired }
        if fail { throw StenoCloudError.network("down") }
        uploads.append(localProjectURL)
    }

    func cancel() {}
}

@main
enum StenoW4SyncTests {
    static func main() async {
        let older = URL(fileURLWithPath: "/tmp/Older.kadr", isDirectory: true)
        let newer = URL(fileURLWithPath: "/tmp/Newer.kadr", isDirectory: true)

        let savedWebdav = StenoCloudSettings.webdavEnabled
        let savedS3 = StenoCloudSettings.s3Enabled
        let savedAuto = StenoCloudSettings.autoUploadAfterSession
        defer {
            StenoCloudSettings.webdavEnabled = savedWebdav
            StenoCloudSettings.s3Enabled = savedS3
            StenoCloudSettings.autoUploadAfterSession = savedAuto
        }

        let qURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("steno-w4-sync-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: qURL) }

        let q = StenoCloudUploadQueue(fileURL: qURL)
        _ = q.enqueue(projectURL: older, destination: .webdav)

        let webdavClient = FakeClient(.webdav)
        let s3Client = FakeClient(.s3)
        let sync = StenoCloudSync(queue: q) { dest in
            switch dest {
            case .webdav: return webdavClient
            case .s3: return s3Client
            case .yandex: return nil
            }
        }

        StenoCloudSettings.webdavEnabled = true
        StenoCloudSettings.s3Enabled = true
        StenoCloudSettings.autoUploadAfterSession = true
        await sync.handlePostSession(projectURL: newer)

        expect(
            webdavClient.uploads.map(\.lastPathComponent) == ["Older.kadr", "Newer.kadr"],
            "drain then current per dest"
        )
        expect(s3Client.uploads == [newer], "s3 only current")

        webdavClient.fail = true
        s3Client.fail = false
        s3Client.uploads = []
        await sync.handlePostSession(projectURL: newer)
        expect(s3Client.uploads.count >= 1, "s3 succeeds when webdav fails")

        let autoOffWebdav = webdavClient.uploads.count
        let autoOffS3 = s3Client.uploads.count
        StenoCloudSettings.autoUploadAfterSession = false
        await sync.handlePostSession(projectURL: newer)
        expect(webdavClient.uploads.count == autoOffWebdav, "auto off webdav")
        expect(s3Client.uploads.count == autoOffS3, "auto off s3")

        exit(failures == 0 ? 0 : 1)
    }
}
