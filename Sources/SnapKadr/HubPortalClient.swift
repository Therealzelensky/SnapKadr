import Foundation

/// Загрузка пакета Стено/Кадр в папку проекта Server Hub
/// (`POST /portal-auth/api/external-projects/files/upload`).
public final class HubPortalClient: StenoCloudClient {
    public let destination: StenoCloudDestination = .hub

    private let session: URLSession
    private var cancelled = false
    private let projectIdOverride: String?

    public init(projectIdOverride: String? = nil, session: URLSession = .shared) {
        self.projectIdOverride = projectIdOverride
        self.session = session
    }

    public func cancel() {
        cancelled = true
    }

    public func testConnection() async throws {
        guard StenoCloudSettings.hubEnabled else { throw StenoCloudError.destinationDisabled }
        let base = try baseURL()
        var req = URLRequest(url: base.appendingPathComponent("portal-auth/api/external-projects"))
        req.httpMethod = "GET"
        try applyAuth(to: &req)
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw StenoCloudError.network("no response")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw StenoCloudError.authRequired
        }
        guard (200..<300).contains(http.statusCode) else {
            throw StenoCloudError.server(status: http.statusCode, message: "projects list")
        }
    }

    public func uploadPackage(localProjectURL: URL) async throws {
        guard StenoCloudSettings.hubEnabled else { throw StenoCloudError.destinationDisabled }
        cancelled = false

        let projectId = try resolveProjectId()
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: localProjectURL.path, isDirectory: &isDir),
              isDir.boolValue
        else { throw StenoCloudError.notAPackage }

        let files = try collectUploadFiles(in: localProjectURL)
        guard !files.isEmpty else {
            throw StenoCloudError.network("нет файлов для загрузки в Hub")
        }

        StenoCloudLog.log("Hub upload → project=\(projectId) files=\(files.count) from \(localProjectURL.lastPathComponent)")

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"id\"\r\n\r\n")
        append("\(projectId)\r\n")

        for file in files {
            if cancelled { throw StenoCloudError.cancelled }
            let data = try Data(contentsOf: file.url)
            let name = file.uploadName
            let mime = file.mime
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"files\"; filename=\"\(name)\"\r\n")
            append("Content-Type: \(mime)\r\n\r\n")
            body.append(data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")

        let base = try baseURL()
        var req = URLRequest(url: base.appendingPathComponent("portal-auth/api/external-projects/files/upload"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        try applyAuth(to: &req)

        let (respData, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw StenoCloudError.network("no response")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw StenoCloudError.authRequired
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: respData, encoding: .utf8) ?? ""
            throw StenoCloudError.server(status: http.statusCode, message: String(msg.prefix(240)))
        }
        StenoCloudLog.log("Hub upload OK project=\(projectId)")
    }

    // MARK: - Internals

    private struct UploadFile {
        var url: URL
        var uploadName: String
        var mime: String
    }

    private func resolveProjectId() throws -> String {
        if let projectIdOverride, !projectIdOverride.isEmpty {
            return projectIdOverride
        }
        // 1) Живой контекст AutoFocus (если приложение установлено и идёт созвон с проектом)
        if let ctx = AutoFocusCallContext.load(), let id = ctx.resolvedHubProjectId, !id.isEmpty {
            return id
        }
        // 2) Ручной ID в настройках SnapKadr — работа без AutoFocus
        let manual = StenoCloudSettings.hubManualProjectId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manual.isEmpty {
            return manual
        }
        throw StenoCloudError.hubProjectMissing
    }

    private func baseURL() throws -> URL {
        let raw = StenoCloudSettings.hubBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw), !raw.isEmpty else {
            throw StenoCloudError.network("Hub URL не задан")
        }
        return url
    }

    private func applyAuth(to request: inout URLRequest) throws {
        let cookie = StenoCloudSettings.hubSessionCookie.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
            return
        }
        // Fallback: cookies из общей jar для домена Hub.
        if let host = request.url?.host {
            let cookies = HTTPCookieStorage.shared.cookies ?? []
            let matched = cookies.filter { ($0.domain as NSString).contains(host) || host.contains($0.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))) }
            if !matched.isEmpty {
                let header = matched.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                request.setValue(header, forHTTPHeaderField: "Cookie")
                return
            }
        }
        throw StenoCloudError.authRequired
    }

    /// Видео + текстовые артефакты Стено; имя с префиксом пакета.
    private func collectUploadFiles(in root: URL) throws -> [UploadFile] {
        let fm = FileManager.default
        let prefix = root.lastPathComponent
            .replacingOccurrences(of: "/", with: "-")
        var out: [UploadFile] = []

        let preferred = [
            "recording",
            "recording.mp4",
            "recording.mov",
            "steno.json",
            "meta.json",
            "project.json",
            "digest.md",
            "transcript.md",
            "notes.md",
        ]
        for name in preferred {
            let url = root.appendingPathComponent(name)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
                out.append(UploadFile(url: url, uploadName: "\(prefix)-\(name)", mime: mime(for: url)))
            }
        }

        // recording/ может быть каталогом с дорожками
        let recordingDir = root.appendingPathComponent("recording", isDirectory: true)
        if fm.fileExists(atPath: recordingDir.path) {
            if let enumr = fm.enumerator(at: recordingDir, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles]) {
                while let item = enumr.nextObject() as? URL {
                    let vals = try item.resourceValues(forKeys: [.isDirectoryKey])
                    if vals.isDirectory == true { continue }
                    let ext = item.pathExtension.lowercased()
                    guard ["mp4", "mov", "m4a", "wav", "webm", "mkv"].contains(ext) else { continue }
                    let rel = item.lastPathComponent
                    out.append(UploadFile(url: item, uploadName: "\(prefix)-\(rel)", mime: mime(for: item)))
                }
            }
        }

        // Dedup by uploadName
        var seen = Set<String>()
        return out.filter { seen.insert($0.uploadName).inserted }
    }

    private func mime(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "webm": return "video/webm"
        case "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        case "json": return "application/json"
        case "md": return "text/markdown"
        default: return "application/octet-stream"
        }
    }
}
