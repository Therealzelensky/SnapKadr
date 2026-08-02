import AppKit
import SnapKit
import KadrKit
import SwiftUI

/// Single suite status item — Kadr MenuBarIcon.
/// LMB → Kadr-style control panel (Snap + Kadr). RMB/⌥ → in-process capture bar.
@MainActor
final class SuiteStatusController: NSObject {
    private let item: NSStatusItem
    private let onPreferences: () -> Void
    private let onQuit: () -> Void

    private var panel: NSPanel?
    private var hosting: NSHostingView<SuiteControlPanelView>?
    private var eventMonitor: Any?
    private let panelWidth: CGFloat = 320

    init(onPreferences: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onPreferences = onPreferences
        self.onQuit = onQuit
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = item.button {
            button.image = AppBranding.menuBarIcon
            button.image?.isTemplate = true
            button.toolTip = AppBranding.displayName
            if AppBranding.isBeta {
                button.title = "β"
                button.imagePosition = .imageLeading
            }
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let flags = event?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
        // RMB or Option+LMB → capture bar. Plain LMB must not treat stale Option from another chord.
        if event?.type == .rightMouseUp
            || (event?.type == .leftMouseUp && flags.contains(.option)) {
            closePanel()
            restoreSystemCursor()
            KadrEngine.shared.openCaptureBar()
            return
        }
        togglePanel()
    }

    private func togglePanel() {
        if panel?.isVisible == true {
            closePanel()
        } else {
            openPanel()
        }
    }

    private func openPanel() {
        // Stuck area/OCR capture leaves NSCursor.hide() active — panel open makes it obvious.
        restoreSystemCursor()
        let panel = ensurePanel()
        refreshPanelRoot()
        resizePanelToFit()
        positionPanel(panel)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            let loc = NSEvent.mouseLocation
            if !panel.frame.contains(loc) {
                if let button = self.item.button, let window = button.window {
                    let buttonFrame = button.convert(button.bounds, to: nil)
                    let screenFrame = window.convertToScreen(buttonFrame)
                    if screenFrame.contains(loc) { return }
                }
                DispatchQueue.main.async { self.closePanel() }
            }
        }
    }

    private func closePanel() {
        panel?.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    /// Undo a leaked `NSCursor.hide()` from Snap area overlay / cancelled capture.
    private func restoreSystemCursor() {
        SnapEngine.shared.cancelActiveCapture()
        NSCursor.unhide()
        NSCursor.arrow.set()
    }

    private func makePanelRoot() -> SuiteControlPanelView {
        SuiteControlPanelView(
            onAction: { [weak self] action in
                self?.handle(action)
            },
            onLayoutNeeded: { [weak self] in
                self?.resizePanelToFit()
                if let panel = self?.panel {
                    self?.positionPanel(panel)
                }
            }
        )
    }

    private func refreshPanelRoot() {
        hosting?.rootView = makePanelRoot()
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let hosting = NSHostingView(rootView: makePanelRoot())
        hosting.frame = NSRect(x: 0, y: 0, width: panelWidth, height: 420)
        self.hosting = hosting

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = true
        panel.sharingType = .none

        let chrome = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: 420))
        chrome.wantsLayer = true
        chrome.layer?.cornerRadius = SuiteTheme.radiusPanel
        chrome.layer?.masksToBounds = true
        chrome.layer?.backgroundColor = NSColor(calibratedRed: 0.043, green: 0.051, blue: 0.063, alpha: 1).cgColor

        hosting.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: chrome.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: chrome.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: chrome.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: chrome.bottomAnchor)
        ])

        panel.contentView = chrome
        self.panel = panel
        return panel
    }

    private func resizePanelToFit() {
        guard let hosting, let panel else { return }
        let fitting = hosting.fittingSize
        let height = max(320, min(640, fitting.height > 1 ? fitting.height : 420))
        var frame = panel.frame
        let top = frame.maxY
        frame.size = NSSize(width: panelWidth, height: height)
        if frame.origin.y == 0, frame.maxY == height {
            // first layout — origin set in positionPanel
        } else {
            frame.origin.y = top - height
        }
        panel.setFrame(frame, display: true)
        panel.contentView?.frame = NSRect(origin: .zero, size: frame.size)
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let button = item.button, let buttonWindow = button.window else {
            if let screen = NSScreen.main {
                let f = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(x: f.maxX - panelWidth - 20, y: f.maxY - panel.frame.height - 8))
            }
            return
        }
        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = buttonWindow.convertToScreen(buttonFrame)
        let x = min(max(screenFrame.midX - panelWidth / 2, screenFrame.minX), screenFrame.maxX - panelWidth)
        let y = screenFrame.minY - panel.frame.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func handle(_ action: SuitePanelAction) {
        closePanel()
        switch action {
        case .snapArea: SnapEngine.shared.captureArea()
        case .snapFull: SnapEngine.shared.captureFull()
        case .snapWindow: SnapEngine.shared.captureActiveWindow()
        case .kadrCapture: KadrEngine.shared.openCaptureBar()
        case .kadrDisplay: KadrEngine.shared.recordDisplay()
        case .openProject: KadrEngine.shared.openProject()
        case .openRecent(let url): KadrEngine.shared.openProject(at: url)
        case .preferences: onPreferences()
        case .quit: onQuit()
        }
    }
}
