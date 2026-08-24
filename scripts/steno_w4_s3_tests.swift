// swiftc -parse-as-library \
//   Sources/SnapKadr/ProjectCloudAdapter.swift \
//   Sources/SnapKadr/S3CloudAdapter.swift \
//   scripts/steno_w4_s3_tests.swift \
//   -o /tmp/steno_w4_s3 && /tmp/steno_w4_s3
import Foundation
import CryptoKit

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoW4S3Tests {
    static func main() {
        expect(
            S3ObjectKey.join(prefix: "backups", project: "A.kadr", relative: "steno.json")
                == "backups/A.kadr/steno.json",
            "key"
        )
        expect(
            S3ObjectKey.join(prefix: "", project: "A.kadr", relative: "x") == "A.kadr/x",
            "empty prefix"
        )

        // Fixed canonical-request hash fixture (AWS SigV4 shape).
        let method = "GET"
        let url = URL(string: "https://examplebucket.s3.amazonaws.com/test.txt")!
        let headers = [
            "host": "examplebucket.s3.amazonaws.com",
            "x-amz-date": "20130524T000000Z",
            "x-amz-content-sha256": S3Signing.emptyPayloadHash
        ]
        let canonical = S3Signing.canonicalRequest(
            method: method,
            url: url,
            headers: headers,
            payloadHash: S3Signing.emptyPayloadHash
        )
        expect(canonical.contains("GET\n"), "canonical starts GET")
        expect(canonical.contains("host:examplebucket.s3.amazonaws.com"), "canonical host")
        let hash = S3Signing.sha256Hex(canonical)
        expect(hash.count == 64, "canonical hash length")

        let sts = S3Signing.stringToSign(
            canonicalRequestHash: hash,
            amzDate: "20130524T000000Z",
            region: "us-east-1",
            service: "s3"
        )
        expect(sts.hasPrefix("AWS4-HMAC-SHA256\n"), "stringToSign algo")
        expect(sts.contains("20130524/us-east-1/s3/aws4_request"), "credential scope")

        exit(failures == 0 ? 0 : 1)
    }
}
