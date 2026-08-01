import AppKit
import Carbon
import KadrKit

/// Carbon hotkeys for in-process KadrEngine. Signature `'SKKD'` — separate from Snap `'SKHK'`.
@MainActor
final class SuiteKadrHotkeyMonitor {
    static let signature = OSType(0x534B4B44) // 'SKKD'

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private static weak var shared: SuiteKadrHotkeyMonitor?

    func start() {
        stop()
        Self.shared = self

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard err == noErr,
                      hotKeyID.signature == SuiteKadrHotkeyMonitor.signature,
                      let action = SuiteKadrHotkey.from(carbonID: hotKeyID.id)
                else { return noErr }
                DispatchQueue.main.async {
                    SuiteKadrHotkeyMonitor.dispatch(action)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard status == noErr else { return }
        registerAll()
    }

    func reload() {
        start()
    }

    func stop() {
        unregisterAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        if Self.shared === self {
            Self.shared = nil
        }
    }

    static func dispatch(_ action: SuiteKadrHotkey) {
        let engine = KadrEngine.shared
        switch action {
        case .capture: engine.openCaptureBar()
        case .display: engine.recordDisplay()
        case .area: engine.recordArea()
        case .window: engine.recordWindow()
        case .device: engine.recordDevice()
        case .stop: engine.stopRecording()
        case .newProject: engine.newProject()
        case .openProject: engine.openProject()
        case .snapshot: engine.takeSnapshot()
        case .show: engine.showHome()
        }
    }

    private func registerAll() {
        unregisterAll()
        for hotkey in SuiteKadrHotkey.prefsOrder {
            guard hotkey.isAssigned, hotkey.keyCode > 0 else { continue }
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: hotkey.carbonID)
            let status = RegisterEventHotKey(
                hotkey.keyCode,
                hotkey.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr {
                hotKeyRefs.append(ref)
            }
        }
    }

    private func unregisterAll() {
        for ref in hotKeyRefs {
            if let ref { UnregisterEventHotKey(ref) }
        }
        hotKeyRefs.removeAll()
    }
}
