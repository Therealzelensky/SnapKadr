import SwiftUI
import SnapKit

struct PrefsShellView: View {
    @ObservedObject var model: PrefsRootModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle()
                .fill(SuiteTheme.border)
                .frame(width: 1)
            ScrollView {
                Group {
                    switch model.selectedTab {
                    case .general: PrefsGeneralView()
                    case .kadr: PrefsKadrView()
                    case .snap: SnapPrefsContent()
                    case .hotkeys: PrefsHotkeysView()
                    case .notifications: PrefsNotificationsView()
                    case .version: PrefsVersionView()
                    }
                }
                .padding(SuiteTheme.spaceL)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(SuiteTheme.background)
        }
        .frame(minWidth: 640, minHeight: 480)
        .background(SuiteTheme.background)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(PrefsTab.allCases) { tab in
                Button {
                    model.selectedTab = tab
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tab.symbol)
                            .frame(width: 18)
                        Text(tab.title)
                            .font(.system(size: 13, weight: model.selectedTab == tab ? .semibold : .regular))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(model.selectedTab == tab ? SuiteTheme.textPrimary : SuiteTheme.textSecondary)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(model.selectedTab == tab ? SuiteTheme.surfaceElevated : Color.clear)
                    )
                    .overlay(alignment: .leading) {
                        if model.selectedTab == tab {
                            Capsule()
                                .fill(SuiteTheme.accent)
                                .frame(width: 3)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 180)
        .background(SuiteTheme.background)
    }
}
