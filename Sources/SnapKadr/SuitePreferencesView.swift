import SwiftUI
import AppKit

enum PrefsTab: String, CaseIterable, Identifiable {
    case general, kadr, snap, hotkeys, version
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return L10n.tr("Общие", "General")
        case .kadr: return L10n.tr("Кадр", "Kadr")
        case .snap: return L10n.tr("Щёлк", "Snap")
        case .hotkeys: return L10n.tr("Горячие клавиши", "Hotkeys")
        case .version: return L10n.tr("Версия", "Version")
        }
    }
}

enum L10n {
    static func tr(_ ru: String, _ en: String) -> String {
        AppBranding.isRussianLocale ? ru : en
    }
}

@MainActor
final class SuitePrefsModel: ObservableObject {
    @Published var launchAtLogin = false
    @Published var showSplash = true
    @Published var autoCheckUpdates = true
    @Published var selectedTab: PrefsTab = .general

    // Kadr-ish placeholders (suite-local until KadrKit embeds)
    @Published var countdownMs = 3000
    @Published var recordMic = true
    @Published var systemAudio = true
    @Published var autoZoom = true

    // Snap-ish placeholders
    @Published var afterCapturePreview = true
    @Published var saveFormatPNG = true

    func reload() {
        let d = UserDefaults.standard
        launchAtLogin = d.bool(forKey: "shared.launchAtLogin")
        showSplash = d.object(forKey: "shared.showSplash") as? Bool ?? true
        autoCheckUpdates = d.object(forKey: "shared.autoCheckUpdates") as? Bool ?? true
        countdownMs = d.object(forKey: "kadr.countdownMs") as? Int ?? 3000
        recordMic = d.object(forKey: "kadr.recordMic") as? Bool ?? true
        systemAudio = d.object(forKey: "kadr.systemAudio") as? Bool ?? true
        autoZoom = d.object(forKey: "kadr.autoZoom") as? Bool ?? true
        afterCapturePreview = d.object(forKey: "snap.afterCapturePreview") as? Bool ?? true
        saveFormatPNG = d.object(forKey: "snap.saveFormatPNG") as? Bool ?? true
    }

    func save() {
        let d = UserDefaults.standard
        d.set(launchAtLogin, forKey: "shared.launchAtLogin")
        d.set(showSplash, forKey: "shared.showSplash")
        d.set(autoCheckUpdates, forKey: "shared.autoCheckUpdates")
        d.set(countdownMs, forKey: "kadr.countdownMs")
        d.set(recordMic, forKey: "kadr.recordMic")
        d.set(systemAudio, forKey: "kadr.systemAudio")
        d.set(autoZoom, forKey: "kadr.autoZoom")
        d.set(afterCapturePreview, forKey: "snap.afterCapturePreview")
        d.set(saveFormatPNG, forKey: "snap.saveFormatPNG")
        UpdateService.shared.automaticallyChecksForUpdates = autoCheckUpdates
    }
}

struct SuitePreferencesView: View {
    @ObservedObject var model: SuitePrefsModel
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $model.selectedTab) {
                ForEach(PrefsTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                Group {
                    switch model.selectedTab {
                    case .general: generalTab
                    case .kadr: kadrTab
                    case .snap: snapTab
                    case .hotkeys: hotkeysTab
                    case .version: versionTab
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 560, height: 480)
        .onAppear { model.reload() }
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            section(L10n.tr("Система", "System"))
            toggle(L10n.tr("Запускать при входе", "Launch at login"), $model.launchAtLogin)
            toggle(L10n.tr("Показывать splash", "Show splash"), $model.showSplash)
            Text(L10n.tr(
                "Доступы (экран / мик / камера) запрашивают модули Щёлк и Кадр при первом использовании.",
                "Permissions (screen / mic / camera) are requested by Snap and Kadr modules on first use."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            saveRow
        }
    }

    private var kadrTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            section(L10n.tr("Запись", "Recording"))
            HStack {
                Text(L10n.tr("Обратный отсчёт (мс)", "Countdown (ms)"))
                Spacer()
                TextField("", value: $model.countdownMs, format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }
            toggle(L10n.tr("Микрофон", "Microphone"), $model.recordMic)
            toggle(L10n.tr("Системный звук", "System audio"), $model.systemAudio)
            toggle(L10n.tr("Автозумы", "Automatic zooms"), $model.autoZoom)
            Text(L10n.tr(
                "Полный инспектор Кадра подключится с KadrKit. Сейчас значения хранятся в suite.",
                "Full Kadr inspector lands with KadrKit. Values are stored in the suite for now."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            saveRow
        }
    }

    private var snapTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            section(L10n.tr("После захвата", "After capture"))
            toggle(L10n.tr("Показывать превью", "Show preview"), $model.afterCapturePreview)
            toggle(L10n.tr("Формат PNG по умолчанию", "Default PNG format"), $model.saveFormatPNG)
            Text(L10n.tr(
                "Полные настройки Щёлка — в SnapKit. Каркас вкладок готов.",
                "Full Snap settings land in SnapKit. Tab scaffold is ready."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            saveRow
        }
    }

    private var hotkeysTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            section(L10n.tr("Щёлк", "Snap"))
            Text("⌃⇧2 — \(L10n.tr("область", "area")) · ⌃⇧3 — \(L10n.tr("экран", "screen"))")
                .font(.system(.body, design: .monospaced))
            section(L10n.tr("Кадр", "Kadr"))
            Text(L10n.tr("Биндинги записи появятся с общим hotkey engine.", "Recording bindings arrive with the shared hotkey engine."))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private var versionTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            section(AppBranding.displayName)
            Text("\(AppBranding.shortVersion) (\(AppBranding.build)) · \(AppBranding.channelLabel)")
                .foregroundStyle(.secondary)

            section(L10n.tr("Обновления", "Updates"))
            toggle(L10n.tr("Автопроверка обновлений", "Automatically check for updates"), $model.autoCheckUpdates)
            Button(L10n.tr("Проверить обновления…", "Check for Updates…")) {
                model.save()
                UpdateService.shared.checkForUpdates()
            }

            section(L10n.tr("Связь", "Support"))
            HStack(spacing: 10) {
                Button(L10n.tr("Сообщить о проблеме", "Report a Problem")) {
                    FeedbackService.openBugReport()
                }
                Button(L10n.tr("Сайт", "Website")) {
                    FeedbackService.openSite()
                }
            }

            Text(L10n.tr(
                "Краши на волне 1 — через Issues (app-feedback). Sentry — позже при необходимости.",
                "Wave-1 crashes go through Issues (app-feedback). Sentry later if needed."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)
            saveRow
        }
    }

    private var saveRow: some View {
        HStack {
            Spacer()
            Button(L10n.tr("Сохранить", "Save")) {
                model.save()
                onClose()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 4)
    }

    private func toggle(_ title: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(title)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}
