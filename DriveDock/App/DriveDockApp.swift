import SwiftUI

@main
struct DriveDockApp: App {
    @State private var appState = AppState.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(colorSchemeForTheme(appState.settings.theme))
                .onAppear {
                    configureAppearance()
                }
                .onOpenURL { url in
                    // OAuth callback handled by local server, not URL scheme
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Upload...") {
                    appState.showDestinationPicker = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Uploads") {
                Button("Add Files...") {
                    openFilePicker()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Add Folder...") {
                    openFolderPicker()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button(appState.engine.isProcessing ? "Pause All" : "Resume All") {
                    if appState.engine.isProcessing {
                        appState.engine.pauseAll()
                    } else {
                        appState.engine.resumeAll()
                    }
                }
                .keyboardShortcut("p", modifiers: .command)

                Button("Resume All") {
                    appState.engine.resumeAll()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Clear Completed") {
                    appState.engine.clearCompleted()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .disabled(appState.engine.completedCount == 0)
            }

            CommandMenu("View") {
                Button("Toggle Inspector") {
                    appState.showInspector.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])

                Divider()

                Button("Show Uploads") {
                    appState.selectedSidebarItem = .uploads
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Show Queue") {
                    appState.selectedSidebarItem = .queue
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Show Active") {
                    appState.selectedSidebarItem = .active
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Show Completed") {
                    appState.selectedSidebarItem = .completed
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Show Failed") {
                    appState.selectedSidebarItem = .failed
                }
                .keyboardShortcut("5", modifiers: .command)

                Button("Show History") {
                    appState.selectedSidebarItem = .history
                }
                .keyboardShortcut("6", modifiers: .command)
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appState.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarPopoverView()
                .environment(appState)
        } label: {
            MenuBarIcon()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)
    }

    private func configureAppearance() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    private func colorSchemeForTheme(_ theme: AppTheme) -> ColorScheme? {
        switch theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            let files = FileDropHandler.processDroppedItems(panel.urls)
            if let account = appState.auth.activeAccount, !files.isEmpty {
                _ = appState.engine.addFiles(
                    files: files,
                    destinationFolderID: "root",
                    destinationFolderName: "My Drive",
                    accountID: account.id
                )
                appState.engine.startProcessing()
            }
        }
    }

    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK {
            let files = FileDropHandler.processDroppedItems(panel.urls)
            if let account = appState.auth.activeAccount, !files.isEmpty {
                _ = appState.engine.addFiles(
                    files: files,
                    destinationFolderID: "root",
                    destinationFolderName: "My Drive",
                    accountID: account.id
                )
                appState.engine.startProcessing()
            }
        }
    }
}
