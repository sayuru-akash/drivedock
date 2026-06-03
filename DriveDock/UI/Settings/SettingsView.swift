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

    var body: some View {
        @Bindable var settings = appState.settings

        Form {
            Section("Appearance") {
                Picker("Theme", selection: $settings.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }

                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
                Toggle("Show Dock icon", isOn: $settings.showDockIcon)
            }

            Section("Behavior") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Confirm before quitting with active uploads", isOn: $settings.confirmQuitWithActiveUploads)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.theme) { _, _ in settings.save() }
        .onChange(of: settings.showMenuBarIcon) { _, _ in settings.save() }
        .onChange(of: settings.showDockIcon) { _, _ in settings.save() }
        .onChange(of: settings.launchAtLogin) { _, _ in settings.save() }
        .onChange(of: settings.confirmQuitWithActiveUploads) { _, _ in settings.save() }
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
    }
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showClearConfirmation = false

    var body: some View {
        Form {
            Section("Local Data") {
                Button("Clear upload history") {
                    appState.persistence.clearHistory()
                }

                Button("Clear all local data") {
                    showClearConfirmation = true
                }
                .foregroundStyle(.red)
            }

            Section("Security") {
                Text("OAuth tokens are stored securely in macOS Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("DriveDock does not include analytics or tracking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .alert("Clear All Local Data", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Everything", role: .destructive) {
                appState.engine.pauseAll()
                appState.persistence.clearAllLocalData()
            }
        } message: {
            Text("This will remove all upload history, queue data, and cached settings. OAuth tokens in Keychain will not be affected.")
        }
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
        .onChange(of: settings.debugLogsEnabled) { _, _ in settings.save() }
    }
}
