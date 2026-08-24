import Foundation

public struct StenoCloudQueueItem: Codable, Equatable, Sendable {
    public var projectPath: String
    public var destination: StenoCloudDestination
    public var enqueuedAt: Date
    public var nextRetryAt: Date
    public var attemptCount: Int
    public var displayName: String

    public var identity: String { "\(destination.rawValue)|\(projectPath)" }

    public init(
        projectPath: String,
        destination: StenoCloudDestination,
        enqueuedAt: Date,
        nextRetryAt: Date,
        attemptCount: Int,
        displayName: String
    ) {
        self.projectPath = projectPath
        self.destination = destination
        self.enqueuedAt = enqueuedAt
        self.nextRetryAt = nextRetryAt
        self.attemptCount = attemptCount
        self.displayName = displayName
    }
}

public extension Notification.Name {
    static let stenoCloudQueueDidChange = Notification.Name("StenoCloudQueueDidChange")
}

public final class StenoCloudUploadQueue: @unchecked Sendable {
    public static let shared = StenoCloudUploadQueue()

    private static let backoffIntervals: [TimeInterval] = [60, 300, 900, 3600]

    private let fileURL: URL
    private let lock = NSLock()
    private var cached: [StenoCloudQueueItem]

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = support.appendingPathComponent("SnapKadr", isDirectory: true)
            self.fileURL = dir.appendingPathComponent("steno-cloud-queue.json")
        }
        self.cached = Self.load(from: self.fileURL)
    }

    public func items() -> [StenoCloudQueueItem] {
        lock.lock()
        defer { lock.unlock() }
        return cached
    }

    public func pendingCount() -> Int {
        items().count
    }

    public func pendingCount(for destination: StenoCloudDestination) -> Int {
        items().filter { $0.destination == destination }.count
    }

    @discardableResult
    public func enqueue(projectURL: URL, destination: StenoCloudDestination) -> Bool {
        let path = projectURL.standardizedFileURL.path
        lock.lock()
        defer { lock.unlock() }
        if cached.contains(where: { $0.projectPath == path && $0.destination == destination }) {
            return false
        }
        let now = Date()
        let item = StenoCloudQueueItem(
            projectPath: path,
            destination: destination,
            enqueuedAt: now,
            nextRetryAt: now,
            attemptCount: 0,
            displayName: projectURL.lastPathComponent
        )
        cached.append(item)
        persistLocked()
        notifyChanged()
        return true
    }

    public func remove(projectURL: URL, destination: StenoCloudDestination) {
        let path = projectURL.standardizedFileURL.path
        lock.lock()
        defer { lock.unlock() }
        let before = cached.count
        cached.removeAll { $0.projectPath == path && $0.destination == destination }
        guard cached.count != before else { return }
        persistLocked()
        notifyChanged()
    }

    public func removeAll(for destination: StenoCloudDestination) {
        lock.lock()
        defer { lock.unlock() }
        let before = cached.count
        cached.removeAll { $0.destination == destination }
        guard cached.count != before else { return }
        persistLocked()
        notifyChanged()
    }

    public func peekEligible(now: Date = Date(), destination: StenoCloudDestination? = nil) -> [StenoCloudQueueItem] {
        lock.lock()
        defer { lock.unlock() }
        return cached
            .filter { item in
                if let destination, item.destination != destination { return false }
                return item.nextRetryAt <= now
            }
            .sorted { $0.enqueuedAt < $1.enqueuedAt }
    }

    public func markFailure(
        projectURL: URL,
        destination: StenoCloudDestination,
        now: Date = Date()
    ) {
        let path = projectURL.standardizedFileURL.path
        lock.lock()
        defer { lock.unlock() }
        guard let index = cached.firstIndex(where: {
            $0.projectPath == path && $0.destination == destination
        }) else { return }
        cached[index].attemptCount += 1
        let intervalIndex = min(cached[index].attemptCount - 1, Self.backoffIntervals.count - 1)
        cached[index].nextRetryAt = now.addingTimeInterval(Self.backoffIntervals[intervalIndex])
        persistLocked()
        notifyChanged()
    }

    public func markSuccess(projectURL: URL, destination: StenoCloudDestination) {
        remove(projectURL: projectURL, destination: destination)
    }

    public func resetBackoff(projectURL: URL, destination: StenoCloudDestination) {
        let path = projectURL.standardizedFileURL.path
        lock.lock()
        defer { lock.unlock() }
        guard let index = cached.firstIndex(where: {
            $0.projectPath == path && $0.destination == destination
        }) else { return }
        cached[index].attemptCount = 0
        cached[index].nextRetryAt = Date()
        persistLocked()
        notifyChanged()
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
            NotificationCenter.default.post(name: .stenoCloudQueueDidChange, object: nil)
        }
    }

    private static func load(from url: URL) -> [StenoCloudQueueItem] {
        guard let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([StenoCloudQueueItem].self, from: data)
        else { return [] }
        return items
    }
}
