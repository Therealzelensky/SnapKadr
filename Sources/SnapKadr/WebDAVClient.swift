import Foundation

enum WebDAVPath {
    static func join(_ base: URL, prefix: String, components: String...) -> URL {
        var url = base
        let trimmedPrefix = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !trimmedPrefix.isEmpty {
            for part in trimmedPrefix.split(separator: "/") {
                url = url.appendingPathComponent(String(part))
            }
        }
        for component in components where !component.isEmpty {
            url = url.appendingPathComponent(component)
        }
        return url
    }

    static func tempName(forFinal finalName: String) -> String {
        "\(finalName).uploading"
    }

    static func connectionProbeURL(base: URL, prefix: String) -> URL {
        _ = prefix
        return base
    }
}

public final class WebDAVClient: StenoCloudClient {
    public let destination: StenoCloudDestination = .webdav

    private let baseURL: URL
    private let username: String
    private let password: String
    private let pathPrefix: String
    private let session: URLSession
    private var cancelled = false

    public init(
        baseURL: URL,
        username: String,
        password: String,
        pathPrefix: String,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
        self.pathPrefix = pathPrefix
        self.session = session
    }

    public func testConnection() async throws {
        try ensureCredentials()
        let url = WebDAVPath.connectionProbeURL(base: baseURL, prefix: pathPrefix)
        var req = URLRequest(url: url)
        req.httpMethod = "PROPFIND"
        req.setValue("0", forHTTPHeaderField: "Depth")
        req.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        applyAuth(&req)
        let (_, response) = try await session.data(for: req)
        try throwIfNeeded(response, fallback: "PROPFIND failed")
    }

    public func uploadPackage(localProjectURL: URL) async throws {
        try ensureCredentials()
        guard !cancelled else { throw StenoCloudError.cancelled }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: localProjectURL.path, isDirectory: &isDir),
              isDir.boolValue
        else { throw StenoCloudError.notAPackage }

        let finalName = localProjectURL.lastPathComponent
        let tempName = WebDAVPath.tempName(forFinal: finalName)
        let tempRoot = WebDAVPath.join(baseURL, prefix: pathPrefix, components: tempName)
        let finalRoot = WebDAVPath.join(baseURL, prefix: pathPrefix, components: finalName)

        try? await deleteRecursive(tempRoot)

        try await mkcolParents(of: tempRoot)
        try await mkcol(tempRoot)

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: localProjectURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw StenoCloudError.network("cannot enumerate package")
        }

        while let item = enumerator.nextObject() as? URL {
            if cancelled { throw StenoCloudError.cancelled }
            let rel = StenoCloudPackage.relativePath(of: item, inside: localProjectURL)
            guard !rel.isEmpty else { continue }
            let remote = appendRelative(tempRoot, relative: rel)
            let vals = try item.resourceValues(forKeys: [.isDirectoryKey])
            if vals.isDirectory == true {
                try await mkcol(remote)
            } else {
                try await putFile(local: item, remote: remote)
            }
        }

        try? await deleteRecursive(finalRoot)
        try await move(from: tempRoot, to: finalRoot)
    }

    public func cancel() {
        cancelled = true
    }

    // MARK: - Internals

    private func ensureCredentials() throws {
        if password.isEmpty { throw StenoCloudError.authRequired }
    }

    private func applyAuth(_ req: inout URLRequest) {
        let raw = "\(username):\(password)"
        let b64 = Data(raw.utf8).base64EncodedString()
        req.setValue("Basic \(b64)", forHTTPHeaderField: "Authorization")
    }

    private func appendRelative(_ root: URL, relative: String) -> URL {
        var url = root
        for part in relative.split(separator: "/") {
            url = url.appendingPathComponent(String(part))
        }
        return url
    }

    private func mkcolParents(of url: URL) async throws {
        var chain: [URL] = []
        var cur = url.deletingLastPathComponent()
        let basePath = baseURL.path
        while cur.path.count > basePath.count {
            chain.insert(cur, at: 0)
            let parent = cur.deletingLastPathComponent()
            if parent.path == cur.path { break }
            cur = parent
        }
        for dir in chain {
            try? await mkcol(dir)
        }
        if !pathPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty {
            try? await mkcol(WebDAVPath.join(baseURL, prefix: pathPrefix))
        }
    }

    private func mkcol(_ url: URL) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = "MKCOL"
        applyAuth(&req)
        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 201 || http.statusCode == 405 || http.statusCode == 301
                || http.statusCode == 200 || http.statusCode == 409
            {
                return
            }
            throw StenoCloudError.server(status: http.statusCode, message: "MKCOL")
        }
    }

    private func putFile(local: URL, remote: URL) async throws {
        let data = try Data(contentsOf: local)
        var req = URLRequest(url: remote)
        req.httpMethod = "PUT"
        req.httpBody = data
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        applyAuth(&req)
        let (_, response) = try await session.data(for: req)
        try throwIfNeeded(response, fallback: "PUT failed")
    }

    private func move(from: URL, to: URL) async throws {
        var req = URLRequest(url: from)
        req.httpMethod = "MOVE"
        req.setValue(to.absoluteString, forHTTPHeaderField: "Destination")
        req.setValue("T", forHTTPHeaderField: "Overwrite")
        applyAuth(&req)
        let (_, response) = try await session.data(for: req)
        try throwIfNeeded(response, fallback: "MOVE failed")
    }

    private func deleteRecursive(_ url: URL) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        applyAuth(&req)
        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse,
           http.statusCode == 404 || (200..<300).contains(http.statusCode)
        {
            return
        }
        try throwIfNeeded(response, fallback: "DELETE failed")
    }

    private func throwIfNeeded(_ response: URLResponse, fallback: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw StenoCloudError.network(fallback)
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw StenoCloudError.authRequired
        }
        guard (200..<300).contains(http.statusCode) || http.statusCode == 207 else {
            throw StenoCloudError.server(status: http.statusCode, message: fallback)
        }
    }
}
