import Foundation

/// Orchestrator: parallel per-destination upload, drain-first queue, backoff retry.
public final class StenoCloudSync: @unchecked Sendable {
    public static let shared = StenoCloudSync()

    public weak var presenter: StenoCloudPresenting?
    public var queue: StenoCloudUploadQueue
    public var clientFactory: (StenoCloudDestination) -> StenoCloudClient?

    private let gate = DrainGate()

    public init(
        queue: StenoCloudUploadQueue = .shared,
        clientFactory: ((StenoCloudDestination) -> StenoCloudClient?)? = nil
    ) {
        self.queue = queue
        self.clientFactory = clientFactory ?? Self.defaultClientFactory
    }

    /// Drain eligible queue per enabled destination, then upload current project in parallel.
    public func handlePostSession(projectURL: URL) async {
        guard StenoCloudSettings.autoUploadAfterSession else { return }
        let destinations = StenoCloudSettings.enabledDestinations()
        guard !destinations.isEmpty else { return }
        guard gate.begin() else { return }

        await withTaskGroup(of: Void.self) { group in
            for destination in destinations {
                group.addTask {
                    await self.processDestination(destination, current: projectURL, drainFirst: true)
                }
            }
        }
        gate.end()
    }

    /// «Загрузить сейчас» — reset backoff and attempt all pending pairs.
    public func flushQueue() async {
        guard gate.begin() else { return }
        defer { gate.end() }

        for item in queue.items() {
            let url = URL(fileURLWithPath: item.projectPath, isDirectory: true)
            queue.resetBackoff(projectURL: url, destination: item.destination)
        }

        let destinations = Array(Set(queue.items().map(\.destination)))
        await withTaskGroup(of: Void.self) { group in
            for destination in destinations {
                group.addTask {
                    await self.processDestination(destination, current: nil, drainFirst: true)
                }
            }
        }
    }

