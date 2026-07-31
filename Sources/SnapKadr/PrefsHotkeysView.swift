import AppKit
import Carbon
import SnapKit
import SwiftUI

struct PrefsHotkeysView: View {
    @ObservedObject private var suiteHotkeys = SuiteHotkeyMonitor.shared
    @State private var recording: AppSettings.Hotkey?
    @State private var mon: Any?
    @State private var rowLabels: [AppSettings.Hotkey: String] = [:]
    @State private var recordingKadr: SuiteKadrHotkey?
    @State private var kadrMon: Any?
    @State private var kadrLabels: [SuiteKadrHotkey: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            statusBanner

            VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
                SuiteSectionHeader(title: L10n.tr("Щёлк", "Snap"))
                SuiteCard {
                    VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                        ForEach(AppSettings.Hotkey.prefsOrder, id: \.self) { hotkey in
                            hotkeyRow(hotkey)
                        }

                        Button(L10n.tr("Сбросить по умолчанию", "Reset to Defaults")) {
                            resetDefaults()
                        }
                        .controlSize(.small)
                    }
                }
            }

            VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
                SuiteSectionHeader(title: L10n.tr("Кадр", "Kadr"))
                SuiteCard {
                    VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                        ForEach(SuiteKadrHotkey.prefsOrder, id: \.self) { hotkey in
                            kadrHotkeyRow(hotkey)
                        }

                        Button(L10n.tr("Сбросить по умолчанию", "Reset to Defaults")) {
                            SuiteKadrHotkey.resetAll()
                            refreshKadrLabels()
                            SuiteHotkeyMonitor.shared.reloadKadrHotkeys()
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        .suiteAppear()
        .onAppear {
            refreshLabels()
            refreshKadrLabels()
        }
        .onDisappear {
            stopRecording()
            stopKadrRecording()
        }
    }

    private var statusBanner: some View {
        SuiteCard {
            HStack(spacing: 10) {
                Image(systemName: suiteHotkeys.isPausedForCompanionSnap ? "pause.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(suiteHotkeys.isPausedForCompanionSnap ? SuiteTheme.snapAccent : Color.green)
                Text(
                    suiteHotkeys.isPausedForCompanionSnap
                        ? L10n.tr("Пауза: запущен Щёлк", "Paused: Snap is running")
                        : L10n.tr("Горячие клавиши suite активны", "Suite hotkeys active")
                )
                .foregroundStyle(SuiteTheme.textPrimary)
                Spacer()
                Button(L10n.tr("Обновить", "Refresh")) {
                    SuiteHotkeyMonitor.shared.refreshCoexistence()
                }
                .controlSize(.small)
            }
        }
    }

    private func hotkeyRow(_ hotkey: AppSettings.Hotkey) -> some View {
        HStack {
            Text(hotkey.title)
                .foregroundStyle(SuiteTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(rowLabels[hotkey] ?? hotkey.display) {
                beginRecording(hotkey)
            }
            .frame(minWidth: 100)
            .controlSize(.small)
            Button("×") {
                hotkey.clear()
                refreshLabels()
                SuiteHotkeyMonitor.shared.refreshCoexistence()
            }
            .controlSize(.small)
            .disabled(!hotkey.isAssigned && recording != hotkey)
        }
    }

    private func kadrHotkeyRow(_ hotkey: SuiteKadrHotkey) -> some View {
        HStack {
            Text(hotkey.title)
                .foregroundStyle(SuiteTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(kadrLabels[hotkey] ?? hotkey.display) {
                beginKadrRecording(hotkey)
            }
            .frame(minWidth: 100)
            .controlSize(.small)
            Button("×") {
                hotkey.clear()
                refreshKadrLabels()
                SuiteHotkeyMonitor.shared.reloadKadrHotkeys()
            }
            .controlSize(.small)
            .disabled(!hotkey.isAssigned && recordingKadr != hotkey)
        }
    }

    private func refreshLabels() {
        var map: [AppSettings.Hotkey: String] = [:]
        for h in AppSettings.Hotkey.prefsOrder {
            map[h] = h.display
        }
        rowLabels = map
    }

    private func refreshKadrLabels() {
        var map: [SuiteKadrHotkey: String] = [:]
        for h in SuiteKadrHotkey.prefsOrder {
            map[h] = h.display
        }
        kadrLabels = map
    }

    private func beginRecording(_ hotkey: AppSettings.Hotkey) {
        stopRecording()
        stopKadrRecording()
        recording = hotkey
        rowLabels[hotkey] = L10n.tr("Нажмите…", "Press…")
        mon = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = carbonMods(from: event.modifierFlags)
            let key = UInt32(event.keyCode)
            if key == UInt32(kVK_Escape) {
                Task { @MainActor in self.stopRecording(); self.refreshLabels() }
                return nil
            }
            guard mods != 0 else { return event }
            AppSettings.setHotkey(hotkey, keyCode: key, modifiers: mods)
            Task { @MainActor in
                self.stopRecording()
                self.refreshLabels()
                SuiteHotkeyMonitor.shared.refreshCoexistence()
            }
            return nil
        }
    }

    private func beginKadrRecording(_ hotkey: SuiteKadrHotkey) {
        stopRecording()
        stopKadrRecording()
        recordingKadr = hotkey
        kadrLabels[hotkey] = L10n.tr("Нажмите…", "Press…")
        kadrMon = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = carbonMods(from: event.modifierFlags)
            let key = UInt32(event.keyCode)
            if key == UInt32(kVK_Escape) {
                Task { @MainActor in self.stopKadrRecording(); self.refreshKadrLabels() }
                return nil
            }
            guard mods != 0 else { return event }
            hotkey.set(keyCode: key, modifiers: mods)
            Task { @MainActor in
                self.stopKadrRecording()
                self.refreshKadrLabels()
                SuiteHotkeyMonitor.shared.reloadKadrHotkeys()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let mon {
            NSEvent.removeMonitor(mon)
            self.mon = nil
        }
        recording = nil
    }

    private func stopKadrRecording() {
        if let kadrMon {
            NSEvent.removeMonitor(kadrMon)
            self.kadrMon = nil
        }
        recordingKadr = nil
    }

    private func resetDefaults() {
        for hotkey in AppSettings.Hotkey.allCases {
            defaultsRemove(hotkey)
        }
        refreshLabels()
        SuiteHotkeyMonitor.shared.refreshCoexistence()
    }

    private func defaultsRemove(_ hotkey: AppSettings.Hotkey) {
        let d = UserDefaults.standard
        d.removeObject(forKey: "hotkey.\(hotkey.rawValue).key")
        d.removeObject(forKey: "hotkey.\(hotkey.rawValue).mods")
        d.removeObject(forKey: "hotkey.\(hotkey.rawValue).cleared")
    }

    private func carbonMods(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        return mods
    }
}
