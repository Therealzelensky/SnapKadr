import SwiftUI

struct PrefsVersionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            SuiteSectionHeader(title: AppBranding.displayName)
            SuiteCard {
                Text("\(AppBranding.shortVersion) (\(AppBranding.build)) · \(AppBranding.channelLabel)")
                    .foregroundStyle(SuiteTheme.textSecondary)
                    .font(.system(size: 13))
            }
        }
    }
}
