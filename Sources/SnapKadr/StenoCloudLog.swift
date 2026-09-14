import Foundation

/// Appends cloud upload diagnostics to `~/Library/Logs/SnapKadr.log` (same file as SnapKit).
enum StenoCloudLog {
    private static let queue = DispatchQueue(label: "com.snapkadr.cloud.log")
    private static let path: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("SnapKadr.log")
    }()

    static func log(_ message: String, file: String = #fileID, line: Int = #line) {
        // Mirror SnapKit AppSettings.allowDiagnostics default (on).
        let allowed = UserDefaults.standard.object(forKey: "allowDiagnostics") as? Bool ?? true
        guard allowed else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let lineText = "[\(stamp)] \(file):\(line) \(message)\n"
        queue.async {
            guard let data = lineText.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: path.path),
               let handle = try? FileHandle(forWritingTo: path) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: path)
            }
        }
    }
}
