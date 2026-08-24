import Foundation

public enum ProjectCloudError: Error, Equatable {
    case noRemoteConfigured
    case autoUploadDisabled
    case notAPackage
    case authRequired
    case network(String)
    case server(status: Int, message: String)
    case cancelled
}

public protocol ProjectCloudAdapter: AnyObject {
    func testConnection() async throws
    /// Upload entire local `.kadr` directory to remote prefix + basename.
    func uploadPackage(localProjectURL: URL) async throws
    func cancel()
}

@MainActor
public protocol ProjectCloudStorePresenting: AnyObject {
    func presentDeferredUploadToast()
    func presentAuthRequiredToast()
}
