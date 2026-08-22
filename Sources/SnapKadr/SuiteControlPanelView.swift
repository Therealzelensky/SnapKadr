import SwiftUI
import KadrKit
import StenoKit

enum SuitePanelAction {
    case snapArea
    case snapFull
    case snapWindow
    case kadrCapture
    case kadrDisplay
    case openProject
    case openRecent(URL)
    case preferences
    case quit
}

/// Control panel chrome matched to Kadr, with Snap + Kadr sections.
struct SuiteControlPanelView: View {
    let onAction: (SuitePanelAction) -> Void
    var onLayoutNeeded: (() -> Void)? = nil

    private enum Screen {
        case home
        case projects
    }

    @State private var screen: Screen = .home
    @ObservedObject private var steno = StenoSessionController.shared
    @ObservedObject private var stenoDetector = StenoSessionController.shared.detector

    private var recentURLs: [URL] {
        AppSettings.recentProjectPaths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            switch screen {
            case .home:
                header
                snapSection
                kadrSection
                stenoSection
            case .projects:
                projectsHeader
                projectsSection
            }
            footer
        }
        .padding(SuiteTheme.spaceL)
        .frame(width: 320)
        .background(SuiteTheme.background)
        .onChange(of: screen) { _, _ in
            DispatchQueue.main.async { onLayoutNeeded?() }
        }
        .onChange(of: stenoDetector.activeCall) { _, _ in
            DispatchQueue.main.async { onLayoutNeeded?() }
        }
        .onChange(of: steno.isSessionActive) { _, _ in
            DispatchQueue.main.async { onLayoutNeeded?() }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SuiteTheme.accent)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppBranding.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SuiteTheme.textPrimary)
                Text(L10n.tr("Щёлк + Кадр", "Snap + Kadr"))
                    .font(.system(size: 11))
                    .foregroundStyle(SuiteTheme.textTertiary)
            }
            Spacer()
        }
        .suiteAppear()
    }

    private var projectsHeader: some View {
        HStack(spacing: 8) {
            Button {
                screen = .home
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L10n.tr("Назад", "Back"))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(SuiteTheme.textSecondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text(L10n.tr("Проекты", "Projects"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SuiteTheme.textPrimary)
            Spacer()
            Color.clear.frame(width: 56, height: 1)
        }
        .suiteAppear()
    }

    private var snapSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Щёлк", "Snap"))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                SuiteTileButton(
                    title: L10n.tr("Область", "Area"),
                    icon: "rectangle.dashed",
                    accent: SuiteTheme.snapAccent,
                    action: { onAction(.snapArea) }
                )
                .suiteAppear(delay: 0.02)
                SuiteTileButton(
                    title: L10n.tr("Экран", "Screen"),
                    icon: "display",
                    accent: SuiteTheme.snapAccent,
                    action: { onAction(.snapFull) }
                )
                .suiteAppear(delay: 0.04)
                SuiteTileButton(
                    title: L10n.tr("Окно", "Window"),
                    icon: "macwindow",
                    accent: SuiteTheme.snapAccent,
                    action: { onAction(.snapWindow) }
                )
                .suiteAppear(delay: 0.06)
            }
        }
    }

    private var kadrSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Кадр", "Kadr"))
            SuiteRowButton(
                title: L10n.tr("Панель захвата", "Capture bar"),
                icon: "record.circle",
                subtitle: L10n.tr("Экран · Окно · Область · Device", "Display · Window · Area · Device"),
                accent: SuiteTheme.record,
                action: { onAction(.kadrCapture) }
            )
            .suiteAppear(delay: 0.08)

            SuiteTileButton(
                title: L10n.tr("Запись экрана", "Record display"),
                icon: "display",
                accent: SuiteTheme.accent,
                action: { onAction(.kadrDisplay) }
            )
            .suiteAppear(delay: 0.1)

            SuiteRowButton(
                title: L10n.tr("Проекты", "Projects"),
                icon: "film.stack",
                subtitle: L10n.tr("Недавние и открыть…", "Recent and open…"),
                accent: SuiteTheme.accent,
                action: { screen = .projects }
            )
            .suiteAppear(delay: 0.12)
        }
    }

    private var stenoSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Стено", "Steno"))
            SuiteCard {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: steno.isSessionActive ? "record.circle" : "waveform")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(steno.isSessionActive ? SuiteTheme.record : SuiteTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stenoStatusTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(SuiteTheme.textPrimary)
                            .lineLimit(1)
                        Text(stenoStatusSubtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(SuiteTheme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if steno.isSessionActive {
                        Button(L10n.tr("Стоп", "Stop")) {
                            StenoSessionController.shared.stopFromUser()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SuiteTheme.record)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .suiteAppear(delay: 0.14)
        }
    }

    private var stenoStatusTitle: String {
        if steno.isSessionActive {
            return L10n.tr("Идёт конспект", "Noting the call")
        }
        if let call = stenoDetector.activeCall {
            let raw = call.title.isEmpty ? call.source.rawValue : call.title
            if raw.count <= 36 { return raw }
            return String(raw.prefix(35)) + "…"
        }
        return L10n.tr("Нет активного звонка", "No active call")
    }

    private var stenoStatusSubtitle: String {
        if steno.isSessionActive {
            return L10n.tr("Стоп в челке или здесь", "Stop in the notch or here")
        }
        if stenoDetector.activeCall != nil {
            return L10n.tr("Подтвердите в челке", "Confirm in the notch")
        }
        return L10n.tr("Zoom · Meet · Telegram · Телемост · Синк", "Zoom · Meet · Telegram · Telemost · Sync")
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Недавние", "Recent"))
            if recentURLs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(SuiteTheme.textTertiary)
                    Text(L10n.tr("Пока пусто", "Nothing yet"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SuiteTheme.textPrimary)
                    Text(L10n.tr("Запишите первый ролик", "Record your first clip"))
                        .font(.system(size: 11))
                        .foregroundStyle(SuiteTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: SuiteTheme.radiusCard, style: .continuous)
                        .fill(SuiteTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: SuiteTheme.radiusCard, style: .continuous)
                                .strokeBorder(SuiteTheme.border, lineWidth: 1)
                        )
                )
                .suiteAppear(delay: 0.04)
            } else {
                SuiteCard {
                    VStack(spacing: 0) {
                        ForEach(Array(recentURLs.enumerated()), id: \.offset) { idx, url in
                            Button {
                                onAction(.openRecent(url))
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(url.deletingPathExtension().lastPathComponent)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(SuiteTheme.textPrimary)
                                            .lineLimit(1)
                                        Text(url.deletingLastPathComponent().lastPathComponent)
                                            .font(.system(size: 11))
                                            .foregroundStyle(SuiteTheme.textTertiary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(SuiteTheme.textTertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if idx < recentURLs.count - 1 {
                                Rectangle()
                                    .fill(SuiteTheme.border)
                                    .frame(height: 1)
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
                .suiteAppear(delay: 0.04)
            }

            SuiteRowButton(
                title: L10n.tr("Открыть проект…", "Open Project…"),
                icon: "folder",
                accent: SuiteTheme.accent,
                action: { onAction(.openProject) }
            )
            .suiteAppear(delay: 0.08)
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text(L10n.tr("Щёлк.Кадр", "Snap.Kadr"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SuiteTheme.textPrimary)
            Spacer(minLength: 0)
            SuiteIconButton(
                systemName: "gearshape",
                size: 30,
                tint: SuiteTheme.textSecondary,
                filled: true,
                action: { onAction(.preferences) }
            )
            SuiteIconButton(
                systemName: "power",
                size: 30,
                tint: SuiteTheme.record,
                filled: true,
                action: { onAction(.quit) }
            )
        }
        .suiteAppear(delay: 0.14)
    }
}
