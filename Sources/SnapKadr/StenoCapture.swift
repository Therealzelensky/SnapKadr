import KadrKit
import StenoKit

/// ScreenCaptureKit profile for Стено. Lives in SnapKadr so standalone Kadr stays sharp.
enum StenoCapture {
    static func windowRecord(recordVideo: Bool = StenoSettings.recordCallVideo) -> KadrWindowRecordOptions {
        KadrWindowRecordOptions(
            recordsInputEvents: false,
            presentsEditor: false,
            capturesVideo: recordVideo,
            activatesOwnerApp: false,
            presentsAlerts: false
        )
    }
}
