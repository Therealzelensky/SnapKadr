import SwiftUI

struct PrefsGeneralView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            SuiteSectionHeader(title: L10n.tr("Система", "System"))
            SuiteCard {
                Text(L10n.tr("Загрузка…", "Loading…"))
                    .foregroundStyle(SuiteTheme.textSecondary)
                    .font(.system(size: 13))
            }
        }
    }
}
