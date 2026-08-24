import AppKit
import Foundation

public extension Notification.Name {
    static let showPrefsGeneralTab = Notification.Name("showPrefsGeneralTab")
}

@MainActor
public final class StenoCloudHUDPresenter: StenoCloudPresenting {
    public static let shared = StenoCloudHUDPresenter()

    private let hud = SuiteNotchHUD.shared

    public init() {}

    public func presentDeferredUploadToast(for destination: StenoCloudDestination) {
        _ = destination
        hud.showCloudUploadDeferred()
    }

    public func presentAuthRequiredToast(for destination: StenoCloudDestination) {
        _ = destination
        hud.showCloudAuthRequired()
    }
}
