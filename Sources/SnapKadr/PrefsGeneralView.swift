import AppKit
import KadrKit
import SwiftUI

struct PrefsGeneralView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var showSplash = SuiteSharedSettings.showSplash
    @State private var hideMenubar = SuiteSharedSettings.hideMenubarIcon
    @State private var urlScheme = SuiteSharedSettings.urlSchemeEnabled
    @State private var diagnostics = SuiteSharedSettings.allowDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            StenoCloudPrefsSection()
            systemSection
            permissionsSection
            extrasSection
        }
        .suiteAppear()
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Система", "System"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    prefsToggle(
                        L10n.tr("Запускать при входе", "Launch at login"),
                        $launchAtLogin
                    ) { LaunchAtLogin.isEnabled = $0 }

                    prefsToggle(
                        L10n.tr("Показывать splash", "Show splash"),
                        $showSplash
                    ) { SuiteSharedSettings.showSplash = $0 }
                }
            }
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Доступы", "Permissions"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    Text(L10n.tr(
                        "Экран, микрофон и камера запрашиваются при первом использовании Щёлка или Кадра.",
                        "Screen, microphone, and camera are requested on first use by Snap or Kadr."
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(SuiteTheme.textSecondary)

                    HStack(spacing: 8) {
                        privacyButton(L10n.tr("Экран", "Screen"), "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
                        privacyButton(L10n.tr("Микрофон", "Microphone"), "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
                        privacyButton(L10n.tr("Камера", "Camera"), "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
                    }
                }
            }
        }
    }

    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Дополнительно", "Advanced"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    prefsToggle(
                        L10n.tr("Скрыть иконку в меню", "Hide menu bar icon"),
                        $hideMenubar
                    ) { SuiteSharedSettings.hideMenubarIcon = $0 }

                    prefsToggle(
                        L10n.tr("Включить deep links (URL Scheme)", "Enable URL Scheme deep links"),
                        $urlScheme
                    ) { SuiteSharedSettings.urlSchemeEnabled = $0 }

                    prefsToggle(
                        L10n.tr("Разрешить сбор диагностики", "Allow diagnostics"),
                        $diagnostics
                    ) { SuiteSharedSettings.allowDiagnostics = $0 }
                }
            }
        }
    }

    private func prefsToggle(_ title: String, _ binding: Binding<Bool>, onSet: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = $0; onSet($0) }
        )) {
            Text(title)
                .foregroundStyle(SuiteTheme.textPrimary)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private func privacyButton(_ title: String, _ urlString: String) -> some View {
        Button(title) {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct StenoCloudPrefsSection: View {
    @State private var folderPath = SuiteKadrSettings.projectsFolderURL.path
    @State private var autoUpload = StenoCloudSettings.autoUploadAfterSession
    @State private var webdavEnabled = StenoCloudSettings.webdavEnabled
    @State private var webdavBaseURL = StenoCloudSettings.webdavBaseURL
    @State private var webdavUsername = StenoCloudSettings.webdavUsername
    @State private var webdavPassword = ""
    @State private var webdavPathPrefix = StenoCloudSettings.webdavPathPrefix
    @State private var s3Enabled = StenoCloudSettings.s3Enabled
    @State private var s3Endpoint = StenoCloudSettings.s3Endpoint
    @State private var s3Region = StenoCloudSettings.s3Region
    @State private var s3Bucket = StenoCloudSettings.s3Bucket
    @State private var s3AccessKeyId = StenoCloudSettings.s3AccessKeyId
    @State private var s3Secret = ""
    @State private var s3PathPrefix = StenoCloudSettings.s3PathPrefix
    @State private var yandexEnabled = StenoCloudSettings.yandexEnabled
    @State private var yandexAccountLabel = StenoCloudSettings.yandexAccountLabel
    @State private var yandexPathPrefix = StenoCloudSettings.yandexPathPrefix
    @State private var yandexOAuthClientID = StenoCloudSettings.yandexOAuthClientID
    @State private var yandexOAuthClientSecret = ""
    @State private var queueItems: [StenoCloudQueueItem] = []
    @State private var statusMessage = ""
    @State private var isBusy = false

    private let oauth = YandexOAuthSession()

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Хранилище проектов", "Project storage"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    localFolderBlock
                    Divider().opacity(0.35)
                    webdavBlock
                    Divider().opacity(0.35)
                    s3Block
                    Divider().opacity(0.35)
                    yandexBlock
                    Divider().opacity(0.35)
                    cloudToggle(
                        L10n.tr("Автозагрузка после сессии", "Auto-upload after session"),
                        $autoUpload
                    ) { StenoCloudSettings.autoUploadAfterSession = $0 }
                    queueBlock
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(SuiteTheme.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            reloadQueue()
            loadSecrets()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stenoCloudQueueDidChange)) { _ in
            reloadQueue()
        }
    }

    private var localFolderBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("Локальная папка", "Local folder"))
                .font(.system(size: 12, weight: .semibold))
            Text(folderPath)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(SuiteTheme.textSecondary)
                .lineLimit(2)
            Button(L10n.tr("Выбрать…", "Choose…")) { chooseFolder() }
                .controlSize(.small)
        }
    }

    private var webdavBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            cloudToggle(L10n.tr("WebDAV", "WebDAV"), $webdavEnabled) {
                StenoCloudSettings.webdavEnabled = $0
            }
            if webdavEnabled {
                cloudField(L10n.tr("URL сервера", "Server URL"), $webdavBaseURL) {
                    StenoCloudSettings.webdavBaseURL = $0
                }
                cloudField(L10n.tr("Имя пользователя", "Username"), $webdavUsername) {
                    StenoCloudSettings.webdavUsername = $0
                }
                SecureField(L10n.tr("Пароль", "Password"), text: $webdavPassword)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: webdavPassword) { _, v in
                        guard !v.isEmpty else { return }
                        try? StenoCloudKeychain.set(
                            v,
                            account: StenoCloudKeychain.accountName(destination: .webdav, field: "password")
                        )
                    }
                cloudField(L10n.tr("Путь на сервере", "Remote path prefix"), $webdavPathPrefix) {
                    StenoCloudSettings.webdavPathPrefix = $0
                }
                testButton(.webdav)
            }
        }
    }

    private var s3Block: some View {
        VStack(alignment: .leading, spacing: 8) {
            cloudToggle(L10n.tr("S3-совместимое", "S3-compatible"), $s3Enabled) {
                StenoCloudSettings.s3Enabled = $0
            }
            if s3Enabled {
                cloudField(L10n.tr("Endpoint", "Endpoint"), $s3Endpoint) {
                    StenoCloudSettings.s3Endpoint = $0
                }
                cloudField(L10n.tr("Region", "Region"), $s3Region) {
                    StenoCloudSettings.s3Region = $0
                }
                cloudField(L10n.tr("Bucket", "Bucket"), $s3Bucket) {
                    StenoCloudSettings.s3Bucket = $0
                }
                cloudField(L10n.tr("Access Key ID", "Access Key ID"), $s3AccessKeyId) {
                    StenoCloudSettings.s3AccessKeyId = $0
                }
                SecureField(L10n.tr("Secret Access Key", "Secret Access Key"), text: $s3Secret)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: s3Secret) { _, v in
                        guard !v.isEmpty else { return }
                        try? StenoCloudKeychain.set(
                            v,
                            account: StenoCloudKeychain.accountName(destination: .s3, field: "secretAccessKey")
                        )
                    }
                cloudField(L10n.tr("Префикс", "Prefix"), $s3PathPrefix) {
                    StenoCloudSettings.s3PathPrefix = $0
                }
                testButton(.s3)
            }
        }
    }

    private var yandexBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            cloudToggle(L10n.tr("Яндекс Диск", "Yandex Disk"), $yandexEnabled) {
                StenoCloudSettings.yandexEnabled = $0
            }
            if yandexEnabled {
                cloudField(L10n.tr("OAuth Client ID", "OAuth Client ID"), $yandexOAuthClientID) {
                    StenoCloudSettings.yandexOAuthClientID = $0
                }
                SecureField(L10n.tr("OAuth Client Secret", "OAuth Client Secret"), text: $yandexOAuthClientSecret)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: yandexOAuthClientSecret) { _, v in
                        let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        try? StenoCloudKeychain.set(
                            trimmed,
                            account: YandexOAuthSession.clientSecretAccount
                        )
                    }
                Text(L10n.tr(
                    "Redirect URI в кабинете Яндекса: https://oauth.yandex.ru/verification_code — после «Подключить» вставьте код со страницы.",
                    "Yandex Redirect URI: https://oauth.yandex.ru/verification_code — after Connect, paste the code from that page."
                ))
                .font(.system(size: 11))
                .foregroundStyle(SuiteTheme.textTertiary)
                HStack(spacing: 8) {
                    Button(L10n.tr("Создать приложение", "Create app")) {
                        if let url = URL(string: "https://oauth.yandex.ru/client/new") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                    if yandexAccountLabel.isEmpty {
                        Button(L10n.tr("Подключить", "Connect")) { connectYandex() }
                            .controlSize(.small)
                            .disabled(isBusy)
                    } else {
                        Text(yandexAccountLabel)
                            .font(.system(size: 12))
                            .foregroundStyle(SuiteTheme.textSecondary)
                        Button(L10n.tr("Отключить", "Disconnect")) { disconnectYandex() }
                            .controlSize(.small)
                    }
                }
                cloudField(L10n.tr("Папка на Диске", "Disk folder path"), $yandexPathPrefix) {
                    StenoCloudSettings.yandexPathPrefix = $0
                }
                testButton(.yandex)
            }
        }
    }

    private var queueBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("Очередь загрузок", "Upload queue"))
                .font(.system(size: 12, weight: .semibold))
            if queueItems.isEmpty {
                Text(L10n.tr("Нет отложенных загрузок", "No pending uploads"))
                    .font(.system(size: 12))
                    .foregroundStyle(SuiteTheme.textSecondary)
            } else {
                ForEach(StenoCloudSync.shared.pendingSummary(), id: \.destination) { row in
                    Text("\(row.destination.rawValue): \(row.count)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(SuiteTheme.textSecondary)
                }
                ForEach(queueItems.prefix(6), id: \.projectPath) { item in
                    HStack {
                        Text(item.displayName)
                            .font(.system(size: 11, design: .monospaced))
                        Spacer()
                        Text(item.destination.rawValue)
                            .font(.system(size: 11))
                            .foregroundStyle(SuiteTheme.textSecondary)
                        Button(L10n.tr("Повторить", "Retry")) { retryItem(item) }
                            .controlSize(.mini)
                    }
                }
            }
            Button(L10n.tr("Загрузить сейчас", "Upload now")) { flushQueue() }
                .controlSize(.small)
                .disabled(isBusy || queueItems.isEmpty)
        }
    }

    private func cloudToggle(_ title: String, _ binding: Binding<Bool>, onSet: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(
            get: { binding.wrappedValue },
            set: { binding.wrappedValue = $0; onSet($0) }
        )) {
            Text(title).foregroundStyle(SuiteTheme.textPrimary)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private func cloudField(_ title: String, _ binding: Binding<String>, onSet: @escaping (String) -> Void) -> some View {
        HStack {
            Text(title)
                .frame(width: 130, alignment: .leading)
            TextField("", text: binding)
                .textFieldStyle(.roundedBorder)
                .onChange(of: binding.wrappedValue) { _, v in onSet(v) }
        }
    }

    private func testButton(_ destination: StenoCloudDestination) -> some View {
        Button(L10n.tr("Проверить соединение", "Test connection")) {
            testConnection(destination)
        }
        .controlSize(.small)
        .disabled(isBusy)
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

    private func loadSecrets() {
        webdavPassword = (try? StenoCloudKeychain.get(
            account: StenoCloudKeychain.accountName(destination: .webdav, field: "password")
        )) ?? ""
        s3Secret = (try? StenoCloudKeychain.get(
            account: StenoCloudKeychain.accountName(destination: .s3, field: "secretAccessKey")
        )) ?? ""
    }

    private func reloadQueue() {
        queueItems = StenoCloudSync.shared.queue.items()
    }

    private func testConnection(_ destination: StenoCloudDestination) {
        isBusy = true
        statusMessage = L10n.tr("Проверка…", "Testing…")
        Task {
            do {
                try await StenoCloudSync.shared.testConnection(for: destination)
                await MainActor.run {
                    statusMessage = L10n.tr("Соединение успешно", "Connection succeeded")
                    isBusy = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = L10n.tr("Ошибка соединения", "Connection failed")
                    isBusy = false
                }
            }
        }
    }

    private func flushQueue() {
        isBusy = true
        statusMessage = L10n.tr("Загрузка…", "Uploading…")
        Task {
            await StenoCloudSync.shared.flushQueue()
            await MainActor.run {
                reloadQueue()
                isBusy = false
                statusMessage = queueItems.isEmpty
                    ? L10n.tr("Очередь пуста", "Queue empty")
                    : L10n.tr("Осталось в очереди", "Still queued")
            }
        }
    }

    private func retryItem(_ item: StenoCloudQueueItem) {
        let url = URL(fileURLWithPath: item.projectPath, isDirectory: true)
        Task {
            await StenoCloudSync.shared.retry(projectURL: url, destination: item.destination)
            await MainActor.run { reloadQueue() }
        }
    }

    private func connectYandex() {
        isBusy = true
        statusMessage = L10n.tr("Вход…", "Signing in…")
        Task { @MainActor in
            do {
                let presenter = NSApp.keyWindow
                    ?? NSApp.mainWindow
                    ?? NSApp.windows.first(where: { $0.isVisible })
                try await oauth.connect(presenter: presenter)
                yandexAccountLabel = L10n.tr("Яндекс Диск подключён", "Yandex Disk connected")
                StenoCloudSettings.yandexAccountLabel = yandexAccountLabel
                statusMessage = yandexAccountLabel
            } catch {
                let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                statusMessage = detail
                if case StenoCloudError.missingYandexClientID = error {
                    if let url = URL(string: "https://oauth.yandex.ru/client/new") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            isBusy = false
        }
    }

    private func disconnectYandex() {
        try? oauth.disconnect()
        yandexAccountLabel = ""
        statusMessage = L10n.tr("Отключено", "Disconnected")
    }
}
