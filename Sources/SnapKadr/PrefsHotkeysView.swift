import SwiftUI

struct PrefsHotkeysView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            SuiteSectionHeader(title: L10n.tr("Горячие клавиши", "Hotkeys"))
            SuiteCard {
                Text(L10n.tr(
                    "Редактор сочетаний и политика B2 — в следующей волне.",
                    "Shortcut editor and B2 policy arrive in the next wave."
                ))
                .foregroundStyle(SuiteTheme.textSecondary)
                .font(.system(size: 13))
            }
        }
    }
}
