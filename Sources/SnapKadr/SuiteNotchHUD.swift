import AppKit
import NotchHUDKit

/// Thin NotchHUDKit wrapper for suite notification tests (not a Snap NotchHUD copy).
@MainActor
final class SuiteNotchHUD {
    static let shared = SuiteNotchHUD()
    private let shell = NotchHUDShell()
    private let promptShell = NotchHUDShell(height: 56, ignoresMouseEvents: false)
    private let recordingShell = NotchHUDShell(height: 56, ignoresMouseEvents: false)
    private let progressShell = NotchHUDShell(height: 56, ignoresMouseEvents: true)
    private let promptActions = StenoPromptActions()
    private let recordingActions = StenoRecordingActions()
    private var recordingDetailLabel: NSTextField?

    static func shareStatusLine(active: Bool, failed: Bool, recordShare: Bool) -> String {
        guard recordShare else { return "" }
        if failed { return L10n.tr("Шару не записали", "Share not recorded") }
        if active { return L10n.tr("Шара пишется", "Share recording") }
        return L10n.tr("Шары нет", "No share")
    }

    func showTest() {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: nil)
        icon.contentTintColor = NSColor(calibratedRed: 0.753, green: 0.149, blue: 0.827, alpha: 1)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let label = NSTextField(labelWithString: L10n.tr("Тест уведомления", "Notification test"))
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.isBezeled = false
        label.drawsBackground = false
        row.addArrangedSubview(icon)
        row.addArrangedSubview(label)
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 42))
        row.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(row)
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            row.centerYAnchor.constraint(equalTo: host.centerYAnchor)
        ])
        shell.contentView = host
        shell.present(size: NSSize(width: 220, height: 42), on: NSScreen.main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.shell.dismiss()
        }
    }

    func showStenoPrompt(
        appTitle: String,
        onAccept: @escaping () -> Void,
        onLater: @escaping () -> Void
    ) {
        promptActions.onAccept = {
            onAccept()
        }
        promptActions.onLater = { [weak self] in
            self?.dismissStenoPrompt {
                onLater()
            }
        }

        let clipped: String = {
            if appTitle.count <= 28 { return appTitle }
            return String(appTitle.prefix(27)) + "…"
        }()

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
        icon.contentTintColor = NSColor(calibratedRed: 0.753, green: 0.149, blue: 0.827, alpha: 1)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let title = NSTextField(labelWithString: L10n.tr("Конспектировать этот звонок?", "Note this call?"))
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .white
        title.isBezeled = false
        title.drawsBackground = false

        let subtitle = NSTextField(labelWithString: clipped)
        subtitle.font = .systemFont(ofSize: 11, weight: .regular)
        subtitle.textColor = NSColor.white.withAlphaComponent(0.55)
        subtitle.isBezeled = false
        subtitle.drawsBackground = false

        let textCol = NSStackView(views: [title, subtitle])
        textCol.orientation = .vertical
        textCol.alignment = .leading
        textCol.spacing = 1

        let later = NSButton(title: L10n.tr("Не сейчас", "Not now"), target: promptActions, action: #selector(StenoPromptActions.later))
        later.bezelStyle = .rounded
        later.controlSize = .small
        later.font = .systemFont(ofSize: 12)
        later.keyEquivalent = "\u{1b}"

        let accept = NSButton(title: L10n.tr("Да", "Yes"), target: promptActions, action: #selector(StenoPromptActions.accept))
        accept.bezelStyle = .rounded
        accept.controlSize = .small
        accept.font = .systemFont(ofSize: 12, weight: .semibold)
        accept.keyEquivalent = "\r"

        let row = NSStackView(views: [icon, textCol, later, accept])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.setHuggingPriority(.defaultHigh, for: .horizontal)

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 56))
        row.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: host.centerYAnchor)
        ])

        promptShell.contentView = host
        promptShell.present(size: NSSize(width: 420, height: 56), on: NSScreen.main)
    }

    func showStenoVideoPrompt(
        appTitle: String,
        onYes: @escaping () -> Void,
        onNo: @escaping () -> Void
    ) {
        promptActions.onAccept = {
            onYes()
        }
        promptActions.onLater = { [weak self] in
            self?.dismissStenoPrompt {
                onNo()
            }
        }

        let clipped: String = {
            if appTitle.count <= 28 { return appTitle }
            return String(appTitle.prefix(27)) + "…"
        }()

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "video", accessibilityDescription: nil)
        icon.contentTintColor = NSColor(calibratedRed: 0.753, green: 0.149, blue: 0.827, alpha: 1)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let title = NSTextField(labelWithString: L10n.tr("Записать видео окна?", "Record the call window?"))
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .white
        title.isBezeled = false
        title.drawsBackground = false

        let subtitle = NSTextField(labelWithString: clipped)
        subtitle.font = .systemFont(ofSize: 11, weight: .regular)
        subtitle.textColor = NSColor.white.withAlphaComponent(0.55)
        subtitle.isBezeled = false
        subtitle.drawsBackground = false

        let textCol = NSStackView(views: [title, subtitle])
        textCol.orientation = .vertical
        textCol.alignment = .leading
        textCol.spacing = 1

        let no = NSButton(title: L10n.tr("Нет", "No"), target: promptActions, action: #selector(StenoPromptActions.later))
        no.bezelStyle = .rounded
        no.controlSize = .small
        no.font = .systemFont(ofSize: 12)
        no.keyEquivalent = "\u{1b}"

        let yes = NSButton(title: L10n.tr("Да", "Yes"), target: promptActions, action: #selector(StenoPromptActions.accept))
        yes.bezelStyle = .rounded
        yes.controlSize = .small
        yes.font = .systemFont(ofSize: 12, weight: .semibold)
        yes.keyEquivalent = "\r"

        let row = NSStackView(views: [icon, textCol, no, yes])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.setHuggingPriority(.defaultHigh, for: .horizontal)

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 56))
        row.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: host.centerYAnchor)
        ])

        promptShell.contentView = host
        promptShell.present(size: NSSize(width: 420, height: 56), on: NSScreen.main)
    }

    func dismissStenoPrompt(completion: (() -> Void)? = nil) {
        promptShell.dismiss(completion: completion)
    }

    func showStenoRecording(title: String, detail: String = "", onStop: @escaping () -> Void) {
        recordingActions.onStop = {
            onStop()
        }
        recordingActions.onContinue = {}

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: nil)
        icon.contentTintColor = NSColor(calibratedRed: 0.937, green: 0.267, blue: 0.267, alpha: 1)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.isBezeled = false
        label.drawsBackground = false

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 11, weight: .regular)
        detailLabel.textColor = NSColor.white.withAlphaComponent(0.55)
        detailLabel.isBezeled = false
        detailLabel.drawsBackground = false
        detailLabel.isHidden = detail.isEmpty
        recordingDetailLabel = detailLabel

        let textCol = NSStackView(views: [label, detailLabel])
        textCol.orientation = .vertical
        textCol.alignment = .leading
        textCol.spacing = 1

        let stop = NSButton(title: L10n.tr("Стоп", "Stop"), target: recordingActions, action: #selector(StenoRecordingActions.stop))
        stop.bezelStyle = .rounded
        stop.controlSize = .small
        stop.font = .systemFont(ofSize: 12, weight: .semibold)

        let row = NSStackView(views: [icon, textCol, stop])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.setHuggingPriority(.defaultHigh, for: .horizontal)

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 56))
        row.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: host.centerYAnchor)
        ])

        recordingShell.contentView = host
        recordingShell.present(size: NSSize(width: 360, height: 56), on: NSScreen.main)
    }

    func showStenoStopConfirm(
        hangup: Bool,
        onConfirm: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        recordingDetailLabel = nil
        recordingActions.onStop = {
            onConfirm()
        }
        recordingActions.onContinue = {
            onContinue()
        }

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: hangup ? "phone.down.fill" : "stop.circle", accessibilityDescription: nil)
        icon.contentTintColor = NSColor(calibratedRed: 0.937, green: 0.267, blue: 0.267, alpha: 1)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let title = NSTextField(labelWithString: L10n.tr("Остановить конспект?", "Stop noting?"))
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .white
        title.isBezeled = false
        title.drawsBackground = false

        let subtitle = NSTextField(labelWithString: hangup
            ? L10n.tr("Похоже, звонок закончился", "Looks like the call ended")
            : L10n.tr("Запись ещё идёт", "Recording is still running"))
        subtitle.font = .systemFont(ofSize: 11, weight: .regular)
        subtitle.textColor = NSColor.white.withAlphaComponent(0.55)
        subtitle.isBezeled = false
        subtitle.drawsBackground = false

        let textCol = NSStackView(views: [title, subtitle])
        textCol.orientation = .vertical
        textCol.alignment = .leading
        textCol.spacing = 1

        let keepGoing = NSButton(
            title: L10n.tr("Продолжить", "Keep going"),
            target: recordingActions,
            action: #selector(StenoRecordingActions.keepGoing)
        )
        keepGoing.bezelStyle = .rounded
        keepGoing.controlSize = .small
        keepGoing.font = .systemFont(ofSize: 12)
        keepGoing.keyEquivalent = "\u{1b}"

        let stop = NSButton(
            title: L10n.tr("Остановить", "Stop"),
            target: recordingActions,
            action: #selector(StenoRecordingActions.stop)
        )
        stop.bezelStyle = .rounded
        stop.controlSize = .small
        stop.font = .systemFont(ofSize: 12, weight: .semibold)
        if hangup {
            keepGoing.keyEquivalent = "\r"
        } else {
            stop.keyEquivalent = "\r"
        }

        let row = NSStackView(views: [icon, textCol, keepGoing, stop])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.setHuggingPriority(.defaultHigh, for: .horizontal)

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 56))
        row.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: host.centerYAnchor)
        ])

        recordingShell.contentView = host
        recordingShell.present(size: NSSize(width: 440, height: 56), on: NSScreen.main)
    }

    func updateStenoRecording(detail: String) {
        guard let recordingDetailLabel else { return }
        if recordingDetailLabel.stringValue == detail,
           recordingDetailLabel.isHidden == detail.isEmpty {
            return
        }
        recordingDetailLabel.stringValue = detail
        recordingDetailLabel.isHidden = detail.isEmpty
    }

    func dismissStenoRecording(completion: (() -> Void)? = nil) {
        recordingDetailLabel = nil
        recordingShell.dismiss(completion: completion)
    }

    func showStenoPostSessionProgress(stageTitle: String) {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "waveform.badge.magnifyingglass", accessibilityDescription: nil)
        icon.contentTintColor = NSColor(calibratedRed: 0.753, green: 0.149, blue: 0.827, alpha: 1)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = NSTextField(labelWithString: stageTitle)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.isBezeled = false
        label.drawsBackground = false

        let row = NSStackView(views: [icon, label])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 56))
        row.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: host.centerYAnchor)
        ])

        progressShell.contentView = host
        progressShell.present(size: NSSize(width: 360, height: 56), on: NSScreen.main)
    }

    func dismissStenoPostSessionProgress(completion: (() -> Void)? = nil) {
        progressShell.dismiss(completion: completion)
    }

    func showStenoFailure(message: String, cta: String, onCTA: @escaping () -> Void) {
        promptActions.onAccept = { [weak self] in
            self?.dismissStenoPrompt {
                onCTA()
            }
        }
        promptActions.onLater = { [weak self] in
            self?.dismissStenoPrompt()
        }

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        icon.contentTintColor = NSColor(calibratedRed: 0.937, green: 0.267, blue: 0.267, alpha: 1)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.isBezeled = false
        label.drawsBackground = false
        label.maximumNumberOfLines = 2
        label.preferredMaxLayoutWidth = 240

        let action = NSButton(title: cta, target: promptActions, action: #selector(StenoPromptActions.accept))
        action.bezelStyle = .rounded
        action.controlSize = .small
        action.font = .systemFont(ofSize: 12, weight: .semibold)

        let row = NSStackView(views: [icon, label, action])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 56))
        row.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: host.centerYAnchor)
        ])
        promptShell.contentView = host
        promptShell.present(size: NSSize(width: 420, height: 56), on: NSScreen.main)
    }

    func showStenoSaved(onOpen: @escaping () -> Void) {
        promptActions.onAccept = { [weak self] in
            self?.dismissStenoPrompt {
                onOpen()
            }
        }
        promptActions.onLater = { [weak self] in
            self?.dismissStenoPrompt()
        }

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        icon.contentTintColor = NSColor(calibratedRed: 0.345, green: 0.80, blue: 0.40, alpha: 1)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)

        let label = NSTextField(labelWithString: L10n.tr("Конспект сохранён", "Notes saved"))
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.isBezeled = false
        label.drawsBackground = false

        let open = NSButton(
            title: L10n.tr("В Finder", "In Finder"),
            target: promptActions,
            action: #selector(StenoPromptActions.accept)
        )
        open.bezelStyle = .rounded
        open.controlSize = .small
        open.font = .systemFont(ofSize: 12, weight: .semibold)

        let row = NSStackView(views: [icon, label, open])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 56))
        row.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: host.centerYAnchor)
        ])
        promptShell.contentView = host
        promptShell.present(size: NSSize(width: 320, height: 56), on: NSScreen.main)
    }

    func showCloudUploadDeferred() {
        showStenoFailure(
            message: L10n.tr("загрузить позже", "upload later"),
            cta: L10n.tr("Понятно", "OK"),
            onCTA: {}
        )
    }

    func showCloudAuthRequired() {
        showStenoFailure(
            message: L10n.tr("Нужно снова войти в облако", "Cloud sign-in required"),
            cta: L10n.tr("Открыть Общие", "Open General"),
            onCTA: {
                NotificationCenter.default.post(name: .showPrefsGeneralTab, object: nil)
            }
        )
    }

    func presentDeferredUploadToast() {
        showCloudUploadDeferred()
    }

    func presentAuthRequiredToast() {
        showCloudAuthRequired()
    }
}

@MainActor
private final class StenoPromptActions: NSObject {
    var onLater: () -> Void = {}
    var onAccept: () -> Void = {}

    @objc func later() { onLater() }
    @objc func accept() { onAccept() }
}

@MainActor
private final class StenoRecordingActions: NSObject {
    var onStop: () -> Void = {}
    var onContinue: () -> Void = {}

    @objc func stop() { onStop() }
    @objc func keepGoing() { onContinue() }
}
