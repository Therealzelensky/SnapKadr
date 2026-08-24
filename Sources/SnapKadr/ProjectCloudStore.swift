import Foundation

/// Facade: drain queue → upload via active adapter.
public final class ProjectCloudStore: @unchecked Sendable {
    public static let shared = ProjectCloudStore()

    public weak var presenter: ProjectCloudStorePresenting?
    public var queue: ProjectCloudUploadQueue
    /// Inject for tests. Default returns nil until real adapters are wired.
    public var adapterFactory: (ProjectCloudRemoteKind) -> ProjectCloudAdapter?

    private let gate = DrainGate()

    public init(
        queue: ProjectCloudUploadQueue = .shared,
        adapterFactory: ((ProjectCloudRemoteKind) -> ProjectCloudAdapter?)? = nil
    ) {
        self.queue = queue
        self.adapterFactory = adapterFactory ?? Self.defaultAdapterFactory
    }

    /// Post-session entry: if kind!=none && auto ON → drain queue then upload current.
    public func handlePostSession(projectURL: URL) async {
        let kind = ProjectCloudSettings.remoteKind
        guard kind != .none else { return }
        guard ProjectCloudSettings.autoUploadAfterSession else { return }
        await drainThenUpload(current: projectURL)
    }

    /// Manual flush / «Загрузить сейчас».
    public func flushQueue() async {
        guard ProjectCloudSettings.remoteKind != .none else { return }
        await drainThenUpload(current: nil)
    }

    /// App launch retry.
    public func retryPendingOnLaunch() async {
        guard ProjectCloudSettings.remoteKind != .none else { return }
        guard queue.pendingCount() > 0 else { return }
        await drainThenUpload(current: nil)
    }

    public func testActiveConnection() async throws {
        let kind = ProjectCloudSettings.remoteKind
        guard kind != .none else { throw ProjectCloudError.noRemoteConfigured }
        guard let adapter = adapterFactory(kind) else {
            throw ProjectCloudError.network("adapter missing")
        }
        try await adapter.testConnection()
    }

    public func pendingCount() -> Int {
        queue.pendingCount()
    }

    // MARK: - Drain-first

    private func drainThenUpload(current: URL?) async {
        guard await gate.begin() else { return }

        let kind = ProjectCloudSettings.remoteKind
        guard kind != .none else {
            await gate.end()
            return
        }

        guard let adapter = adapterFactory(kind) else {
            if let current {
                _ = queue.enqueue(projectURL: current)
            }
            await presentDeferred()
            await gate.end()
            return
        }

        var sawDeferred = false
        var stoppedForAuth = false

        for item in queue.peekAll() {
            if stoppedForAuth { break }
            let url = URL(fileURLWithPath: item.projectPath, isDirectory: true)
            do {
                try await adapter.uploadPackage(localProjectURL: url)
                queue.remove(projectURL: url)
            } catch let error as ProjectCloudError {
                if case .authRequired = error {
                    stoppedForAuth = true
                    await presentAuth()
                    break
                }
                sawDeferred = true
            } catch {
                sawDeferred = true
            }
        }

        if let current, !stoppedForAuth {
            do {
                try await adapter.uploadPackage(localProjectURL: current)
                queue.remove(projectURL: current)
            } catch let error as ProjectCloudError {
                if case .authRequired = error {
                    _ = queue.enqueue(projectURL: current)
                    await presentAuth()
                    await gate.end()
                    return
                }
                _ = queue.enqueue(projectURL: current)
                sawDeferred = true
            } catch {
                _ = queue.enqueue(projectURL: current)
                sawDeferred = true
            }
        }

        if sawDeferred {
            await presentDeferred()
        }
        await gate.end()
    }

    private func presentDeferred() async {
        await MainActor.run {
            presenter?.presentDeferredUploadToast()
        }
    }

    private func presentAuth() async {
        await MainActor.run {
            presenter?.presentAuthRequiredToast()
        }
    }

    /// Default factory — real adapters registered as they land (Tasks 4–6).
    public static func defaultAdapterFactory(_ kind: ProjectCloudRemoteKind) -> ProjectCloudAdapter? {
        switch kind {
        case .none:
            return nil
        case .webdav:
            return makeWebDAVAdapter()
        case .s3:
            return makeS3Adapter()
        case .yandex:
            return makeYandexAdapter()
        }
    }

    // Soft stubs until adapters exist; return nil so missing adapter → enqueue.
    private static func makeWebDAVAdapter() -> ProjectCloudAdapter? {
        // Wired in Task 4
        nil
    }

    private static func makeS3Adapter() -> ProjectCloudAdapter? {
        // Wired in Task 5
        nil
    }

    private static func makeYandexAdapter() -> ProjectCloudAdapter? {
        // Wired in Task 6
        nil
    }
}

private actor DrainGate {
    private var busy = false

    func begin() -> Bool {
        if busy { return false }
        busy = true
        return true
    }

    func end() {
        busy = false
    }
}
