import AppKit
import Combine
import Foundation

public struct StenoDetectedCall: Equatable, Sendable {
    public var source: StenoSource
    public var windowID: UInt32
    public var title: String

    public init(source: StenoSource, windowID: UInt32, title: String) {
        self.source = source
        self.windowID = windowID
        self.title = title
    }
}

@MainActor
public final class StenoDetector: ObservableObject {
    @Published public private(set) var activeCall: StenoDetectedCall?

    private let probe: () -> [StenoWindowSnapshot]
    private var snooze = StenoSnoozeState()
    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    public init(probe: @escaping () -> [StenoWindowSnapshot] = {
        StenoWindowProbe.snapshots(matchingPIDs: StenoWindowProbe.sourcePIDs())
    }) {
        self.probe = probe
    }

    public func start() {
        stop()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            },
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            },
        ]
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        for obs in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        workspaceObservers = []
        activeCall = nil
    }

    public func snooze(windowID: UInt32) {
        snooze.snooze(windowID)
        if activeCall?.windowID == windowID {
            activeCall = nil
        }
        tick()
    }

    public func tick() {
        let snaps = probe()
        let present = Set(snaps.map(\.windowID))
        snooze.reap(presentIDs: present)
        let enabled = StenoSettings.enabledSources
        let found = snaps.first { snap in
            !snooze.isSnoozed(snap.windowID) && StenoMatcher.match(snap, enabled: enabled) != nil
        }
        if let found, let source = StenoMatcher.match(found, enabled: enabled) {
            let next = StenoDetectedCall(source: source, windowID: found.windowID, title: found.title)
            if activeCall != next {
                activeCall = next
            }
        } else if activeCall != nil {
            activeCall = nil
        }
    }

    deinit {
        timer?.invalidate()
    }
}
