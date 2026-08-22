import KadrKit
import SwiftUI

struct PrefsSpeechView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
                SuiteSectionHeader(title: L10n.tr("Речь", "Speech"))
                SuiteCard {
                    SpeechRecognitionSettingsForm()
                }
            }
        }
        .suiteAppear()
    }
}
