// swiftc -parse-as-library Sources/SnapKadr/StenoCloudSettings.swift \
//   Sources/SnapKadr/StenoCloudUploadQueue.swift scripts/steno_w4_queue_tests.swift -o /tmp/steno_w4_queue && /tmp/steno_w4_queue
import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoW4QueueTests {
    static func main() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("steno-w4-q-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let q = StenoCloudUploadQueue(fileURL: tmp)
        let a = URL(fileURLWithPath: "/tmp/Demo.kadr", isDirectory: true)
        expect(q.enqueue(projectURL: a, destination: .webdav), "first enqueue")
        expect(!q.enqueue(projectURL: a, destination: .webdav), "dedupe same pair")
        expect(q.enqueue(projectURL: a, destination: .s3), "same project different dest OK")
        expect(q.pendingCount() == 2, "count 2")
        expect(q.pendingCount(for: .webdav) == 1, "per-dest count")
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        q.markFailure(projectURL: a, destination: .webdav, now: now)
        let item = q.items().first { $0.destination == .webdav }!
        expect(item.attemptCount == 1, "attempt incremented")
        expect(item.nextRetryAt > now, "backoff scheduled")
        expect(q.peekEligible(now: now, destination: .webdav).isEmpty, "not eligible before backoff")
        expect(q.peekEligible(now: item.nextRetryAt, destination: .webdav).count == 1, "eligible after backoff")
        q.markSuccess(projectURL: a, destination: .webdav)
        expect(q.pendingCount(for: .webdav) == 0, "removed on success")
        let q2 = StenoCloudUploadQueue(fileURL: tmp)
        expect(q2.pendingCount(for: .s3) == 1, "persist relaunch")
        exit(failures == 0 ? 0 : 1)
    }
}
