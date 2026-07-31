import AppKit
import AVFoundation
import SwiftUI

struct PrefsKadrView: View {
    @State private var folderPath = SuiteKadrSettings.projectsFolderURL.path
    @State private var countdownMs = SuiteKadrSettings.recordingCountdownMs
    @State private var autoZoom = SuiteKadrSettings.createAutomaticZooms
    @State private var recordMic = SuiteKadrSettings.recordMicrophone
    @State private var noiseReduction = SuiteKadrSettings.noiseReduction
    @State private var systemAudio = SuiteKadrSettings.captureSystemAudio
    @State private var recordWebcam = SuiteKadrSettings.recordWebcam
    @State private var hideIcons = SuiteKadrSettings.hideDesktopIconsWhileRecording
    @State private var clickSounds = SuiteKadrSettings.playClickSounds
    @State private var micID = SuiteKadrSettings.preferredMicrophoneUID ?? ""
    @State private var cameraID = SuiteKadrSettings.preferredCameraUniqueID ?? ""
    @State private var micOptions: [(id: String, name: String)] = []
    @State private var cameraOptions: [(id: String, name: String)] = []
    @State private var exportResIndex = 0
    @State private var exportFPSIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            folderSection
            recordingSection
            exportSection
        }
        .suiteAppear()
        .onAppear(perform: reloadDevices)
    }

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Папка проектов", "Projects folder"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    Text(folderPath)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(SuiteTheme.textSecondary)
                        .lineLimit(2)
                    Button(L10n.tr("Выбрать…", "Choose…")) { chooseFolder() }
                        .controlSize(.small)
                }
            }
        }
    }

    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Запись", "Recording"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    HStack {
                        Text(L10n.tr("Обратный отсчёт (мс)", "Countdown (ms)"))
                        Spacer()
                        TextField("", value: $countdownMs, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: countdownMs) { _, v in
                                SuiteKadrSettings.recordingCountdownMs = max(0, v)
                            }
                    }

                    liveToggle(L10n.tr("Создавать автозумы", "Create automatic zooms"), $autoZoom) {
                        SuiteKadrSettings.createAutomaticZooms = $0
                    }
                    liveToggle(L10n.tr("Записывать микрофон", "Record microphone"), $recordMic) {
                        SuiteKadrSettings.recordMicrophone = $0
                    }

                    Picker(L10n.tr("Микрофон", "Microphone"), selection: $micID) {
                        Text(L10n.tr("Системный по умолчанию", "System default")).tag("")
                        ForEach(micOptions, id: \.id) { opt in
                            Text(opt.name).tag(opt.id)
                        }
                    }
                    .disabled(!recordMic)
                    .onChange(of: micID) { _, v in
                        SuiteKadrSettings.preferredMicrophoneUID = v.isEmpty ? nil : v
                    }

                    liveToggle(L10n.tr("Шумодав микрофона", "Mic noise reduction"), $noiseReduction) {
                        SuiteKadrSettings.noiseReduction = $0
                    }
                    liveToggle(L10n.tr("Системный звук", "System audio"), $systemAudio) {
                        SuiteKadrSettings.captureSystemAudio = $0
                    }
                    liveToggle(L10n.tr("Веб-камера / Continuity", "Webcam / Continuity"), $recordWebcam) {
                        SuiteKadrSettings.recordWebcam = $0
                    }

                    Picker(L10n.tr("Камера", "Camera"), selection: $cameraID) {
                        ForEach(cameraOptions, id: \.id) { opt in
                            Text(opt.name).tag(opt.id)
                        }
                    }
                    .disabled(!recordWebcam)
                    .onChange(of: cameraID) { _, v in
                        SuiteKadrSettings.preferredCameraUniqueID = v.isEmpty ? nil : v
                    }

                    liveToggle(L10n.tr("Скрывать иконки рабочего стола", "Hide desktop icons"), $hideIcons) {
                        SuiteKadrSettings.hideDesktopIconsWhileRecording = $0
                    }
                    liveToggle(L10n.tr("Звуки кликов при экспорте", "Click sounds on export"), $clickSounds) {
                        SuiteKadrSettings.playClickSounds = $0
                    }
                }
            }
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Экспорт по умолчанию", "Default export"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    Picker(L10n.tr("Разрешение", "Resolution"), selection: $exportResIndex) {
                        Text("1920×1080").tag(0)
                        Text("2560×1440").tag(1)
                        Text("3840×2160 (4K)").tag(2)
                    }
                    .onChange(of: exportResIndex) { _, idx in
                        switch idx {
                        case 1: SuiteKadrSettings.exportWidth = 2560; SuiteKadrSettings.exportHeight = 1440
                        case 2: SuiteKadrSettings.exportWidth = 3840; SuiteKadrSettings.exportHeight = 2160
                        default: SuiteKadrSettings.exportWidth = 1920; SuiteKadrSettings.exportHeight = 1080
                        }
                    }

                    Picker("FPS", selection: $exportFPSIndex) {
                        Text("30 fps").tag(0)
                        Text("60 fps").tag(1)
                    }
                    .onChange(of: exportFPSIndex) { _, idx in
                        SuiteKadrSettings.exportFPS = idx == 1 ? 60 : 30
                    }
                }
            }
        }
    }

    private func liveToggle(_ title: String, _ binding: Binding<Bool>, onSet: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = $0; onSet($0) }
        )) {
            Text(title).foregroundStyle(SuiteTheme.textPrimary)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private func reloadDevices() {
        folderPath = SuiteKadrSettings.projectsFolderURL.path
        countdownMs = SuiteKadrSettings.recordingCountdownMs
        autoZoom = SuiteKadrSettings.createAutomaticZooms
        recordMic = SuiteKadrSettings.recordMicrophone
        noiseReduction = SuiteKadrSettings.noiseReduction
        systemAudio = SuiteKadrSettings.captureSystemAudio
        recordWebcam = SuiteKadrSettings.recordWebcam
        hideIcons = SuiteKadrSettings.hideDesktopIconsWhileRecording
        clickSounds = SuiteKadrSettings.playClickSounds
        micID = SuiteKadrSettings.preferredMicrophoneUID ?? ""
        cameraID = SuiteKadrSettings.preferredCameraUniqueID ?? ""

        let audio = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        ).devices
        micOptions = audio.map { ($0.uniqueID, $0.localizedName) }

        let video = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
        cameraOptions = [("", L10n.tr("Авто", "Auto"))] + video.map { ($0.uniqueID, $0.localizedName) }

        switch (SuiteKadrSettings.exportWidth, SuiteKadrSettings.exportHeight) {
        case (2560, 1440): exportResIndex = 1
        case (3840, 2160): exportResIndex = 2
        default: exportResIndex = 0
        }
        exportFPSIndex = SuiteKadrSettings.exportFPS == 60 ? 1 : 0
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = SuiteKadrSettings.projectsFolderURL
        guard panel.runModal() == .OK, let url = panel.url else { return }
        SuiteKadrSettings.projectsFolderURL = url
        folderPath = url.path
    }
}
