import CryptoKit
import Foundation

enum S3ObjectKey {
    static func join(prefix: String, project: String, relative: String) -> String {
        let parts = [prefix, project, relative]
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: "/")
    }
}

enum S3Signing {
    static let emptyPayloadHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    static func sha256Hex(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Hex(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func hmacSHA256(key: Data, data: Data) -> Data {
        let key = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(mac)
    }

    static func canonicalRequest(
        method: String,
        url: URL,
        headers: [String: String],
        payloadHash: String
    ) -> String {
        let path = url.path.isEmpty ? "/" : url.path.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? url.path
        let query = canonicalQuery(url.query ?? "")
        let sortedKeys = headers.keys.map { $0.lowercased() }.sorted()
        var canonicalHeaders = ""
        var signedHeaders: [String] = []
        for key in sortedKeys {
            let value = headers.first { $0.key.lowercased() == key }?.value
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            canonicalHeaders += "\(key):\(value)\n"
            signedHeaders.append(key)
        }
        let signed = signedHeaders.joined(separator: ";")
        return [
            method,
            path,
            query,
            canonicalHeaders,
            signed,
            payloadHash
        ].joined(separator: "\n")
    }

    static func stringToSign(
        canonicalRequestHash: String,
        amzDate: String,
        region: String,
        service: String
    ) -> String {
        let dateStamp = String(amzDate.prefix(8))
        let scope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        return [
            "AWS4-HMAC-SHA256",
            amzDate,
            scope,
            canonicalRequestHash
        ].joined(separator: "\n")
    }

    static func signingKey(
        secret: String,
        dateStamp: String,
        region: String,
        service: String
    ) -> Data {
        let kDate = hmacSHA256(key: Data("AWS4\(secret)".utf8), data: Data(dateStamp.utf8))
        let kRegion = hmacSHA256(key: kDate, data: Data(region.utf8))
        let kService = hmacSHA256(key: kRegion, data: Data(service.utf8))
        return hmacSHA256(key: kService, data: Data("aws4_request".utf8))
    }

    static func authorizationHeader(
        accessKeyId: String,
        region: String,
        amzDate: String,
        signedHeaders: String,
        signature: String
    ) -> String {
        let dateStamp = String(amzDate.prefix(8))
        let scope = "\(dateStamp)/\(region)/s3/aws4_request"
        return "AWS4-HMAC-SHA256 Credential=\(accessKeyId)/\(scope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
    }

    private static func canonicalQuery(_ query: String) -> String {
        guard !query.isEmpty else { return "" }
        return query.split(separator: "&").map(String.init).sorted().joined(separator: "&")
    }
}

public final class S3CompatibleClient: StenoCloudClient {
    public let destination: StenoCloudDestination = .s3

    private let endpoint: URL
    private let region: String
    private let bucket: String
    private let accessKeyId: String
    private let secretAccessKey: String
    private let pathPrefix: String
    private let session: URLSession
    private var cancelled = false

    /// Region empty → `"us-east-1"` (MinIO / path-style often ignore region; AWS-compatible default).
    public init(
        endpoint: URL,
        region: String,
        bucket: String,
        accessKeyId: String,
        secretAccessKey: String,
        pathPrefix: String,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.region = region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "us-east-1"
            : region
        self.bucket = bucket
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        self.pathPrefix = pathPrefix
        self.session = session
    }

    public func testConnection() async throws {
        try ensureCredentials()
        let listURL = listURL()
        var req = URLRequest(url: listURL)
        req.httpMethod = "GET"
        try sign(&req, payloadHash: S3Signing.emptyPayloadHash)
        let (_, response) = try await session.data(for: req)
        try throwIfNeeded(response)
    }

    public func uploadPackage(localProjectURL: URL) async throws {
        try ensureCredentials()
        guard !cancelled else { throw StenoCloudError.cancelled }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: localProjectURL.path, isDirectory: &isDir),
              isDir.boolValue
        else { throw StenoCloudError.notAPackage }

        let projectName = localProjectURL.lastPathComponent
        var uploadedKeys: [String] = []

        do {
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
                let vals = try item.resourceValues(forKeys: [.isDirectoryKey])
                if vals.isDirectory == true { continue }
                let rel = item.path.replacingOccurrences(of: localProjectURL.path, with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard !rel.isEmpty else { continue }
                let key = S3ObjectKey.join(prefix: pathPrefix, project: projectName, relative: rel)
                try await putObject(local: item, key: key)
                uploadedKeys.append(key)
            }
        } catch {
            for key in uploadedKeys {
                try? await deleteObject(key: key)
            }
            throw error
        }
    }

    public func cancel() {
        cancelled = true
    }

    // MARK: - Internals

    private func ensureCredentials() throws {
        if secretAccessKey.isEmpty || accessKeyId.isEmpty {
            throw StenoCloudError.authRequired
        }
        if bucket.isEmpty {
            throw StenoCloudError.network("missing bucket")
        }
    }

    private func listURL() -> URL {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        var path = components.path
        if !path.hasSuffix("/") { path += "/" }
        path += bucket
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "list-type", value: "2"),
            URLQueryItem(name: "max-keys", value: "1")
        ]
        return components.url!
    }

    private func objectURL(key: String) -> URL {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        var path = components.path
        if !path.hasSuffix("/") { path += "/" }
        path += bucket
        if !key.isEmpty {
            path += "/" + key.split(separator: "/").map {
                String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
            }.joined(separator: "/")
        }
        components.path = path
        components.query = nil
        return components.url!
    }

    private func putObject(local: URL, key: String) async throws {
        let data = try Data(contentsOf: local)
        let payloadHash = S3Signing.sha256Hex(data: data)
        var req = URLRequest(url: objectURL(key: key))
        req.httpMethod = "PUT"
        req.httpBody = data
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        try sign(&req, payloadHash: payloadHash)
        let (_, response) = try await session.data(for: req)
        try throwIfNeeded(response)
    }

    private func deleteObject(key: String) async throws {
        var req = URLRequest(url: objectURL(key: key))
        req.httpMethod = "DELETE"
        try sign(&req, payloadHash: S3Signing.emptyPayloadHash)
        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse,
           http.statusCode == 204 || http.statusCode == 200 || http.statusCode == 404
        {
            return
        }
        try throwIfNeeded(response)
    }

    private func sign(_ req: inout URLRequest, payloadHash: String) throws {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = formatter.string(from: Date())
        let host = req.url?.host ?? endpoint.host ?? ""

        req.setValue(host, forHTTPHeaderField: "Host")
        req.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        req.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")

        var headers: [String: String] = [
            "host": host,
            "x-amz-date": amzDate,
            "x-amz-content-sha256": payloadHash
        ]
        if let ct = req.value(forHTTPHeaderField: "Content-Type") {
            headers["content-type"] = ct
        }

        let canonical = S3Signing.canonicalRequest(
            method: req.httpMethod ?? "GET",
            url: req.url!,
            headers: headers,
            payloadHash: payloadHash
        )
        let hash = S3Signing.sha256Hex(canonical)
        let toSign = S3Signing.stringToSign(
            canonicalRequestHash: hash,
            amzDate: amzDate,
            region: region,
            service: "s3"
        )
        let dateStamp = String(amzDate.prefix(8))
        let key = S3Signing.signingKey(
            secret: secretAccessKey,
            dateStamp: dateStamp,
            region: region,
            service: "s3"
        )
        let sigData = S3Signing.hmacSHA256(key: key, data: Data(toSign.utf8))
        let signature = sigData.map { String(format: "%02x", $0) }.joined()
        let signedHeaders = headers.keys.map { $0.lowercased() }.sorted().joined(separator: ";")
        let auth = S3Signing.authorizationHeader(
            accessKeyId: accessKeyId,
            region: region,
            amzDate: amzDate,
            signedHeaders: signedHeaders,
            signature: signature
        )
        req.setValue(auth, forHTTPHeaderField: "Authorization")
    }

    private func throwIfNeeded(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw StenoCloudError.network("invalid response")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw StenoCloudError.authRequired
        }
        guard (200..<300).contains(http.statusCode) else {
            throw StenoCloudError.server(status: http.statusCode, message: "S3 request failed")
        }
    }
}
