import Foundation

private var failures = 0
private func expect(_ c: @autoclosure () -> Bool, _ m: String) {
    if c() { print("PASS  \(m)") } else { failures += 1; print("FAIL  \(m)") }
}

@main
enum StenoSettingsTests {
    static func main() {
        let suite = "steno.settings.tests.\(UUID().uuidString)"
        guard let ud = UserDefaults(suiteName: suite) else {
            fputs("FAIL  could not create suite\n", stderr)
            exit(1)
        }
        ud.removePersistentDomain(forName: suite)
        StenoSettings.defaults = ud

        expect(StenoSettings.enabledSources == Set(StenoSource.allCases), "missing key → all enabled")
        expect(StenoSettings.isEnabled(.zoom), "zoom on by default")

        StenoSettings.setEnabled(.telegram, false)
        expect(!StenoSettings.isEnabled(.telegram), "telegram off")
        expect(StenoSettings.enabledSources.count == 4, "four remain")
        expect(StenoSettings.isEnabled(.zoom), "zoom still on")

        StenoSettings.enabledSources = []
        expect(StenoSettings.enabledSources.isEmpty, "empty array all off")
        expect(!StenoSettings.isEnabled(.zoom), "zoom off when empty")

        ud.set(["zoom", "not-a-source", "telegram"], forKey: "steno.enabledSources")
        expect(StenoSettings.enabledSources == [.zoom, .telegram], "unknown raw ignored")

        expect(StenoSettings.isEnabled, "master on by default")

        StenoSettings.isEnabled = false
        expect(!StenoSettings.isEnabled, "master off persists")

        ud.removePersistentDomain(forName: suite)
        StenoSettings.defaults = ud
        expect(StenoSettings.isEnabled, "missing master key → on")

        ud.removePersistentDomain(forName: suite)
        exit(failures == 0 ? 0 : 1)
    }
}
