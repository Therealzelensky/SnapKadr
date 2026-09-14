import Foundation

enum YandexDiskOperation {
    static func href(statusCode: Int, data: Data) -> URL? {
        guard statusCode == 202 else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let href = json["href"] as? String
        else { return nil }
        return URL(string: href)
    }

    /// `true` success, `false` failed, `nil` still running / unknown.
    static func isFinished(_ data: Data) -> Bool? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? String
        else { return nil }
        switch status {
        case "success": return true
        case "failed": return false
        default: return nil
        }
    }
}

/// Pure rules for resume / async op waits (unit-tested).
enum YandexDiskUploadPolicy {
    /// Large package MOVE/DELETE often exceeds 30s on Disk.
    static let operationTimeout: TimeInterval = 600
    static let operationPollNanos: UInt64 = 800_000_000

    /// Skip PUT when a complete remote object already matches local bytes.
    static func shouldSkipUpload(localSize: Int64, remoteSize: Int64?) -> Bool {
        guard let remoteSize, remoteSize >= 0 else { return false }
        return remoteSize == localSize && localSize > 0
    }
}

enum YandexDiskPath {
    static let appFolderName = "SnapKadr"
    static let appRoot = "disk:/SnapKadr"

    static func join(prefix: String, project: String) -> String {
        remoteFolder(prefix: prefix, project: project)
    }

    static func remoteFolder(prefix: String, project: String) -> String {
        let effectivePrefix = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty
            ? appFolderName
            : prefix
        let parts = [effectivePrefix, project]
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
            .filter { !$0.isEmpty }
        return "disk:/" + parts.joined(separator: "/")
    }

    static func filePath(prefix: String, project: String, relative: String) -> String {
        let base = remoteFolder(prefix: prefix, project: project)
        let rel = relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !rel.isEmpty else { return base }
        return base + "/" + rel
    }

    static func tempPath(forFinal path: String) -> String {
        path + ".uploading"
    }
}

public final class YandexDiskClient: StenoCloudClient {
    public let destination: StenoCloudDestination = .yandex

    private let pathPrefix: String
    private let oauth: YandexOAuthSession
    private let session: URLSession
    private var cancelled = false

    public init(
        pathPrefix: String = StenoCloudSettings.yandexPathPrefix,
        oauth: YandexOAuthSession = YandexOAuthSession(),
        session: URLSession = .shared
    ) {
        self.pathPrefix = pathPrefix
        self.oauth = oauth
        self.session = session
    }

