import SnapKit
import SwiftUI

struct PrefsNotificationsView: View {
    @State private var style = SuiteNotificationSettings.confirmationStyle
    @State private var snapCopied = SuiteNotificationSettings.snapCopied
    @State private var snapSaved = SuiteNotificationSettings.snapSaved
    @State private var snapError = SuiteNotificationSettings.snapError
    @State private var snapOCR = SuiteNotificationSettings.snapOCR
    @State private var kadrStarted = SuiteNotificationSettings.kadrStarted
    @State private var kadrStopped = SuiteNotificationSettings.kadrStopped
    @State private var kadrExport = SuiteNotificationSettings.kadrExport
    @State private var kadrNewProject = SuiteNotificationSettings.kadrNewProject

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            generalSection
            snapSection
            kadrSection
        }
        .suiteAppear()
        .onAppear { reload() }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Общие", "General"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    HStack {
                        Text(L10n.tr("Стиль подтверждения", "Confirmation style"))
                            .foregroundStyle(SuiteTheme.textPrimary)
                        Spacer()
                        Picker("", selection: $style) {
                            ForEach(SuiteConfirmationStyle.allCases) { s in
                                Text(s.title).tag(s)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                        .onChange(of: style) { _, v in
                            SuiteNotificationSettings.confirmationStyle = v
                            AppSettings.confirmationStyle = AppSettings.ConfirmationStyle(rawValue: v.rawValue) ?? .notch
                        }
                    }

                    Button(L10n.tr("Показать тест", "Show test")) {
                        SuiteNotchHUD.shared.showTest()
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var snapSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Щёлк", "Snap"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    eventToggle(L10n.tr("Скопировано", "Copied"), $snapCopied) {
                        SuiteNotificationSettings.snapCopied = $0
                    }
                    eventToggle(L10n.tr("Сохранено", "Saved"), $snapSaved) {
                        SuiteNotificationSettings.snapSaved = $0
                    }
                    eventToggle(L10n.tr("Ошибка захвата", "Capture error"), $snapError) {
                        SuiteNotificationSettings.snapError = $0
                    }
                    eventToggle(L10n.tr("OCR / распознавание готово", "OCR / recognition ready"), $snapOCR) {
                        SuiteNotificationSettings.snapOCR = $0
                    }
                }
            }
        }
    }

    private var kadrSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Кадр", "Kadr"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    eventToggle(L10n.tr("Запись началась", "Recording started"), $kadrStarted) {
                        SuiteNotificationSettings.kadrStarted = $0
                    }
                    eventToggle(L10n.tr("Запись остановлена", "Recording stopped"), $kadrStopped) {
                        SuiteNotificationSettings.kadrStopped = $0
                    }
                    eventToggle(L10n.tr("Экспорт готов / ошибка", "Export ready / error"), $kadrExport) {
                        SuiteNotificationSettings.kadrExport = $0
                    }
                    eventToggle(L10n.tr("Новый проект создан", "New project created"), $kadrNewProject) {
                        SuiteNotificationSettings.kadrNewProject = $0
                    }
                    Text(L10n.tr(
                        "Тогглы Кадра сохраняются в suite; синхронизация с компаньоном — позже.",
                        "Kadr notification toggles apply in-process via KadrKit."
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(SuiteTheme.textTertiary)
                }
            }
        }
    }

    private func eventToggle(_ title: String, _ binding: Binding<Bool>, onSet: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = $0; onSet($0) }
        )) {
            Text(title)
                .foregroundStyle(SuiteTheme.textPrimary)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private func reload() {
        style = SuiteNotificationSettings.confirmationStyle
        snapCopied = SuiteNotificationSettings.snapCopied
        snapSaved = SuiteNotificationSettings.snapSaved
        snapError = SuiteNotificationSettings.snapError
        snapOCR = SuiteNotificationSettings.snapOCR
        kadrStarted = SuiteNotificationSettings.kadrStarted
        kadrStopped = SuiteNotificationSettings.kadrStopped
        kadrExport = SuiteNotificationSettings.kadrExport
        kadrNewProject = SuiteNotificationSettings.kadrNewProject
    }
}
