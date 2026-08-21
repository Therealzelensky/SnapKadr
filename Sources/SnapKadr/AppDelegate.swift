import AppKit
import SnapKit
import KadrKit
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: SuiteStatusController?
    private var prefs: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppBranding.applyApplicationIcon()
        UpdateService.shared.start()
        InstallLocationGuard.warnIfNeeded()
        SnapEngine.shared.prepare()
        KadrEngine.shared.prepare()
        SuiteHotkeyMonitor.shared.start()

        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        TranscriptQuickActionInstaller.installIfNeeded()

        status = SuiteStatusController(
            onPreferences: { [weak self] in self?.showPreferences() },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPreferences()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "kadr" {
                KadrEngine.shared.openProject(at: url)
            } else if isTranscribable(url) {
                KadrEngine.shared.transcribeFile(at: url)
            }
        }
    }

    /// Finder / Services: «Распознать текст»
    @objc func transcribeService(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        var urls: [URL] = []
        if let read = pboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] {
            urls.append(contentsOf: read)
        }
        if urls.isEmpty,
           let paths = pboard.propertyList(forType: .init("NSFilenamesPboardType")) as? [String] {
            urls.append(contentsOf: paths.map { URL(fileURLWithPath: $0) })
        }
        let media = urls.filter(isTranscribable).prefix(5).map { $0 }
        guard !media.isEmpty else {
            error.pointee = "Нет аудио или видео файлов." as NSString
            return
        }
        KadrEngine.shared.transcribeFiles(at: media)
    }

    private func isTranscribable(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext == "kadr" { return false }
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .audio) || type.conforms(to: .movie) || type.conforms(to: .audiovisualContent)
        }
        return ["m4a", "mp3", "wav", "caf", "aiff", "aac", "mp4", "mov", "m4v"].contains(ext)
    }

    private func showPreferences() {
        if prefs == nil {
            prefs = PreferencesWindowController()
        }
        prefs?.show()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
