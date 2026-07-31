import Foundation
import AppKit

enum FeedbackService {
    static func openBugReport() {
        NSWorkspace.shared.open(AppBranding.feedbackNewIssueURL)
    }

    static func openSite() {
        NSWorkspace.shared.open(AppBranding.siteURL)
    }
}
