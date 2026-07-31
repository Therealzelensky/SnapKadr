import AppKit
import Carbon
import SnapKit

/// Suite Carbon hotkeys with B2 coexistence: pause while Snap.app / SnapBeta runs.
@MainActor
final class SuiteHotkeyMonitor: ObservableObject {
    static let shared = SuiteHotkeyMonitor()

    @Published private(set) var isPausedForCompanionSnap = false

    private var monitor: HotkeyMonitor?
    private var workspaceObs: [NSObjectProtocol] = []

    private static let snapBundleIDs = ["com.snap.app", "com.snap.app.beta"]

    private init() {}

    func start() {
        observeWorkspace()
        refreshCoexistence()
    }

    func stop() {
        for obs in workspaceObs {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        workspaceObs.removeAll()
        monitor?.stop()
        monitor = nil
    }

    func refreshCoexistence() {
        let snapRunning = Self.snapBundleIDs.contains { id in
            !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty
        }
        if snapRunning {
            isPausedForCompanionSnap = true
            monitor?.stop()
            monitor = nil
        } else {
            isPausedForCompanionSnap = false
            if monitor == nil {
                let m = HotkeyMonitor(signature: HotkeyMonitor.suiteSignature) { action in
                    Task { @MainActor in
                        Self.dispatch(action)
                    }
                }
                m.start()
                monitor = m
            } else {
                monitor?.reload()
            }
        }
    }

    private func observeWorkspace() {
        guard workspaceObs.isEmpty else { return }
        let nc = NSWorkspace.shared.notificationCenter
        let launch = nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bid = app.bundleIdentifier,
                  Self.snapBundleIDs.contains(bid)
            else { return }
            Task { @MainActor in self?.refreshCoexistence() }
        }
        let terminate = nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bid = app.bundleIdentifier,
                  Self.snapBundleIDs.contains(bid)
            else { return }
            Task { @MainActor in self?.refreshCoexistence() }
        }
        workspaceObs = [launch, terminate]
    }

    private static func dispatch(_ action: HotkeyMonitor.Action) {
        switch action {
        case .area: SnapEngine.shared.captureArea()
        case .full: SnapEngine.shared.captureFull()
        case .window: SnapEngine.shared.captureActiveWindow()
        case .anyWindow: SnapEngine.shared.captureAnyWindow()
        case .ocr: SnapEngine.shared.captureOCR()
        case .scrolling: SnapEngine.shared.captureScrollingArea()
        case .repeat: SnapEngine.shared.captureRepeatArea()
        case .showApp:
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
