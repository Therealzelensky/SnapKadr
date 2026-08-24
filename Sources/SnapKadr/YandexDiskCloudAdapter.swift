import Foundation

enum YandexDiskPath {
    static func join(prefix: String, project: String) -> String {
        let parts = [prefix, project]
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
            .filter { !$0.isEmpty }
        return "disk:/" + parts.joined(separator: "/")
    }

    static func filePath(prefix: String, project: String, relative: String) -> String {
        let base = join(prefix: prefix, project: project)
        let rel = relative.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !rel.isEmpty else { return base }
        return base + "/" + rel
    }

    static func tempPath(forFinal path: String) -> String {
        path + ".uploading"
    }
}

public final class YandexDiskCloudAdapter: ProjectCloudAdapter {
    private let pathPrefix: String
    private let oauth: YandexOAuthClient
    private let session: URLSession
    private var cancelled = false

    public init(
        pathPrefix: String = ProjectCloudSettings.yandexPathPrefix,
        oauth: YandexOAuthClient = YandexOAuthClient(),
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
    }

    public func uploadPackage(localProjectURL: URL) async throws {
        let token = try await oauth.validAccessToken()
        guard !cancelled else { throw ProjectCloudError.cancelled }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: localProjectURL.path, isDirectory: &isDir),
              isDir.boolValue
        else { throw ProjectCloudError.notAPackage }

        let projectName = localProjectURL.lastPathComponent
        let finalRoot = YandexDiskPath.join(prefix: pathPrefix, project: projectName)
        let tempRoot = YandexDiskPath.tempPath(forFinal: finalRoot)

        try await ensureFolder(path: tempRoot, token: token, recursive: true)

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: localProjectURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ProjectCloudError.network("cannot enumerate package")
        }

        while let item = enumerator.nextObject() as? URL {
            if cancelled { throw ProjectCloudError.cancelled }
            let vals = try item.resourceValues(forKeys: [.isDirectoryKey])
                let rel = item.path.replacingOccurrences(of: localProjectURL.path, with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard !rel.isEmpty else { continue }
                let remotePath = tempRoot + "/" + rel
                if vals.isDirectory == true {
                    try await ensureFolder(path: remotePath, token: token, recursive: false)
                } else {
                    try await uploadFile(local: item, remotePath: remotePath, token: token)
                }
        }

        // Replace final: delete final if exists, move temp → final via overwrite rename
        try? await deletePath(finalRoot, token: token)
        try await movePath(from: tempRoot, to: finalRoot, token: token)
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
            // 201 created, 409 already exists
            if http.statusCode == 201 || http.statusCode == 409 { return }
            if http.statusCode == 401 { throw ProjectCloudError.authRequired }
            throw ProjectCloudError.server(status: http.statusCode, message: "mkdir")
        }
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
            throw ProjectCloudError.network("missing upload href")
        }
        let body = try Data(contentsOf: local)
        var put = URLRequest(url: uploadURL)
        put.httpMethod = "PUT"
        put.httpBody = body
        put.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (_, putResp) = try await session.data(for: put)
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
        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse,
           http.statusCode == 204 || http.statusCode == 202 || http.statusCode == 404
        {
            return
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
        let (_, response) = try await session.data(for: req)
        try throwIfNeeded(response)
    }

    private func throwIfNeeded(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ProjectCloudError.network("invalid response")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw ProjectCloudError.authRequired
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ProjectCloudError.server(status: http.statusCode, message: "Yandex Disk")
        }
    }
}
