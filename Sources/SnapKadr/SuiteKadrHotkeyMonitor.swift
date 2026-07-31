import AppKit
import Carbon

/// Carbon hotkeys for Kadr deep links. Signature `'SKKD'` — separate from Snap `'SKHK'`.
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
                    CompanionLaunch.openKadr(path: action.path)
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
