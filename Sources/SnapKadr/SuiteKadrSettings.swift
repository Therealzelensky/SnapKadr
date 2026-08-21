import Foundation
import KadrKit

/// Thin aliases over in-process `AppSettings` (same keys, same UserDefaults domain in suite).
enum SuiteKadrSettings {
    static var projectsFolderURL: URL {
        get { AppSettings.projectsFolderURL }
        set { AppSettings.projectsFolderURL = newValue }
    }

    static var recordingCountdownMs: Int {
        get { AppSettings.recordingCountdownMs }
        set { AppSettings.recordingCountdownMs = newValue }
    }

    static var createAutomaticZooms: Bool {
        get { AppSettings.createAutomaticZooms }
        set { AppSettings.createAutomaticZooms = newValue }
    }

    static var recordMicrophone: Bool {
        get { AppSettings.recordMicrophone }
        set { AppSettings.recordMicrophone = newValue }
    }

    static var preferredMicrophoneUID: String? {
        get { AppSettings.preferredMicrophoneUID }
        set { AppSettings.preferredMicrophoneUID = newValue }
    }

    static var noiseReduction: Bool {
        get { AppSettings.noiseReduction }
        set { AppSettings.noiseReduction = newValue }
    }

    static var captureSystemAudio: Bool {
        get { AppSettings.captureSystemAudio }
        set { AppSettings.captureSystemAudio = newValue }
    }

    static var recordWebcam: Bool {
        get { AppSettings.recordWebcam }
        set { AppSettings.recordWebcam = newValue }
    }

    static var preferredCameraUniqueID: String? {
        get {
            let v = AppSettings.preferredCameraUniqueID
            return (v?.isEmpty == false) ? v : nil
        }
        set {
            AppSettings.preferredCameraUniqueID = newValue
        }
    }

    static var hideDesktopIconsWhileRecording: Bool {
        get { AppSettings.hideDesktopIconsWhileRecording }
        set { AppSettings.hideDesktopIconsWhileRecording = newValue }
    }

    static var captureKeystrokes: Bool {
        get { AppSettings.captureKeystrokes }
        set { AppSettings.captureKeystrokes = newValue }
    }

    static var playClickSounds: Bool {
        get { AppSettings.playClickSounds }
        set { AppSettings.playClickSounds = newValue }
    }

    static var exportWidth: Int {
        get { AppSettings.exportWidth }
        set { AppSettings.exportWidth = newValue }
    }

    static var exportHeight: Int {
        get { AppSettings.exportHeight }
        set { AppSettings.exportHeight = newValue }
    }

    static var exportFPS: Int {
        get { AppSettings.exportFPS }
        set { AppSettings.exportFPS = newValue }
    }

    static var speechEngine: SpeechEnginePreference {
        get { AppSettings.speechEngine }
        set { AppSettings.speechEngine = newValue }
    }

    static var whisperModelSize: WhisperModelSize {
        get { AppSettings.whisperModelSize }
        set { AppSettings.whisperModelSize = newValue }
    }

    static var speechLanguage: SpeechLanguagePreference {
        get { AppSettings.speechLanguage }
        set { AppSettings.speechLanguage = newValue }
    }
}
