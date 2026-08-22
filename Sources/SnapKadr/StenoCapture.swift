import KadrKit

/// Light ScreenCaptureKit profile for Стено. Lives in SnapKadr so standalone Kadr stays sharp.
enum StenoCapture {
    /// Same picture as Kadr. Only skip the cursor tap and the editor — those do not change the file.
    static let windowRecord = KadrWindowRecordOptions(
        recordsInputEvents: false,
        presentsEditor: false
    )
}
