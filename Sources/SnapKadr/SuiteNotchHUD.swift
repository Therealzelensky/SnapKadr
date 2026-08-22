import AppKit
import NotchHUDKit

/// Thin NotchHUDKit wrapper for suite notification tests (not a Snap NotchHUD copy).
@MainActor
final class SuiteNotchHUD {
    static let shared = SuiteNotchHUD()
    private let shell = NotchHUDShell()
    private let promptShell = NotchHUDShell(height: 56, ignoresMouseEvents: false)
    private let recordingShell = NotchHUDShell(height: 56, ignoresMouseEvents: false)
    private let promptActions = StenoPromptActions()
    private let recordingActions = StenoRecordingActions()

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
        promptActions.onAccept = { [weak self] in
            self?.dismissStenoPrompt {
                onAccept()
            }
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

    func dismissStenoPrompt(completion: (() -> Void)? = nil) {
        promptShell.dismiss(completion: completion)
    }

    func showStenoRecording(title: String, onStop: @escaping () -> Void) {
        recordingActions.onStop = { [weak self] in
            self?.dismissStenoRecording {
                onStop()
            }
        }

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

        let stop = NSButton(title: L10n.tr("Стоп", "Stop"), target: recordingActions, action: #selector(StenoRecordingActions.stop))
        stop.bezelStyle = .rounded
        stop.controlSize = .small
        stop.font = .systemFont(ofSize: 12, weight: .semibold)

        let row = NSStackView(views: [icon, label, stop])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.setHuggingPriority(.defaultHigh, for: .horizontal)

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 56))
        row.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: host.centerYAnchor)
        ])

        recordingShell.contentView = host
        recordingShell.present(size: NSSize(width: 320, height: 56), on: NSScreen.main)
    }

    func dismissStenoRecording(completion: (() -> Void)? = nil) {
        recordingShell.dismiss(completion: completion)
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

    @objc func stop() { onStop() }
}
