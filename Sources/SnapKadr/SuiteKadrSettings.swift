import Foundation

/// Kadr prefs keys — same raw names as Kadr beta `AppSettings` so KadrKit can adopt later.
enum SuiteKadrSettings {
    private static let d = UserDefaults.standard

    static var projectsFolderURL: URL {
        get {
            if let path = d.string(forKey: "projectsFolderPath"), !path.isEmpty {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            return docs.appendingPathComponent("Кадр Проекты", isDirectory: true)
        }
        set { d.set(newValue.path, forKey: "projectsFolderPath") }
    }

    static var recordingCountdownMs: Int {
        get { d.object(forKey: "recordingCountdownMs") as? Int ?? 3000 }
        set { d.set(newValue, forKey: "recordingCountdownMs") }
    }

    static var createAutomaticZooms: Bool {
        get {
            if d.object(forKey: "createAutomaticZooms") == nil { return true }
            return d.bool(forKey: "createAutomaticZooms")
        }
        set { d.set(newValue, forKey: "createAutomaticZooms") }
    }

    static var recordMicrophone: Bool {
        get {
            if d.object(forKey: "recordMicrophone") == nil { return true }
            return d.bool(forKey: "recordMicrophone")
        }
        set { d.set(newValue, forKey: "recordMicrophone") }
    }

    static var preferredMicrophoneUID: String? {
        get {
            let v = d.string(forKey: "preferredMicrophoneUID")
            return (v?.isEmpty == false) ? v : nil
        }
        set {
            if let newValue, !newValue.isEmpty {
                d.set(newValue, forKey: "preferredMicrophoneUID")
            } else {
                d.removeObject(forKey: "preferredMicrophoneUID")
            }
        }
    }

    static var noiseReduction: Bool {
        get {
            if d.object(forKey: "noiseReduction") == nil { return true }
            return d.bool(forKey: "noiseReduction")
        }
        set { d.set(newValue, forKey: "noiseReduction") }
    }

    static var captureSystemAudio: Bool {
        get {
            if d.object(forKey: "captureSystemAudio") == nil { return true }
            return d.bool(forKey: "captureSystemAudio")
        }
        set { d.set(newValue, forKey: "captureSystemAudio") }
    }

    static var recordWebcam: Bool {
        get { d.bool(forKey: "recordWebcam") }
        set { d.set(newValue, forKey: "recordWebcam") }
    }

    static var preferredCameraUniqueID: String? {
        get {
            let v = d.string(forKey: "preferredCameraUniqueID")
            return (v?.isEmpty == false) ? v : nil
        }
        set {
            if let newValue, !newValue.isEmpty {
                d.set(newValue, forKey: "preferredCameraUniqueID")
            } else {
                d.removeObject(forKey: "preferredCameraUniqueID")
            }
        }
    }

    static var hideDesktopIconsWhileRecording: Bool {
        get { d.bool(forKey: "hideDesktopIconsWhileRecording") }
        set { d.set(newValue, forKey: "hideDesktopIconsWhileRecording") }
    }

    static var playClickSounds: Bool {
        get { d.bool(forKey: "playClickSounds") }
        set { d.set(newValue, forKey: "playClickSounds") }
    }

    static var exportWidth: Int {
        get { d.object(forKey: "exportWidth") as? Int ?? 1920 }
        set { d.set(newValue, forKey: "exportWidth") }
    }

    static var exportHeight: Int {
        get { d.object(forKey: "exportHeight") as? Int ?? 1080 }
        set { d.set(newValue, forKey: "exportHeight") }
    }

    static var exportFPS: Int {
        get { d.object(forKey: "exportFPS") as? Int ?? 60 }
        set { d.set(newValue, forKey: "exportFPS") }
    }
}
