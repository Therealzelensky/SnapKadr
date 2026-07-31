import Foundation
import SnapKit

/// Suite notification prefs. Snap event keys match `AppSettings` so in-process SnapKit reads them.
enum SuiteNotificationSettings {
    private static let d = UserDefaults.standard

    static var confirmationStyle: SuiteConfirmationStyle {
        get { SuiteConfirmationStyle(rawValue: SuiteSharedSettings.confirmationStyleRaw) ?? .notch }
        set { SuiteSharedSettings.confirmationStyleRaw = newValue.rawValue }
    }

    // Snap (bridged to AppSettings)
    static var snapCopied: Bool {
        get { AppSettings.notifyCopiedEnabled }
        set { AppSettings.notifyCopiedEnabled = newValue }
    }

    static var snapSaved: Bool {
        get { AppSettings.notifySavedEnabled }
        set { AppSettings.notifySavedEnabled = newValue }
    }

    static var snapError: Bool {
        get { AppSettings.notifyCaptureErrorEnabled }
        set { AppSettings.notifyCaptureErrorEnabled = newValue }
    }

    static var snapOCR: Bool {
        get { AppSettings.notifyOCREnabled }
        set { AppSettings.notifyOCREnabled = newValue }
    }

    // Kadr (suite-local until companion sync)
    static var kadrStarted: Bool {
        get { d.object(forKey: "notify.kadr.started") as? Bool ?? true }
        set { d.set(newValue, forKey: "notify.kadr.started") }
    }

    static var kadrStopped: Bool {
        get { d.object(forKey: "notify.kadr.stopped") as? Bool ?? true }
        set { d.set(newValue, forKey: "notify.kadr.stopped") }
    }

    static var kadrExport: Bool {
        get { d.object(forKey: "notify.kadr.export") as? Bool ?? true }
        set { d.set(newValue, forKey: "notify.kadr.export") }
    }

    static var kadrNewProject: Bool {
        get { d.object(forKey: "notify.kadr.newProject") as? Bool ?? true }
        set { d.set(newValue, forKey: "notify.kadr.newProject") }
    }
}