    public func testConnection() async throws {
        let token = try await oauth.validAccessToken()
        var req = URLRequest(url: URL(string: "https://cloud-api.yandex.net/v1/disk/")!)
        req.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: req)
        try throwIfNeeded(response)
        try await ensureAppRootFolder(token: token)
    }

    /// Creates `disk:/SnapKadr` (idempotent) and pins uploads to that prefix.
    public func ensureAppRootFolder(token: String? = nil) async throws {
        let access: String
        if let token {
            access = token
        } else {
            access = try await oauth.validAccessToken()
        }
        StenoCloudSettings.yandexPathPrefix = YandexDiskPath.appFolderName
        try await ensureFolder(path: YandexDiskPath.appRoot, token: access, recursive: true)
    }

    public func uploadPackage(localProjectURL: URL) async throws {
        let token = try await oauth.validAccessToken()
        guard !cancelled else { throw StenoCloudError.cancelled }
        try await ensureAppRootFolder(token: token)

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: localProjectURL.path, isDirectory: &isDir),
              isDir.boolValue
        else { throw StenoCloudError.notAPackage }

        let projectName = localProjectURL.lastPathComponent
        let prefix = YandexDiskPath.appFolderName
        let finalRoot = YandexDiskPath.remoteFolder(prefix: prefix, project: projectName)
        let tempRoot = YandexDiskPath.tempPath(forFinal: finalRoot)

        StenoCloudLog.log("Yandex upload start \(projectName) → \(tempRoot)")

        try await ensureFolder(path: tempRoot, token: token, recursive: true)

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: localProjectURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw StenoCloudError.network("cannot enumerate package")
        }

        var uploaded = 0
        var skipped = 0
        var bytes: Int64 = 0

        while let item = enumerator.nextObject() as? URL {
            if cancelled { throw StenoCloudError.cancelled }
            let vals = try item.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let rel = StenoCloudPackage.relativePath(of: item, inside: localProjectURL)
            guard !rel.isEmpty else { continue }
            let remotePath = tempRoot + "/" + rel
            if vals.isDirectory == true {
                try await ensureFolder(path: remotePath, token: token, recursive: false)
            } else {
                let localSize = Int64(vals.fileSize ?? 0)
                let remoteSize = try await remoteFileSize(path: remotePath, token: token)
                if YandexDiskUploadPolicy.shouldSkipUpload(localSize: localSize, remoteSize: remoteSize) {
                    skipped += 1
                    bytes += localSize
                    StenoCloudLog.log("Yandex skip \(rel) (\(localSize) B, already on Disk)")
                    continue
                }
                StenoCloudLog.log("Yandex PUT \(rel) (\(localSize) B)")
                try await uploadFile(local: item, remotePath: remotePath, token: token)
                uploaded += 1
                bytes += localSize
            }
        }

        StenoCloudLog.log(
            "Yandex files done \(projectName) uploaded=\(uploaded) skipped=\(skipped) bytes=\(bytes); MOVE → \(finalRoot)"
        )

        try? await deletePath(finalRoot, token: token)
        try await movePath(from: tempRoot, to: finalRoot, token: token)
        StenoCloudLog.log("Yandex upload OK \(projectName)")
    }

    public func cancel() {
        cancelled = true
    }

    // MARK: - Disk REST

    private func ensureFolder(path: String, token: String, recursive: Bool) async throws {
        if recursive {
            let trimmed = path.replacingOccurrences(of: "disk:/", with: "")
            var built = "disk:"
            for part in trimmed.split(separator: "/") {
                built += "/" + part
                try await createFolder(path: built, token: token)
            }
        } else {
            try await createFolder(path: path, token: token)
        }
    }

    private func createFolder(path: String, token: String) async throws {
        var components = URLComponents(string: "https://cloud-api.yandex.net/v1/disk/resources")!
        components.queryItems = [URLQueryItem(name: "path", value: path)]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "PUT"
        req.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 201 || http.statusCode == 409 { return }
            if http.statusCode == 401 { throw StenoCloudError.authRequired }
            throw StenoCloudError.server(status: http.statusCode, message: "mkdir")
        }
    }

    /// `nil` if missing / not a file.
    private func remoteFileSize(path: String, token: String) async throws -> Int64? {
        var components = URLComponents(string: "https://cloud-api.yandex.net/v1/disk/resources")!
        components.queryItems = [
            URLQueryItem(name: "path", value: path),
            URLQueryItem(name: "fields", value: "type,size")
        ]
        var req = URLRequest(url: components.url!)
        req.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { return nil }
            if http.statusCode == 401 || http.statusCode == 403 {
                throw StenoCloudError.authRequired
            }
            guard (200..<300).contains(http.statusCode) else { return nil }
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["type"] as? String) == "file"
        else { return nil }
        if let n = json["size"] as? Int64 { return n }
        if let n = json["size"] as? Int { return Int64(n) }
        if let n = json["size"] as? NSNumber { return n.int64Value }
        return nil
    }

    private func uploadFile(local: URL, remotePath: String, token: String) async throws {
        var components = URLComponents(string: "https://cloud-api.yandex.net/v1/disk/resources/upload")!
        components.queryItems = [
            URLQueryItem(name: "path", value: remotePath),
            URLQueryItem(name: "overwrite", value: "true")
        ]
        var metaReq = URLRequest(url: components.url!)
        metaReq.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        let (metaData, metaResp) = try await session.data(for: metaReq)
        try throwIfNeeded(metaResp)
        guard let json = try JSONSerialization.jsonObject(with: metaData) as? [String: Any],
              let href = json["href"] as? String,
              let uploadURL = URL(string: href)
        else {
            throw StenoCloudError.network("missing upload href")
        }
        // Stream from disk — packages often include 40–300 MB media.
        var put = URLRequest(url: uploadURL)
        put.httpMethod = "PUT"
        put.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (_, putResp) = try await session.upload(for: put, fromFile: local)
        try throwIfNeeded(putResp)
    }

    private func deletePath(_ path: String, token: String) async throws {
        var components = URLComponents(string: "https://cloud-api.yandex.net/v1/disk/resources")!
        components.queryItems = [
            URLQueryItem(name: "path", value: path),
            URLQueryItem(name: "permanently", value: "true")
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "DELETE"
        req.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 204 || http.statusCode == 404 { return }
            if http.statusCode == 202 {
                try await waitForOperation(data: data, token: token, label: "DELETE \(path)")
                return
            }
        }
        try throwIfNeeded(response)
    }

    private func movePath(from: String, to: String, token: String) async throws {
        var components = URLComponents(string: "https://cloud-api.yandex.net/v1/disk/resources/move")!
        components.queryItems = [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "path", value: to),
            URLQueryItem(name: "overwrite", value: "true")
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        req.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode == 201 {
            return
        }
        if let http = response as? HTTPURLResponse, http.statusCode == 202 {
            try await waitForOperation(data: data, token: token, label: "MOVE \(from) → \(to)")
            return
        }
        try throwIfNeeded(response)
    }

    private func waitForOperation(data: Data, token: String, label: String) async throws {
        guard let url = YandexDiskOperation.href(statusCode: 202, data: data) else {
            StenoCloudLog.log("Yandex \(label): 202 without href — treating as done")
            return
        }
        let deadline = Date().addingTimeInterval(YandexDiskUploadPolicy.operationTimeout)
        StenoCloudLog.log("Yandex wait \(label) up to \(Int(YandexDiskUploadPolicy.operationTimeout))s")
        while Date() < deadline {
            if cancelled { throw StenoCloudError.cancelled }
            var req = URLRequest(url: url)
            req.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
            let (body, response) = try await session.data(for: req)
            try throwIfNeeded(response)
            switch YandexDiskOperation.isFinished(body) {
            case true:
                StenoCloudLog.log("Yandex \(label) finished")
                return
            case false:
                StenoCloudLog.log("Yandex \(label) failed on Disk")
                throw StenoCloudError.network("Yandex Disk operation failed")
            case nil:
                try await Task.sleep(nanoseconds: YandexDiskUploadPolicy.operationPollNanos)
            }
        }
        StenoCloudLog.log("Yandex \(label) timed out after \(Int(YandexDiskUploadPolicy.operationTimeout))s")
        throw StenoCloudError.network("Yandex Disk operation timed out")
    }

    private func throwIfNeeded(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw StenoCloudError.network("invalid response")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw StenoCloudError.authRequired
        }
        guard (200..<300).contains(http.statusCode) else {
            StenoCloudLog.log("Yandex HTTP \(http.statusCode)")
            throw StenoCloudError.server(status: http.statusCode, message: "Yandex Disk")
        }
    }
}
