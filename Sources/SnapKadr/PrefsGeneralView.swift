import AppKit
import KadrKit
import SwiftUI

extension Notification.Name {
    static let showPrefsGeneralTab = Notification.Name("showPrefsGeneralTab")
}

struct PrefsGeneralView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var showSplash = SuiteSharedSettings.showSplash
    @State private var hideMenubar = SuiteSharedSettings.hideMenubarIcon
    @State private var urlScheme = SuiteSharedSettings.urlSchemeEnabled
    @State private var diagnostics = SuiteSharedSettings.allowDiagnostics

    @State private var folderPath = SuiteKadrSettings.projectsFolderURL.path
    @State private var remoteKind = ProjectCloudSettings.remoteKind
    @State private var autoUpload = ProjectCloudSettings.autoUploadAfterSession
    @State private var webdavURL = ProjectCloudSettings.webdavBaseURL
    @State private var webdavUser = ProjectCloudSettings.webdavUsername
    @State private var webdavPassword = ""
    @State private var webdavPrefix = ProjectCloudSettings.webdavPathPrefix
    @State private var s3Endpoint = ProjectCloudSettings.s3Endpoint
    @State private var s3Region = ProjectCloudSettings.s3Region
    @State private var s3Bucket = ProjectCloudSettings.s3Bucket
    @State private var s3AccessKey = ProjectCloudSettings.s3AccessKeyId
    @State private var s3Secret = ""
    @State private var s3Prefix = ProjectCloudSettings.s3PathPrefix
    @State private var yandexLabel = ProjectCloudSettings.yandexAccountLabel
    @State private var yandexPrefix = ProjectCloudSettings.yandexPathPrefix
    @State private var pendingCount = ProjectCloudStore.shared.pendingCount()
    @State private var statusMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceL) {
            systemSection
            storageSection
            permissionsSection
            extrasSection
        }
        .suiteAppear()
        .onAppear(perform: reloadStorage)
        .onReceive(NotificationCenter.default.publisher(for: ProjectCloudUploadQueue.didChangeNotification)) { _ in
            pendingCount = ProjectCloudStore.shared.pendingCount()
        }
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

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            SuiteSectionHeader(title: L10n.tr("Хранилище проектов", "Project storage"))
            SuiteCard {
                VStack(alignment: .leading, spacing: SuiteTheme.spaceM) {
                    Text(folderPath)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(SuiteTheme.textSecondary)
                        .lineLimit(2)
                    Button(L10n.tr("Выбрать…", "Choose…")) { chooseFolder() }
                        .controlSize(.small)

                    Picker(
                        L10n.tr("Удалённое хранилище", "Remote storage"),
                        selection: $remoteKind
                    ) {
                        Text(L10n.tr("Выкл", "Off")).tag(ProjectCloudRemoteKind.none)
                        Text("WebDAV").tag(ProjectCloudRemoteKind.webdav)
                        Text("S3").tag(ProjectCloudRemoteKind.s3)
                        Text(L10n.tr("Яндекс Диск", "Yandex Disk")).tag(ProjectCloudRemoteKind.yandex)
                    }
                    .onChange(of: remoteKind) { _, kind in
                        ProjectCloudSettings.setRemoteKind(kind, clearingPreviousSecrets: true)
                        webdavPassword = ""
                        s3Secret = ""
                        reloadStorage()
                    }

                    if remoteKind == .webdav {
                        webdavFields
                    } else if remoteKind == .s3 {
                        s3Fields
                    } else if remoteKind == .yandex {
                        yandexFields
                    }

                    if remoteKind != .none {
                        prefsToggle(
                            L10n.tr("Автозагрузка после сессии", "Auto-upload after session"),
                            $autoUpload
                        ) { ProjectCloudSettings.autoUploadAfterSession = $0 }

                        HStack(spacing: 8) {
                            Button(L10n.tr("Проверить соединение", "Test connection")) {
                                testConnection()
                            }
                            .controlSize(.small)

                            Button(L10n.tr("Загрузить сейчас", "Upload now")) {
                                flushQueue()
                            }
                            .controlSize(.small)
                        }

                        Text(L10n.tr(
                            "В очереди: \(pendingCount)",
                            "Queued: \(pendingCount)"
                        ))
                        .font(.system(size: 12))
                        .foregroundStyle(SuiteTheme.textSecondary)

                        if pendingCount > 0 {
                            Text(L10n.tr(
                                "Очередь уйдёт в выбранное сейчас хранилище.",
                                "Pending items upload to the currently selected remote."
                            ))
                            .font(.system(size: 11))
                            .foregroundStyle(SuiteTheme.textSecondary)
                        }
                    }

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(SuiteTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var webdavFields: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            field(L10n.tr("URL", "URL"), $webdavURL) {
                ProjectCloudSettings.webdavBaseURL = $0
            }
            field(L10n.tr("Имя пользователя", "Username"), $webdavUser) {
                ProjectCloudSettings.webdavUsername = $0
            }
            SecureField(L10n.tr("Пароль", "Password"), text: $webdavPassword)
                .textFieldStyle(.roundedBorder)
                .onChange(of: webdavPassword) { _, value in
                    guard !value.isEmpty else { return }
                    try? ProjectCloudKeychain.set(
                        value,
                        account: ProjectCloudKeychain.accountName(kind: .webdav, field: "password")
                    )
                }
            field(L10n.tr("Префикс пути", "Path prefix"), $webdavPrefix) {
                ProjectCloudSettings.webdavPathPrefix = $0
            }
        }
    }

    private var s3Fields: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            field(L10n.tr("Endpoint", "Endpoint"), $s3Endpoint) {
                ProjectCloudSettings.s3Endpoint = $0
            }
            field(L10n.tr("Регион", "Region"), $s3Region) {
                ProjectCloudSettings.s3Region = $0
            }
            field(L10n.tr("Bucket", "Bucket"), $s3Bucket) {
                ProjectCloudSettings.s3Bucket = $0
            }
            field(L10n.tr("Access Key ID", "Access Key ID"), $s3AccessKey) {
                ProjectCloudSettings.s3AccessKeyId = $0
            }
            SecureField(L10n.tr("Secret Access Key", "Secret Access Key"), text: $s3Secret)
                .textFieldStyle(.roundedBorder)
                .onChange(of: s3Secret) { _, value in
                    guard !value.isEmpty else { return }
                    try? ProjectCloudKeychain.set(
                        value,
                        account: ProjectCloudKeychain.accountName(kind: .s3, field: "secretAccessKey")
                    )
                }
            field(L10n.tr("Префикс пути", "Path prefix"), $s3Prefix) {
                ProjectCloudSettings.s3PathPrefix = $0
            }
        }
    }

    private var yandexFields: some View {
        VStack(alignment: .leading, spacing: SuiteTheme.spaceS) {
            if yandexLabel.isEmpty {
                Text(L10n.tr("Не подключено", "Not connected"))
                    .font(.system(size: 12))
                    .foregroundStyle(SuiteTheme.textSecondary)
            } else {
                Text(yandexLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(SuiteTheme.textSecondary)
            }
            HStack(spacing: 8) {
                Button(L10n.tr("Подключить", "Connect")) {
                    connectYandex()
                }
                .controlSize(.small)
                Button(L10n.tr("Отключить", "Disconnect")) {
                    disconnectYandex()
                }
                .controlSize(.small)
                .disabled(yandexLabel.isEmpty)
            }
            field(L10n.tr("Префикс пути", "Path prefix"), $yandexPrefix) {
                ProjectCloudSettings.yandexPathPrefix = $0
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

    private func field(_ title: String, _ binding: Binding<String>, onSet: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(SuiteTheme.textSecondary)
            TextField(title, text: binding)
                .textFieldStyle(.roundedBorder)
                .onChange(of: binding.wrappedValue) { _, v in onSet(v) }
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

    private func reloadStorage() {
        folderPath = SuiteKadrSettings.projectsFolderURL.path
        remoteKind = ProjectCloudSettings.remoteKind
        autoUpload = ProjectCloudSettings.autoUploadAfterSession
        webdavURL = ProjectCloudSettings.webdavBaseURL
        webdavUser = ProjectCloudSettings.webdavUsername
        webdavPrefix = ProjectCloudSettings.webdavPathPrefix
        s3Endpoint = ProjectCloudSettings.s3Endpoint
        s3Region = ProjectCloudSettings.s3Region
        s3Bucket = ProjectCloudSettings.s3Bucket
        s3AccessKey = ProjectCloudSettings.s3AccessKeyId
        s3Prefix = ProjectCloudSettings.s3PathPrefix
        yandexLabel = ProjectCloudSettings.yandexAccountLabel
        yandexPrefix = ProjectCloudSettings.yandexPathPrefix
        pendingCount = ProjectCloudStore.shared.pendingCount()
        webdavPassword = ""
        s3Secret = ""
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

    private func testConnection() {
        statusMessage = L10n.tr("Проверка…", "Testing…")
        Task {
            do {
                try await ProjectCloudStore.shared.testActiveConnection()
                await MainActor.run {
                    statusMessage = L10n.tr("Соединение успешно", "Connection OK")
                }
            } catch {
                await MainActor.run {
                    statusMessage = L10n.tr("Ошибка соединения", "Connection failed")
                }
            }
        }
    }

    private func flushQueue() {
        statusMessage = L10n.tr("Загрузка…", "Uploading…")
        Task {
            await ProjectCloudStore.shared.flushQueue()
            await MainActor.run {
                pendingCount = ProjectCloudStore.shared.pendingCount()
                statusMessage = pendingCount == 0
                    ? L10n.tr("Очередь пуста", "Queue empty")
                    : L10n.tr("Осталось в очереди: \(pendingCount)", "Still queued: \(pendingCount)")
            }
        }
    }

    private func connectYandex() {
        statusMessage = L10n.tr("Вход…", "Signing in…")
        Task { @MainActor in
            do {
                try await YandexOAuthClient().connect(presenter: NSApp.keyWindow)
                yandexLabel = ProjectCloudSettings.yandexAccountLabel
                statusMessage = L10n.tr("Яндекс Диск подключён", "Yandex Disk connected")
            } catch {
                statusMessage = L10n.tr("Не удалось войти", "Sign-in failed")
            }
        }
    }

    private func disconnectYandex() {
        try? YandexOAuthClient().disconnect()
        yandexLabel = ""
        statusMessage = L10n.tr("Отключено", "Disconnected")
    }
}
