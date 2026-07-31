import SwiftUI

enum SuitePanelAction {
    case snapArea
    case snapFull
    case snapWindow
    case kadrCapture
    case kadrDisplay
    case preferences
    case quit
}

/// Control panel chrome matched to Kadr, with Snap + Kadr sections.
struct SuiteControlPanelView: View {
    let onAction: (SuitePanelAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            header
            snapSection
            kadrSection
            footer
        }
        .padding(SuiteTheme.spaceL)
        .frame(width: 320)
        .background(SuiteTheme.background)
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
