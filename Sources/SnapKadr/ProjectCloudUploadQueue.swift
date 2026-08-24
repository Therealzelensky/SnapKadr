import Foundation

public struct ProjectCloudQueueItem: Codable, Equatable, Sendable {
    public var projectPath: String
    public var enqueuedAt: Date
    public var displayName: String

    public init(projectPath: String, enqueuedAt: Date, displayName: String) {
        self.projectPath = projectPath
        self.enqueuedAt = enqueuedAt
        self.displayName = displayName
    }
}

public final class ProjectCloudUploadQueue: @unchecked Sendable {
    public static let shared = ProjectCloudUploadQueue()

    public static let didChangeNotification = Notification.Name("ProjectCloudQueueDidChange")

    private let fileURL: URL
    private let lock = NSLock()
    private var cached: [ProjectCloudQueueItem]

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = support.appendingPathComponent("SnapKadr", isDirectory: true)
            self.fileURL = dir.appendingPathComponent("cloud-upload-queue.json")
        }
        self.cached = Self.load(from: self.fileURL)
    }

    public func items() -> [ProjectCloudQueueItem] {
        lock.lock()
        defer { lock.unlock() }
        return cached
    }

    public func pendingCount() -> Int {
        items().count
    }

    @discardableResult
    public func enqueue(projectURL: URL) -> Bool {
        let path = projectURL.standardizedFileURL.path
        lock.lock()
        defer { lock.unlock() }
        if cached.contains(where: { $0.projectPath == path }) {
            return false
        }
        let item = ProjectCloudQueueItem(
            projectPath: path,
            enqueuedAt: Date(),
            displayName: projectURL.lastPathComponent
        )
        cached.append(item)
        persistLocked()
        notifyChanged()
        return true
    }

    public func remove(projectURL: URL) {
        let path = projectURL.standardizedFileURL.path
        lock.lock()
        defer { lock.unlock() }
        let before = cached.count
        cached.removeAll { $0.projectPath == path }
        guard cached.count != before else { return }
        persistLocked()
        notifyChanged()
    }

    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        guard !cached.isEmpty else { return }
        cached = []
        persistLocked()
        notifyChanged()
    }

    public func peekAll() -> [ProjectCloudQueueItem] {
        items()
    }

    private func persistLocked() {
        do {
            let parent = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(cached)
            let tmp = fileURL.appendingPathExtension("tmp")
            try data.write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: fileURL)
            }
        } catch {
            // Best-effort durable queue; keep in-memory state.
        }
    }

    private func notifyChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    private static func load(from url: URL) -> [ProjectCloudQueueItem] {
        guard let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([ProjectCloudQueueItem].self, from: data)
        else { return [] }
        return items
    }
}
