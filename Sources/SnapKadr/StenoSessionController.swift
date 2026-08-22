import AppKit
import Combine
import KadrKit
import StenoKit

@MainActor
final class StenoSessionController: ObservableObject {
    static let shared = StenoSessionController()

    let detector = StenoDetector()
    @Published private(set) var isSessionActive = false
    @Published private(set) var lastProjectURL: URL?
    private var cancellable: AnyCancellable?
    private var promptedWindowID: UInt32?
    private var sessionProjectURL: URL?
    private var sessionWindowID: UInt32?
    private var sessionPID: pid_t = 0
    private var sessionBundleID = ""
    private var hangupWatch: Timer?
    private var hangupTicks = 0
    private var hangupArmedAt: Date?
    private var endingSession = false
    private var sawCapture = false
    private var sleepObserver: NSObjectProtocol?
    private var pendingStenoFinish = false
    private var pendingCall: StenoDetectedCall?

    private init() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.pendingCall != nil {
                    self.clearPendingAccept(resetPrompted: true)
                    return
                }
                self.stopFromUser()
            }
        }
        KadrEngine.shared.onCaptureFinished = { [weak self] result in
            Task { @MainActor in self?.handleCaptureFinished(result) }
        }
    }

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
            clearPendingAccept(resetPrompted: true)
            detector.stop()
        }
    }

    private func handle(_ call: StenoDetectedCall?) {
        guard let call else {
            clearPendingAccept(resetPrompted: true)
            if promptedWindowID != nil {
                SuiteNotchHUD.shared.dismissStenoPrompt()
                promptedWindowID = nil
            }
            return
        }
        if sessionProjectURL != nil { return }
        if pendingCall != nil { return }
        if promptedWindowID == call.windowID { return }
        promptedWindowID = call.windowID
        let title = call.title.isEmpty ? sourceLabel(call.source) : call.title
        SuiteNotchHUD.shared.showStenoPrompt(
            appTitle: title,
            onAccept: { [weak self] in self?.offerVideoStep(call) },
            onLater: { [weak self] in self?.later(call) }
        )
    }

    private func later(_ call: StenoDetectedCall) {
        clearPendingAccept(resetPrompted: false)
        detector.snooze(windowID: call.windowID)
        promptedWindowID = nil
    }

    private func offerVideoStep(_ call: StenoDetectedCall) {
        pendingCall = call
        let title = call.title.isEmpty ? sourceLabel(call.source) : call.title
        SuiteNotchHUD.shared.showStenoVideoPrompt(
            appTitle: title,
            onYes: { [weak self] in self?.beginCapture(call, recordVideo: true) },
            onNo: { [weak self] in self?.beginCapture(call, recordVideo: false) }
        )
    }

    private func beginCapture(_ call: StenoDetectedCall, recordVideo: Bool) {
        pendingCall = nil
        let name = projectName(source: call.source)
        switch KadrEngine.shared.startRecording(
            windowID: CGWindowID(call.windowID),
            projectName: name,
            options: StenoCapture.windowRecord(recordVideo: recordVideo)
        ) {
        case .success(let url):
            SuiteNotchHUD.shared.dismissStenoPrompt()
            sessionProjectURL = url
            lastProjectURL = url
            pendingStenoFinish = true
            sessionWindowID = call.windowID
            if let snap = StenoWindowProbe.snapshots().first(where: { $0.windowID == call.windowID }) {
                sessionPID = snap.ownerPID
                sessionBundleID = snap.bundleID
            } else {
                sessionPID = 0
                sessionBundleID = ""
            }
            isSessionActive = true
            hangupTicks = 0
            startHangupWatch()
            SuiteNotchHUD.shared.showStenoRecording(
                title: L10n.tr("Идёт конспект", "Noting the call"),
                onStop: { [weak self] in self?.stopFromUser() }
            )
            let sidecar = StenoSidecar(source: call.source.rawValue, windowTitle: call.title, createdAt: Date())
            do {
                try StenoSidecarIO.write(sidecar, inProject: url)
            } catch {
                NSLog("Steno sidecar write failed: \(error.localizedDescription)")
            }
        case .failure(let error):
            SuiteNotchHUD.shared.dismissStenoPrompt()
            presentStartFailure(error)
            promptedWindowID = nil
        }
    }

    private func clearPendingAccept(resetPrompted: Bool) {
        if pendingCall != nil {
            pendingCall = nil
            SuiteNotchHUD.shared.dismissStenoPrompt()
        }
        if resetPrompted {
            promptedWindowID = nil
        }
    }

    func stopFromUser() {
        guard isSessionActive, !endingSession else { return }
        endingSession = true
        SuiteNotchHUD.shared.dismissStenoRecording()
        KadrEngine.shared.stopRecording()
        clearSession()
    }

    func openLastProject() {
        guard let url = lastProjectURL else { return }
        revealProjectInFinder(url)
    }

    private func revealProjectInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func presentStartFailure(_ error: Error) {
        let text = error.localizedDescription
        let lower = text.lowercased()
        if lower.contains("screen") || lower.contains("экрана") || lower.contains("запись экрана") {
            SuiteNotchHUD.shared.showStenoFailure(
                message: L10n.tr("Нужен доступ к записи экрана", "Screen Recording access needed"),
                cta: L10n.tr("Настройки", "Settings")
            ) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }
        if lower.contains("already") || lower.contains("уже идёт") || lower.contains("already recording") {
            SuiteNotchHUD.shared.showStenoFailure(
                message: L10n.tr("Уже идёт запись Кадра", "Kadr is already recording"),
                cta: L10n.tr("Понятно", "OK"),
                onCTA: {}
            )
            return
        }
        SuiteNotchHUD.shared.showStenoFailure(
            message: text,
            cta: L10n.tr("Понятно", "OK"),
            onCTA: {}
        )
    }

    private func handleCaptureFinished(_ result: Result<URL, Error>) {
        guard pendingStenoFinish else { return }
        pendingStenoFinish = false
        switch result {
        case .success(let url):
            lastProjectURL = url
            SuiteNotchHUD.shared.dismissStenoRecording()
            revealProjectInFinder(url)
            SuiteNotchHUD.shared.showStenoSaved { [weak self] in
                self?.openLastProject()
            }
        case .failure(let error):
            SuiteNotchHUD.shared.dismissStenoRecording()
            presentStartFailure(error)
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
        // CGWindowList / SCK often blips the captured window right after start.
        hangupArmedAt = Date().addingTimeInterval(5)
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
        if let armed = hangupArmedAt, Date() < armed { return }
        guard let windowID = sessionWindowID else { return }
        let snaps = StenoWindowProbe.snapshots()
        let enabled = StenoSettings.enabledSources
        if let replacement = StenoSessionEnd.replacementWindowID(
            sessionWindowID: windowID,
            sessionPID: sessionPID,
            sessionBundleID: sessionBundleID,
            snapshots: snaps,
            enabled: enabled
        ) {
            sessionWindowID = replacement
            hangupTicks = 0
            return
        }
        if StenoSessionEnd.shouldStop(
            sessionWindowID: windowID,
            sessionPID: sessionPID,
            sessionBundleID: sessionBundleID,
            snapshots: snaps,
            enabled: enabled
        ) {
            hangupTicks += 1
            if hangupTicks >= 3 {
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
        SuiteNotchHUD.shared.dismissStenoRecording()
        if let url = sessionProjectURL {
            lastProjectURL = url
        }
        sessionProjectURL = nil
        sessionWindowID = nil
        sessionPID = 0
        sessionBundleID = ""
        isSessionActive = false
        promptedWindowID = nil
        hangupTicks = 0
        sawCapture = false
        endingSession = false
        hangupArmedAt = nil
    }
}
