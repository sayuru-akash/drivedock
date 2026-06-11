import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general
        case uploads
        case accounts
        case network
        case privacy
        case advanced

        var displayName: String {
            switch self {
            case .general: return "General"
            case .uploads: return "Uploads"
            case .accounts: return "Accounts"
            case .network: return "Network"
            case .privacy: return "Privacy"
            case .advanced: return "Advanced"
            }
        }

        var systemImage: String {
            switch self {
            case .general: return "gearshape"
            case .uploads: return "arrow.up.circle"
            case .accounts: return "person.circle"
            case .network: return "network"
            case .privacy: return "lock.shield"
            case .advanced: return "wrench.and.screwdriver"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with close button
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            TabView(selection: $selectedTab) {
                GeneralSettingsView()
                    .tabItem {
                        Label(SettingsTab.general.displayName, systemImage: SettingsTab.general.systemImage)
                    }
                    .tag(SettingsTab.general)

                UploadSettingsView()
                    .tabItem {
                        Label(SettingsTab.uploads.displayName, systemImage: SettingsTab.uploads.systemImage)
                    }
                    .tag(SettingsTab.uploads)

                AccountSettingsView()
                    .tabItem {
                        Label(SettingsTab.accounts.displayName, systemImage: SettingsTab.accounts.systemImage)
                    }
                    .tag(SettingsTab.accounts)

                NetworkSettingsView()
                    .tabItem {
                        Label(SettingsTab.network.displayName, systemImage: SettingsTab.network.systemImage)
                    }
                    .tag(SettingsTab.network)

                PrivacySettingsView()
                    .tabItem {
                        Label(SettingsTab.privacy.displayName, systemImage: SettingsTab.privacy.systemImage)
                    }
                    .tag(SettingsTab.privacy)

                AdvancedSettingsView()
                    .tabItem {
                        Label(SettingsTab.advanced.displayName, systemImage: SettingsTab.advanced.systemImage)
                    }
                    .tag(SettingsTab.advanced)
            }
        }
        .frame(width: 620, height: 500)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState

    private let startScreenOptions: [SidebarItem] = [
        .uploads, .queue, .active, .completed, .failed, .history
    ]

    var body: some View {
        @Bindable var settings = appState.settings

        Form {
            Section("Appearance") {
                Picker("Theme", selection: $settings.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }

                Picker("Accent color", selection: $settings.accentColor) {
                    ForEach(AccentStyle.allCases, id: \.self) { style in
                        HStack {
                            Circle()
                                .fill(style.tintColor)
                                .frame(width: 10, height: 10)
                            Text(style.displayName)
                        }
                        .tag(style)
                    }
                }

                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
                Toggle("Show Dock icon", isOn: $settings.showDockIcon)
            }

            Section("Behavior") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Confirm before quitting with active uploads", isOn: $settings.confirmQuitWithActiveUploads)

                Picker("Default start screen", selection: $settings.defaultStartScreen) {
                    ForEach(startScreenOptions, id: \.self) { item in
                        Label(item.displayName, systemImage: item.systemImage)
                            .tag(item)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.theme) { _, _ in settings.save() }
        .onChange(of: settings.accentColor) { _, _ in settings.save() }
        .onChange(of: settings.showMenuBarIcon) { _, _ in settings.save() }
        .onChange(of: settings.showDockIcon) { _, _ in settings.save() }
        .onChange(of: settings.launchAtLogin) { _, _ in settings.save() }
        .onChange(of: settings.confirmQuitWithActiveUploads) { _, _ in settings.save() }
        .onChange(of: settings.defaultStartScreen) { _, _ in settings.save() }
    }
}

// MARK: - Upload Settings

struct UploadSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var settings = appState.settings

        Form {
            Section("Default Behavior") {
                Picker("Upload mode", selection: $settings.defaultUploadMode) {
                    ForEach(UploadMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.displayName)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(mode)
                    }
                }

                Picker("Destination", selection: $settings.defaultDestination) {
                    ForEach(DestinationDefault.allCases, id: \.self) { dest in
                        Text(dest.displayName).tag(dest)
                    }
                }

                Picker("Duplicate handling", selection: $settings.defaultDuplicateMode) {
                    ForEach(DuplicateMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("Files") {
                Toggle("Ignore hidden files", isOn: $settings.ignoreHiddenFiles)
                Toggle("Ignore .DS_Store", isOn: $settings.ignoreDSStore)
                Toggle("Preserve folder structure", isOn: $settings.preserveFolderStructure)
            }

            Section("Retry") {
                Toggle("Auto-retry failed uploads", isOn: $settings.autoRetryFailed)
                Toggle("Resume uploads on app launch", isOn: $settings.resumeOnLaunch)

                Stepper("Max parallel uploads: \(settings.maxParallelUploads)", value: $settings.maxParallelUploads, in: 1...10)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.defaultUploadMode) { _, _ in settings.save() }
        .onChange(of: settings.defaultDestination) { _, _ in settings.save() }
        .onChange(of: settings.defaultDuplicateMode) { _, _ in settings.save() }
        .onChange(of: settings.ignoreHiddenFiles) { _, _ in settings.save() }
        .onChange(of: settings.ignoreDSStore) { _, _ in settings.save() }
        .onChange(of: settings.preserveFolderStructure) { _, _ in settings.save() }
        .onChange(of: settings.autoRetryFailed) { _, _ in settings.save() }
        .onChange(of: settings.resumeOnLaunch) { _, _ in settings.save() }
        .onChange(of: settings.maxParallelUploads) { _, _ in settings.save() }
    }
}

// MARK: - Account Settings

struct AccountSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Connected Accounts") {
                if appState.auth.accounts.isEmpty {
                    Text("No accounts connected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.auth.accounts) { account in
                        HStack {
                            Image(systemName: account.tokenStatus.systemImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                                .foregroundStyle(account.tokenStatus == .valid ? .green : .orange)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading) {
                                Text(account.displayName)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(account.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(account.tokenStatus.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Button("Disconnect") {
                                try? appState.auth.disconnectAccount(account.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                Button {
                    Task {
                        _ = try? await appState.auth.startAuthentication()
                    }
                } label: {
                    Label("Add Google Account", systemImage: "plus.circle")
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Network Settings

struct NetworkSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var settings = appState.settings

        Form {
            Section("Bandwidth") {
                Toggle("Limit upload bandwidth", isOn: Binding(
                    get: { settings.bandwidthLimitKBps > 0 },
                    set: { settings.bandwidthLimitKBps = $0 ? 1024 : 0 }
                ))

                if settings.bandwidthLimitKBps > 0 {
                    Stepper("Limit: \(settings.bandwidthLimitKBps) KB/s", value: $settings.bandwidthLimitKBps, in: 100...10240, step: 100)
                }
            }

            Section("Network Conditions") {
                Toggle("Pause on metered network", isOn: $settings.pauseOnMeteredNetwork)
                    .help("Automatically pause uploads when connected to a metered or cellular network")
                Toggle("Pause on VPN change", isOn: $settings.pauseOnVPNChange)
                    .help("Pause uploads when the VPN connection changes")
            }

            Section("Notifications") {
                Picker("Notify me", selection: $settings.notificationPreference) {
                    ForEach(NotificationPreference.allCases, id: \.self) { pref in
                        Text(pref.displayName).tag(pref)
                    }
                }

                Toggle("Notify on errors", isOn: $settings.notifyOnErrors)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.bandwidthLimitKBps) { _, _ in settings.save() }
        .onChange(of: settings.notificationPreference) { _, _ in settings.save() }
        .onChange(of: settings.notifyOnErrors) { _, _ in settings.save() }
        .onChange(of: settings.pauseOnMeteredNetwork) { _, _ in settings.save() }
        .onChange(of: settings.pauseOnVPNChange) { _, _ in settings.save() }
    }
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showClearConfirmation = false
    @State private var showRemoveTokensConfirmation = false
    @State private var localDataInfo: (files: [String], totalSize: String) = ([], "")

    var body: some View {
        Form {
            Section("Local Data") {
                Button("Clear upload history") {
                    appState.persistence.clearHistory()
                }

                Button("Clear queue cache") {
                    appState.engine.clearCompleted()
                    appState.persistence.saveQueue([])
                    appState.persistence.saveBatches([])
                }

                Button("Clear all local data") {
                    showClearConfirmation = true
                }
                .foregroundStyle(.red)
            }

            Section("Data Stored Locally") {
                if localDataInfo.files.isEmpty {
                    Text("No local data files found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(localDataInfo.files, id: \.self) { fileName in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(fileName)
                            Spacer()
                        }
                    }

                    HStack {
                        Text("Total size")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(localDataInfo.totalSize)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Security") {
                Text("OAuth tokens are stored securely in macOS Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Remove all tokens from Keychain") {
                    showRemoveTokensConfirmation = true
                }
                .foregroundStyle(.red)

                Text("DriveDock does not include analytics or tracking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadLocalDataInfo()
        }
        .alert("Clear All Local Data", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Everything", role: .destructive) {
                appState.engine.pauseAll()
                appState.persistence.clearAllLocalData()
                loadLocalDataInfo()
            }
        } message: {
            Text("This will remove all upload history, queue data, and cached settings. OAuth tokens in Keychain will not be affected.")
        }
        .alert("Remove All Tokens", isPresented: $showRemoveTokensConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove All Tokens", role: .destructive) {
                try? KeychainService.shared.deleteAll()
                loadLocalDataInfo()
            }
        } message: {
            Text("This will remove all OAuth tokens from Keychain. You will need to reconnect your Google accounts.")
        }
    }

    private func loadLocalDataInfo() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DriveDock")

        guard let contents = try? fm.contentsOfDirectory(atPath: appSupport.path) else {
            localDataInfo = ([], "")
            return
        }

        let jsonFiles = contents.filter { $0.hasSuffix(".json") }
        var totalSize: Int64 = 0

        for file in jsonFiles {
            let fileURL = appSupport.appendingPathComponent(file)
            if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }

        localDataInfo = (
            jsonFiles,
            ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        )
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var settings = appState.settings

        Form {
            Section("Upload") {
                Stepper("Max retry count: \(settings.maxRetryCount)", value: $settings.maxRetryCount, in: 1...20)

                Stepper("Max active uploads: \(settings.maxActiveUploads)", value: $settings.maxActiveUploads, in: 1...10)
                    .help("Maximum number of concurrent uploads, overrides upload mode")

                Picker("Chunk size", selection: $settings.chunkSize) {
                    ForEach(ChunkSizeOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .help("Size of each upload chunk. Auto uses 8 MB for files ≥ 5 MB.")
            }

            Section("Debug") {
                Toggle("Enable debug logs", isOn: $settings.debugLogsEnabled)

                Button("Export debug logs") {
                    // TODO: Implement log export
                }
            }

            Section("Reset") {
                Button("Reset app state") {
                    appState.engine.pauseAll()
                    appState.persistence.clearAllLocalData()
                    appState.hasCompletedOnboarding = false
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.maxRetryCount) { _, _ in settings.save() }
        .onChange(of: settings.maxActiveUploads) { _, _ in settings.save() }
        .onChange(of: settings.chunkSize) { _, _ in settings.save() }
        .onChange(of: settings.debugLogsEnabled) { _, _ in settings.save() }
    }
}
