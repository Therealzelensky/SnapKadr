import Foundation

public enum StenoCloudError: Error, Equatable {
    case destinationDisabled
    case autoUploadDisabled
    case notAPackage
    case authRequired
    case network(String)
    case server(status: Int, message: String)
    case cancelled
}

public protocol StenoCloudClient: AnyObject {
    var destination: StenoCloudDestination { get }
    func testConnection() async throws
    func uploadPackage(localProjectURL: URL) async throws
    func cancel()
}

public protocol StenoCloudPresenting: AnyObject {
    @MainActor func presentDeferredUploadToast(for destination: StenoCloudDestination)
    @MainActor func presentAuthRequiredToast(for destination: StenoCloudDestination)
}
