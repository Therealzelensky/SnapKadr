// swiftc -parse-as-library \
//   Sources/SnapKadr/ProjectCloudUploadQueue.swift \
//   scripts/steno_w4_queue_tests.swift \
//   -o /tmp/steno_w4_queue && /tmp/steno_w4_queue
import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoW4QueueTests {
    static func main() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("steno-w4-q-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let q = ProjectCloudUploadQueue(fileURL: tmp)
        let a = URL(fileURLWithPath: "/tmp/Demo.kadr", isDirectory: true)
        let b = URL(fileURLWithPath: "/tmp/Other.kadr", isDirectory: true)
        expect(q.enqueue(projectURL: a), "first enqueue")
        expect(!q.enqueue(projectURL: a), "dedupe")
        expect(q.pendingCount() == 1, "count 1")
        _ = q.enqueue(projectURL: b)
        expect(q.peekAll().map(\.displayName) == ["Demo.kadr", "Other.kadr"], "order")
        q.remove(projectURL: a)
        expect(q.pendingCount() == 1, "after remove")

        let q2 = ProjectCloudUploadQueue(fileURL: tmp)
        expect(q2.pendingCount() == 1, "persist")
        expect(q2.peekAll().first?.projectPath.hasSuffix("Other.kadr") == true, "path")

        exit(failures == 0 ? 0 : 1)
    }
}
