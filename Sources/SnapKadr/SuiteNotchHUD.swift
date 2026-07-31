import AppKit
import NotchHUDKit

/// Thin NotchHUDKit wrapper for suite notification tests (not a Snap NotchHUD copy).
@MainActor
final class SuiteNotchHUD {
    static let shared = SuiteNotchHUD()
    private let shell = NotchHUDShell()

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
}
