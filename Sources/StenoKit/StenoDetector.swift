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
    private let mediaHold = CallMediaHold()
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
        var foundCall: (snap: StenoWindowSnapshot, source: StenoSource)?
        for snap in snaps where !snooze.isSnoozed(snap.windowID) {
            if let source = StenoMatcher.match(snap, enabled: enabled, media: { self.mediaReady($0, $1) }) {
                foundCall = (snap, source)
                break
            }
        }
        if let found = foundCall?.snap, let source = foundCall?.source {
            let next = StenoDetectedCall(source: source, windowID: found.windowID, title: found.title)
            if activeCall != next {
                activeCall = next
            }
        } else if activeCall != nil {
            activeCall = nil
        }
    }

    /// Интерфейс уже похож на звонок. Медиа-UDP должен продержаться две секунды.
    private func mediaReady(_ snap: StenoWindowSnapshot, _ source: StenoSource) -> Bool {
        guard snap.ownerPID > 0 else { return false }
        let hit = CallSocketProbe.hasMedia(pid: snap.ownerPID, service: CallService(steno: source))
        return mediaHold.confirm(key: "\(source.rawValue)#\(snap.ownerPID)", hit: hit)
    }

    deinit {
        timer?.invalidate()
    }
}
