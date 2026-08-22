import AppKit
import Combine
import KadrKit
import StenoKit

@MainActor
final class StenoSessionController {
    static let shared = StenoSessionController()

    let detector = StenoDetector()
    private var cancellable: AnyCancellable?
    private var promptedWindowID: UInt32?
    private var sessionProjectURL: URL?

    private init() {}

    func start() {
        cancellable = detector.$activeCall
            .removeDuplicates()
            .sink { [weak self] call in
                self?.handle(call)
            }
        detector.start()
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
        guard let url = KadrEngine.shared.startRecording(
            windowID: CGWindowID(call.windowID),
            projectName: name
        ) else {
            promptedWindowID = nil
            return
        }
        sessionProjectURL = url
        let sidecar = StenoSidecar(source: call.source.rawValue, windowTitle: call.title, createdAt: Date())
        do {
            try StenoSidecarIO.write(sidecar, inProject: url)
        } catch {
            NSLog("Steno sidecar write failed: \(error.localizedDescription)")
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
}
