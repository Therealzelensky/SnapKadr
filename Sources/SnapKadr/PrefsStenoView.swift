import StenoKit
import SwiftUI

struct PrefsStenoView: View {
    @State private var revision = 0

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
                SuiteSectionHeader(title: L10n.tr("Поведение", "Behavior"))
                SuiteCard {
                    VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                        Toggle(isOn: Binding(
                            get: { _ = revision; return StenoSettings.isEnabled },
                            set: {
                                StenoSettings.isEnabled = $0
                                StenoSessionController.shared.applyEnabledFromSettings()
                                revision += 1
                            }
                        )) {
                            Text(L10n.tr("Включить Стено", "Enable Steno")).foregroundStyle(SuiteTheme.textPrimary)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        Toggle(isOn: Binding(
                            get: { _ = revision; return StenoSettings.recordShare },
                            set: {
                                StenoSettings.recordShare = $0
                                revision += 1
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Писать шару", "Record screen share"))
                                    .foregroundStyle(SuiteTheme.textPrimary)
                                Text(L10n.tr(
                                    "Вкл — отдельная дорожка, когда шара на экране.",
                                    "On — a separate track when screen share is visible."
                                ))
                                .font(.caption)
                                .foregroundStyle(SuiteTheme.textTertiary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }
            }

            VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
                SuiteSectionHeader(title: L10n.tr("Источники", "Sources"))
                SuiteCard {
                    VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                        ForEach(StenoSource.allCases, id: \.rawValue) { source in
                            Toggle(isOn: Binding(
                                get: { _ = revision; return StenoSettings.isEnabled(source) },
                                set: {
                                    StenoSettings.setEnabled(source, $0)
                                    revision += 1
                                }
                            )) {
                                Text(title(for: source)).foregroundStyle(SuiteTheme.textPrimary)
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .suiteAppear()
    }

    private func title(for source: StenoSource) -> String {
        switch source {
        case .zoom: return "Zoom"
        case .googleMeet: return "Google Meet"
        case .telegram: return "Telegram"
        case .telemost: return L10n.tr("Телемост", "Telemost")
        case .bitrixSync: return L10n.tr("Битрикс24 Синк", "Bitrix24 Sync")
        case .yandexMessenger: return L10n.tr("Яндекс Мессенджер", "Yandex Messenger")
        }
    }
}
