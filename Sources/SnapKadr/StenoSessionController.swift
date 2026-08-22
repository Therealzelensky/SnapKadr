import AppKit
import Combine
import KadrKit
import StenoKit

@MainActor
final class StenoSessionController: ObservableObject {
    static let shared = StenoSessionController()

    let detector = StenoDetector()
    @Published private(set) var isSessionActive = false
    private var cancellable: AnyCancellable?
    private var promptedWindowID: UInt32?
    private var sessionProjectURL: URL?
    private var sessionWindowID: UInt32?
    private var hangupWatch: Timer?
    private var hangupTicks = 0
    private var endingSession = false
    private var sawCapture = false

    private init() {}

    func start() {
        if cancellable == nil {
            cancellable = detector.$activeCall
                .removeDuplicates()
                .sink { [weak self] call in
                    self?.handle(call)
                }
        }
        applyEnabledFromSettings()
    }

    func applyEnabledFromSettings() {
        if StenoSettings.isEnabled {
            detector.start()
        } else {
            detector.stop()
        }
    }

    private func handle(_ call: StenoDetectedCall?) {
        guard let call else {
            if promptedWindowID != nil {
                SuiteNotchHUD.shared.dismissStenoPrompt()
                promptedWindowID = nil
            }
            return
        }
        if sessionProjectURL != nil { return }
        if promptedWindowID == call.windowID { return }
        promptedWindowID = call.windowID
        let title = call.title.isEmpty ? sourceLabel(call.source) : call.title
        SuiteNotchHUD.shared.showStenoPrompt(
            appTitle: title,
            onAccept: { [weak self] in self?.accept(call) },
            onLater: { [weak self] in self?.later(call) }
        )
    }

    private func later(_ call: StenoDetectedCall) {
        detector.snooze(windowID: call.windowID)
        promptedWindowID = nil
    }

    private func accept(_ call: StenoDetectedCall) {
        let name = projectName(source: call.source)
        switch KadrEngine.shared.startRecording(
            windowID: CGWindowID(call.windowID),
            projectName: name,
            options: StenoCapture.windowRecord()
        ) {
        case .success(let url):
            sessionProjectURL = url
            sessionWindowID = call.windowID
            isSessionActive = true
            hangupTicks = 0
            startHangupWatch()
            let sidecar = StenoSidecar(source: call.source.rawValue, windowTitle: call.title, createdAt: Date())
            do {
                try StenoSidecarIO.write(sidecar, inProject: url)
            } catch {
                NSLog("Steno sidecar write failed: \(error.localizedDescription)")
            }
        case .failure(let error):
            NSLog("Steno start failed: \(error.localizedDescription)")
            promptedWindowID = nil
        }
    }

    private func projectName(source: StenoSource) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Стено \(sourceLabel(source)) \(formatter.string(from: Date()))"
    }

    private func sourceLabel(_ source: StenoSource) -> String {
        switch source {
        case .zoom: return "Zoom"
        case .googleMeet: return "Meet"
        case .telegram: return "Telegram"
        case .telemost: return "Телемост"
        case .bitrixSync: return "Синк"
        }
    }

    private func startHangupWatch() {
        hangupWatch?.invalidate()
        hangupTicks = 0
        endingSession = false
        sawCapture = false
        hangupWatch = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.watchHangup() }
        }
    }

    private func watchHangup() {
        guard isSessionActive, !endingSession else { return }
        let capturing = KadrEngine.shared.isRecording
        if capturing { sawCapture = true }
        if sawCapture, !capturing {
            clearSession()
            return
        }
        guard let windowID = sessionWindowID else { return }
        let snaps = StenoWindowProbe.snapshots()
        if StenoSessionEnd.shouldStop(
            sessionWindowID: windowID,
            snapshots: snaps,
            enabled: StenoSettings.enabledSources
        ) {
            hangupTicks += 1
            if hangupTicks >= 2 {
                endSessionBecauseCallEnded()
            }
        } else {
            hangupTicks = 0
        }
    }

    private func endSessionBecauseCallEnded() {
        endingSession = true
        KadrEngine.shared.stopRecording()
        clearSession()
    }

    private func clearSession() {
        hangupWatch?.invalidate()
        hangupWatch = nil
        sessionProjectURL = nil
        sessionWindowID = nil
        isSessionActive = false
        promptedWindowID = nil
        hangupTicks = 0
        sawCapture = false
        endingSession = false
    }
}
