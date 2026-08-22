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
                            get: { _ = revision; return StenoSettings.recordCallVideo },
                            set: { StenoSettings.recordCallVideo = $0; revision += 1 }
                        )) {
                            Text(L10n.tr("Писать видео окна звонка", "Record call window video"))
                                .foregroundStyle(SuiteTheme.textPrimary)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        Text(L10n.tr(
                            "Выкл — только звук, Mac не тормозит на звонке.",
                            "Off — audio only, keeps the Mac smooth on a call."
                        ))
                        .font(.system(size: 11))
                        .foregroundStyle(SuiteTheme.textTertiary)
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
        }
    }
}
