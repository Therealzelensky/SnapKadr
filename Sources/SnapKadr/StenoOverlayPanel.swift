import AppKit
import SwiftUI

@MainActor
final class StenoOverlayPanel {
    static let shared = StenoOverlayPanel()

    private var panel: NSPanel?
    private var hosting: NSHostingView<StenoCardView>?
    private var model = StenoCardModel.sessionStub
    private var onStop: (() -> Void)?
    private var anchorWindowID: UInt32?
    private var followTimer: Timer?

    private init() {}

    func show(model: StenoCardModel, anchorWindowID: UInt32, onStop: @escaping () -> Void) {
        self.model = model
        self.onStop = onStop
        self.anchorWindowID = anchorWindowID
        let panel = ensurePanel()
        hosting?.rootView = StenoCardView(model: model, onStop: { [weak self] in
            self?.onStop?()
        })
        resizeToFit()
        reposition(anchorWindowID: anchorWindowID)
        panel.orderFrontRegardless()
        startFollow()
    }

    func update(model: StenoCardModel) {
        self.model = model
        hosting?.rootView = StenoCardView(model: model, onStop: { [weak self] in
            self?.onStop?()
        })
        resizeToFit()
    }

    func reposition(anchorWindowID: UInt32) {
        self.anchorWindowID = anchorWindowID
        guard let panel else { return }
        guard let bounds = Self.windowBounds(windowID: anchorWindowID) else {
            hide()
            return
        }
        let size = panel.frame.size
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(bounds) }) ?? NSScreen.main else {
            return
        }
        let visible = screen.visibleFrame
        let gap: CGFloat = 12
        var origin = NSPoint(x: bounds.maxX + gap, y: bounds.midY - size.height / 2)
        if origin.x + size.width > visible.maxX {
            origin.x = bounds.minX - gap - size.width
        }
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
    }

    func hide() {
        followTimer?.invalidate()
        followTimer = nil
        panel?.orderOut(nil)
        anchorWindowID = nil
        onStop = nil
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let root = StenoCardView(model: model, onStop: { [weak self] in self?.onStop?() })
        let hosting = NSHostingView(rootView: root)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        self.hosting = hosting

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = true
        panel.sharingType = .none
        panel.contentView = hosting
        self.panel = panel
        return panel
    }

    private func resizeToFit() {
        guard let hosting, let panel else { return }
        let fitting = hosting.fittingSize
        let size = NSSize(
            width: max(240, fitting.width),
            height: max(120, fitting.height)
        )
        var frame = panel.frame
        frame.size = size
        panel.setFrame(frame, display: true)
    }

    private func startFollow() {
        followTimer?.invalidate()
        followTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let id = self.anchorWindowID else { return }
                self.reposition(anchorWindowID: id)
            }
        }
    }

    /// CGWindow bounds in AppKit coordinates (origin bottom-left).
    private static func windowBounds(windowID: UInt32) -> NSRect? {
        let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(windowID)) as? [[String: Any]]
        guard let entry = info?.first,
              let boundsDict = entry[kCGWindowBounds as String] as? [String: CGFloat]
        else { return nil }
        let quartz = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )
        guard quartz.width > 1, quartz.height > 1 else { return nil }
        // Quartz origin is top-left of main display; convert to AppKit.
        guard let screen = NSScreen.screens.first else { return nil }
        let screenH = screen.frame.height
        return NSRect(
            x: quartz.origin.x,
            y: screenH - quartz.origin.y - quartz.height,
            width: quartz.width,
            height: quartz.height
        )
    }
}
