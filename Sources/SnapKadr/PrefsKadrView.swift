import SwiftUI

struct PrefsKadrView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            SuiteSectionHeader(title: L10n.tr("Кадр", "Kadr"))
            SuiteCard {
                Text(L10n.tr(
                    "Настройки записи появятся в следующей волне.",
                    "Recording settings arrive in the next wave."
                ))
                .foregroundStyle(SuiteTheme.textSecondary)
                .font(.system(size: 13))
            }
        }
    }
}
