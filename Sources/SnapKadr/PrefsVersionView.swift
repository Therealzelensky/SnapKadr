import AppKit
import SwiftUI

struct PrefsVersionView: View {
    @State private var autoCheck = SuiteSharedSettings.autoCheckUpdates

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            HStack(alignment: .top, spacing: SuiteTheme.spaceM) {
                productCard
                developerCard
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

    private var productCard: some View {
        SuiteCard {
            VStack(alignment: .center, spacing: 10) {
                appIconView
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(AppBranding.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SuiteTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("\(AppBranding.shortVersion) (\(AppBranding.build))")
                    .font(.system(size: 12))
                    .foregroundStyle(SuiteTheme.textSecondary)
                Text(AppBranding.channelLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(SuiteTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var developerCard: some View {
        SuiteCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    neonIrisView
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Therealzelensky")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SuiteTheme.textPrimary)
                        Text(L10n.tr(
                            "macOS tools · Щёлк · Кадр · Щёлк.Кадр",
                            "macOS tools · Snap · Kadr · Snap.Kadr"
                        ))
                        .font(.system(size: 11))
                        .foregroundStyle(SuiteTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                FlowLinkChips(links: [
                    (L10n.tr("GitHub", "GitHub"), AppBranding.developerGitHubURL),
                    (L10n.tr("Сайт", "Site"), AppBranding.siteURL),
                    (L10n.tr("Щёлк", "Snap"), AppBranding.snapReleasesURL),
                    (L10n.tr("Кадр", "Kadr"), AppBranding.kadrReleasesURL),
                    (L10n.tr("Suite", "Suite"), AppBranding.suiteReleasesURL),
                    (L10n.tr("Проблема", "Issue"), AppBranding.feedbackNewIssueURL)
                ])
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let icon = NSApp.applicationIconImage {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "camera.aperture")
                .font(.system(size: 28))
                .foregroundStyle(SuiteTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SuiteTheme.surfaceElevated)
        }
    }

    @ViewBuilder
    private var neonIrisView: some View {
        if let url = Bundle.main.url(forResource: "NeonIris", withExtension: "png", subdirectory: "Brand")
            ?? Bundle.main.url(forResource: "NeonIris", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(SuiteTheme.accent)
        }
    }
}

/// Simple wrapping chip row for developer links.
private struct FlowLinkChips: View {
    let links: [(String, URL)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(stride(from: 0, to: links.count, by: 3)), id: \.self) { start in
                HStack(spacing: 6) {
                    ForEach(start..<min(start + 3, links.count), id: \.self) { i in
                        let item = links[i]
                        Button(item.0) {
                            NSWorkspace.shared.open(item.1)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            }
        }
    }
}
