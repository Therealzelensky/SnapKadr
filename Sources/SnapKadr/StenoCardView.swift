import SwiftUI

struct StenoCardModel: Equatable {
    var isRecording: Bool
    var shareActive: Bool
    var shareFailed: Bool
    var speakerLabel: String
    var thesisPreview: String

    static let sessionStub = StenoCardModel(
        isRecording: true,
        shareActive: false,
        shareFailed: false,
        speakerLabel: "—",
        thesisPreview: ""
    )
}

struct StenoCardView: View {
    let model: StenoCardModel
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            HStack(spacing: 8) {
                Circle()
                    .fill(model.isRecording ? Color.red : SuiteTheme.textTertiary)
                    .frame(width: 8, height: 8)
                Text(L10n.tr("Идёт конспект", "Noting the call"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SuiteTheme.textPrimary)
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Image(systemName: model.shareActive ? "rectangle.on.rectangle" : "rectangle.dashed")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(shareTint)
                Text(shareLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(shareTint)
                Spacer(minLength: 0)
            }

            if !model.speakerLabel.isEmpty {
                Text(model.speakerLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(SuiteTheme.textTertiary)
                    .lineLimit(1)
            }

            if !model.thesisPreview.isEmpty {
                Text(model.thesisPreview)
                    .font(.system(size: 11))
                    .foregroundStyle(SuiteTheme.textTertiary)
                    .lineLimit(2)
            }

            Button(action: onStop) {
                Text(L10n.tr("Стоп", "Stop"))
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(SuiteTheme.accent)
        }
        .padding(SuiteTheme.spaceM)
        .frame(width: 240)
        .background(
            RoundedRectangle(cornerRadius: SuiteTheme.radiusCard, style: .continuous)
                .fill(SuiteTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: SuiteTheme.radiusCard, style: .continuous)
                        .strokeBorder(SuiteTheme.border, lineWidth: 1)
                )
        )
    }

    private var shareTint: Color {
        if model.shareFailed { return .orange }
        if model.shareActive { return SuiteTheme.accent }
        return SuiteTheme.textTertiary
    }

    private var shareLabel: String {
        if model.shareFailed {
            return L10n.tr("Шару не записали", "Share not recorded")
        }
        if model.shareActive {
            return L10n.tr("Шара пишется", "Share recording")
        }
        return L10n.tr("Шары нет", "No share")
    }
}
