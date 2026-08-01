import Carbon
import Foundation
import SnapKit

/// Suite-owned Kadr hotkey bindings (empty defaults). Dispatch via `KadrEngine` in-process.
enum SuiteKadrHotkey: String, CaseIterable, Hashable {
    case capture, display, area, window, device, stop, newProject, openProject, snapshot, show

    static var prefsOrder: [SuiteKadrHotkey] {
        [.capture, .display, .area, .window, .device, .stop, .newProject, .openProject, .snapshot, .show]
    }

    /// Legacy host path name (kept for prefs labels / migration); dispatch uses `SuiteKadrHotkeyMonitor.dispatch`.
    var path: String {
        switch self {
        case .capture: return "capture"
        case .display: return "display"
        case .area: return "area"
        case .window: return "window"
        case .device: return "device"
        case .stop: return "stop"
        case .newProject: return "new"
        case .openProject: return "open"
        case .snapshot: return "snapshot"
        case .show: return "show"
        }
    }

    var title: String {
        switch self {
        case .capture: return L10n.tr("Панель захвата", "Capture bar")
        case .display: return L10n.tr("Запись экрана", "Record display")
        case .area: return L10n.tr("Запись области", "Record area")
        case .window: return L10n.tr("Запись окна", "Record window")
        case .device: return L10n.tr("Запись устройства", "Record device")
        case .stop: return L10n.tr("Стоп записи", "Stop recording")
        case .newProject: return L10n.tr("Новый проект", "New project")
        case .openProject: return L10n.tr("Открыть проект", "Open project")
        case .snapshot: return L10n.tr("Снимок кадра", "Snapshot")
        case .show: return L10n.tr("Показать Кадр", "Show Kadr")
        }
    }

    private var keyKey: String { "suite.hotkey.kadr.\(rawValue).key" }
    private var modsKey: String { "suite.hotkey.kadr.\(rawValue).mods" }
    private var clearedKey: String { "suite.hotkey.kadr.\(rawValue).cleared" }
    private static var d: UserDefaults { .standard }

    /// Defaults empty — only explicit assignment.
    var isAssigned: Bool {
        if Self.d.bool(forKey: clearedKey) { return false }
        return Self.d.integer(forKey: keyKey) > 0
    }

    var keyCode: UInt32 {
        get { UInt32(Self.d.integer(forKey: keyKey)) }
        nonmutating set {
            Self.d.set(Int(newValue), forKey: keyKey)
            Self.d.set(false, forKey: clearedKey)
        }
    }

    var modifiers: UInt32 {
        get { UInt32(Self.d.integer(forKey: modsKey)) }
        nonmutating set { Self.d.set(Int(newValue), forKey: modsKey) }
    }

    var display: String {
        guard isAssigned, keyCode > 0 else { return L10n.tr("Записать", "Record") }
        return HotkeyFormatter.string(keyCode: keyCode, modifiers: modifiers)
    }

    func set(keyCode: UInt32, modifiers: UInt32) {
        Self.d.set(Int(keyCode), forKey: keyKey)
        Self.d.set(Int(modifiers), forKey: modsKey)
        Self.d.set(false, forKey: clearedKey)
    }

    func clear() {
        Self.d.removeObject(forKey: keyKey)
        Self.d.removeObject(forKey: modsKey)
        Self.d.set(true, forKey: clearedKey)
    }

    static func resetAll() {
        for h in allCases { h.clear() }
    }

    /// Carbon hotkey id (1-based index in prefsOrder).
    var carbonID: UInt32 {
        UInt32((Self.prefsOrder.firstIndex(of: self) ?? 0) + 1)
    }

    static func from(carbonID: UInt32) -> SuiteKadrHotkey? {
        let idx = Int(carbonID) - 1
        guard prefsOrder.indices.contains(idx) else { return nil }
        return prefsOrder[idx]
    }
}