    /// App launch — process eligible pending only.
    public func retryPendingOnLaunch() async {
        guard gate.begin() else { return }
        defer { gate.end() }

        let destinations = Array(Set(queue.peekEligible().map(\.destination)))
        guard !destinations.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for destination in destinations where StenoCloudSettings.isEnabled(destination) {
                group.addTask {
                    await self.processDestination(destination, current: nil, drainFirst: true)
                }
            }
        }
    }

    public func testConnection(for destination: StenoCloudDestination) async throws {
        guard StenoCloudSettings.isEnabled(destination) else {
            throw StenoCloudError.destinationDisabled
        }
        guard let client = resolveClient(for: destination) else {
            throw StenoCloudError.network("client missing")
        }
        try await client.testConnection()
    }

    public func retry(projectURL: URL, destination: StenoCloudDestination) async {
        queue.resetBackoff(projectURL: projectURL, destination: destination)
        guard gate.begin() else { return }
        defer { gate.end() }
        await processDestination(destination, current: projectURL, drainFirst: false)
    }

    public func pendingCount() -> Int {
        queue.pendingCount()
    }

    public func pendingSummary() -> [(destination: StenoCloudDestination, count: Int)] {
        StenoCloudDestination.allCases.compactMap { destination in
            let count = queue.pendingCount(for: destination)
            return count > 0 ? (destination, count) : nil
        }
    }

    // MARK: - Per-destination drain + upload

    private func processDestination(
        _ destination: StenoCloudDestination,
        current: URL?,
        drainFirst: Bool
    ) async {
        guard StenoCloudSettings.isEnabled(destination) else { return }

        guard let client = resolveClient(for: destination) else {
            if let current {
                _ = queue.enqueue(projectURL: current, destination: destination)
                queue.markFailure(projectURL: current, destination: destination)
            }
            await presentDeferred(for: destination)
            return
        }

        var sawDeferred = false
        var stoppedForAuth = false

        if drainFirst {
            let eligible = queue.peekEligible().filter { $0.destination == destination }
            for item in eligible {
                if stoppedForAuth { break }
                let url = URL(fileURLWithPath: item.projectPath, isDirectory: true)
                do {
                    StenoCloudLog.log("Cloud drain \(destination.rawValue) \(url.lastPathComponent)")
                    try await client.uploadPackage(localProjectURL: url)
                    queue.markSuccess(projectURL: url, destination: destination)
                    StenoCloudLog.log("Cloud OK \(destination.rawValue) \(url.lastPathComponent)")
                } catch let error as StenoCloudError {
                    StenoCloudLog.log("Cloud fail \(destination.rawValue) \(url.lastPathComponent): \(error)")
                    switch error {
                    case .authRequired:
                        stoppedForAuth = true
                        await presentAuth(for: destination)
                    case .cancelled:
                        break
                    default:
                        queue.markFailure(projectURL: url, destination: destination)
                        sawDeferred = true
                    }
                } catch {
                    StenoCloudLog.log("Cloud fail \(destination.rawValue) \(url.lastPathComponent): \(error)")
                    queue.markFailure(projectURL: url, destination: destination)
                    sawDeferred = true
                }
            }
        }

        if let current, !stoppedForAuth {
            do {
                StenoCloudLog.log("Cloud upload \(destination.rawValue) \(current.lastPathComponent)")
                try await client.uploadPackage(localProjectURL: current)
                queue.markSuccess(projectURL: current, destination: destination)
                StenoCloudLog.log("Cloud OK \(destination.rawValue) \(current.lastPathComponent)")
            } catch let error as StenoCloudError {
                StenoCloudLog.log("Cloud fail \(destination.rawValue) \(current.lastPathComponent): \(error)")
                switch error {
                case .authRequired:
                    _ = queue.enqueue(projectURL: current, destination: destination)
                    await presentAuth(for: destination)
                case .cancelled:
                    break
                default:
                    _ = queue.enqueue(projectURL: current, destination: destination)
                    queue.markFailure(projectURL: current, destination: destination)
                    sawDeferred = true
                }
            } catch {
                StenoCloudLog.log("Cloud fail \(destination.rawValue) \(current.lastPathComponent): \(error)")
                _ = queue.enqueue(projectURL: current, destination: destination)
                queue.markFailure(projectURL: current, destination: destination)
                sawDeferred = true
            }
        }

        if sawDeferred {
            await presentDeferred(for: destination)
        }
    }

    private func resolveClient(for destination: StenoCloudDestination) -> StenoCloudClient? {
        clientFactory(destination)
    }

    private func presentDeferred(for destination: StenoCloudDestination) async {
        await MainActor.run {
            presenter?.presentDeferredUploadToast(for: destination)
        }
    }

    private func presentAuth(for destination: StenoCloudDestination) async {
        await MainActor.run {
            presenter?.presentAuthRequiredToast(for: destination)
        }
    }

    // MARK: - Default client factory

    public static func defaultClientFactory(_ destination: StenoCloudDestination) -> StenoCloudClient? {
        switch destination {
        case .webdav:
            return makeWebDAVClient()
        case .s3:
            return makeS3Client()
        case .yandex:
            return makeYandexClient()
        }
    }

    private static func makeWebDAVClient() -> StenoCloudClient? {
        let raw = StenoCloudSettings.webdavBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: raw), !raw.isEmpty else { return nil }
        let password = (try? StenoCloudKeychain.get(
            account: StenoCloudKeychain.accountName(destination: .webdav, field: "password")
        )) ?? ""
        return WebDAVClient(
            baseURL: base,
            username: StenoCloudSettings.webdavUsername,
            password: password,
            pathPrefix: StenoCloudSettings.webdavPathPrefix
        )
    }

    private static func makeS3Client() -> StenoCloudClient? {
        let raw = StenoCloudSettings.s3Endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let endpoint = URL(string: raw), !raw.isEmpty else { return nil }
        let secret = (try? StenoCloudKeychain.get(
            account: StenoCloudKeychain.accountName(destination: .s3, field: "secretAccessKey")
        )) ?? ""
        return S3CompatibleClient(
            endpoint: endpoint,
            region: StenoCloudSettings.s3Region,
            bucket: StenoCloudSettings.s3Bucket,
            accessKeyId: StenoCloudSettings.s3AccessKeyId,
            secretAccessKey: secret,
            pathPrefix: StenoCloudSettings.s3PathPrefix
        )
    }

    private static func makeYandexClient() -> StenoCloudClient? {
        YandexDiskClient(pathPrefix: StenoCloudSettings.yandexPathPrefix)
    }
}

private final class DrainGate: @unchecked Sendable {
    private let lock = NSLock()
    private var busy = false

    func begin() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if busy { return false }
        busy = true
        return true
    }

    func end() {
        lock.lock()
        defer { lock.unlock() }
        busy = false
    }
}
