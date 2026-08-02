import AppKit
import SwiftUI

/// Classic centered Apple About for the Version prefs tab.
struct PrefsVersionView: View {
    @ObservedObject private var updates = UpdateService.shared
    @State private var autoCheck = SuiteSharedSettings.autoCheckUpdates
    @State private var showBuild = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                identityColumn
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
                .padding(.horizontal, SuiteTheme.spaceXL)
                .padding(.bottom, SuiteTheme.spaceL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .suiteAppear()
        .onAppear {
            autoCheck = SuiteSharedSettings.autoCheckUpdates
            UpdateService.shared.automaticallyChecksForUpdates = autoCheck
            if autoCheck {
                UpdateService.shared.checkForUpdatesInBackground()
            }
        }
    }

    private var identityColumn: some View {
        VStack(spacing: 0) {
            appIconView
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.45), radius: 20, y: 10)

            Text(AppBranding.displayName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(SuiteTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 16)

            Button {
                showBuild.toggle()
            } label: {
                Text(showBuild ? AppBranding.build : AppBranding.releaseLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SuiteTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityLabel(L10n.tr(
                "\(AppBranding.releaseLabel), сборка \(AppBranding.build)",
                "\(AppBranding.releaseLabel), build \(AppBranding.build)"
            ))

            if updates.updateAvailable, let pending = updates.pendingShortVersion {
                Text(L10n.tr("Доступна \(pending)", "Update available: \(pending)"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SuiteTheme.accent)
                    .padding(.top, 6)
            }

            HStack(spacing: 8) {
                neonIrisView
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(SuiteTheme.border, lineWidth: 1))
                Text(L10n.tr("Therealzelensky · Щёлк.Кадр", "Therealzelensky · Snap.Kadr"))
                    .font(.system(size: 11))
                    .foregroundStyle(SuiteTheme.textTertiary)
            }
            .padding(.top, 18)

            Button(L10n.tr("Проверить обновления…", "Check for Updates…")) {
                UpdateService.shared.checkForUpdates()
            }
            .buttonStyle(.borderedProminent)
            .tint(SuiteTheme.accent)
            .controlSize(.regular)
            .padding(.top, 22)
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, SuiteTheme.spaceXL)
        .padding(.bottom, 48)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(L10n.tr("Автопроверка", "Automatic checks"))
                .font(.system(size: 11))
                .foregroundStyle(SuiteTheme.textTertiary)
            Spacer(minLength: 0)
            Toggle("", isOn: Binding(
                get: { autoCheck },
                set: {
                    autoCheck = $0
                    SuiteSharedSettings.autoCheckUpdates = $0
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
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
                .font(.system(size: 42, weight: .medium))
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
                .font(.system(size: 16))
                .foregroundStyle(SuiteTheme.accent)
        }
    }
}
