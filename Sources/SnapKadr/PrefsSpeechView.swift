import KadrKit
import StenoKit
import SwiftUI

struct PrefsSpeechView: View {
    @State private var revision = 0

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
                SuiteSectionHeader(title: L10n.tr("Речь", "Speech"))
                SuiteCard {
                    SpeechRecognitionSettingsForm()
                }
            }

            VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
                SuiteSectionHeader(title: L10n.tr("Участники", "Participants"))
                SuiteCard {
                    VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                        Toggle(isOn: Binding(
                            get: { _ = revision; return StenoSettings.namesFromCallWindow },
                            set: {
                                StenoSettings.namesFromCallWindow = $0
                                revision += 1
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Имена из окна звонка", "Names from call window"))
                                    .foregroundStyle(SuiteTheme.textPrimary)
                                Text(L10n.tr(
                                    "AX и OCR после стопа",
                                    "AX and OCR after stop"
                                ))
                                .font(.caption)
                                .foregroundStyle(SuiteTheme.textTertiary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        Toggle(isOn: Binding(
                            get: { _ = revision; return StenoSettings.separateSpeakers },
                            set: {
                                StenoSettings.separateSpeakers = $0
                                revision += 1
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Разделять голоса", "Separate speakers"))
                                    .foregroundStyle(SuiteTheme.textPrimary)
                                Text(L10n.tr(
                                    "Разметка голосов после распознавания",
                                    "Speaker labels after recognition"
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
        }
        .suiteAppear()
    }
}
