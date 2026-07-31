import SwiftUI

struct PrefsVersionView: View {
    @State private var autoCheck = SuiteSharedSettings.autoCheckUpdates

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
                SuiteSectionHeader(title: AppBranding.displayName)
                SuiteCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(AppBranding.shortVersion) (\(AppBranding.build))")
                            .foregroundStyle(SuiteTheme.textPrimary)
                            .font(.system(size: 14, weight: .semibold))
                        Text(AppBranding.channelLabel)
                            .foregroundStyle(SuiteTheme.textSecondary)
                            .font(.system(size: 12))
                    }
                }
            }

            VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
                SuiteSectionHeader(title: L10n.tr("Обновления", "Updates"))
                SuiteCard {
                    VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                        Toggle(isOn: Binding(
                            get: { autoCheck },
                            set: {
                                autoCheck = $0
                                SuiteSharedSettings.autoCheckUpdates = $0
                            }
                        )) {
                            Text(L10n.tr("Автопроверка обновлений", "Automatically check for updates"))
                                .foregroundStyle(SuiteTheme.textPrimary)
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        Button(L10n.tr("Проверить обновления…", "Check for Updates…")) {
                            UpdateService.shared.checkForUpdates()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(SuiteTheme.accent)
                        .controlSize(.small)
                    }
                }
            }

            VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
                SuiteSectionHeader(title: L10n.tr("Связь", "Support"))
                SuiteCard {
                    HStack(spacing: 10) {
                        Button(L10n.tr("Сообщить о проблеме", "Report a Problem")) {
                            FeedbackService.openBugReport()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(L10n.tr("Сайт", "Website")) {
                            FeedbackService.openSite()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .suiteAppear()
        .onAppear {
            autoCheck = SuiteSharedSettings.autoCheckUpdates
            UpdateService.shared.automaticallyChecksForUpdates = autoCheck
        }
    }
}
