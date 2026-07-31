import AppKit
import SwiftUI

struct PrefsGeneralView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var showSplash = SuiteSharedSettings.showSplash
    @State private var hideMenubar = SuiteSharedSettings.hideMenubarIcon
    @State private var urlScheme = SuiteSharedSettings.urlSchemeEnabled
    @State private var diagnostics = SuiteSharedSettings.allowDiagnostics
    @State private var confirmation = SuiteConfirmationStyle(
        rawValue: SuiteSharedSettings.confirmationStyleRaw
    ) ?? .notch

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            systemSection
            permissionsSection
            extrasSection
        }
        .suiteAppear()
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Система", "System"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    prefsToggle(
                        L10n.tr("Запускать при входе", "Launch at login"),
                        $launchAtLogin
                    ) { LaunchAtLogin.isEnabled = $0 }

                    prefsToggle(
                        L10n.tr("Показывать splash", "Show splash"),
                        $showSplash
                    ) { SuiteSharedSettings.showSplash = $0 }
                }
            }
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Доступы", "Permissions"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    Text(L10n.tr(
                        "Экран, микрофон и камера запрашиваются при первом использовании Щёлка или Кадра.",
                        "Screen, microphone, and camera are requested on first use by Snap or Kadr."
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(SuiteTheme.textSecondary)

                    HStack(spacing: 8) {
                        privacyButton(L10n.tr("Экран", "Screen"), "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
                        privacyButton(L10n.tr("Микрофон", "Microphone"), "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
                        privacyButton(L10n.tr("Камера", "Camera"), "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
                    }
                }
            }
        }
    }

    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Дополнительно", "Advanced"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    prefsToggle(
                        L10n.tr("Скрыть иконку в меню", "Hide menu bar icon"),
                        $hideMenubar
                    ) { SuiteSharedSettings.hideMenubarIcon = $0 }

                    prefsToggle(
                        L10n.tr("Включить deep links (URL Scheme)", "Enable URL Scheme deep links"),
                        $urlScheme
                    ) { SuiteSharedSettings.urlSchemeEnabled = $0 }

                    prefsToggle(
                        L10n.tr("Разрешить сбор диагностики", "Allow diagnostics"),
                        $diagnostics
                    ) { SuiteSharedSettings.allowDiagnostics = $0 }

                    HStack {
                        Text(L10n.tr("Стиль подтверждения", "Confirmation style"))
                            .foregroundStyle(SuiteTheme.textPrimary)
                        Spacer()
                        Picker("", selection: $confirmation) {
                            ForEach(SuiteConfirmationStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                        .onChange(of: confirmation) { _, newValue in
                            SuiteSharedSettings.confirmationStyleRaw = newValue.rawValue
                        }
                    }
                }
            }
        }
    }

    private func prefsToggle(_ title: String, _ binding: Binding<Bool>, onSet: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = $0; onSet($0) }
        )) {
            Text(title)
                .foregroundStyle(SuiteTheme.textPrimary)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private func privacyButton(_ title: String, _ urlString: String) -> some View {
        Button(title) {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
