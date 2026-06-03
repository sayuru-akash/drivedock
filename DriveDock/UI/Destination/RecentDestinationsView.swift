import SwiftUI

struct RecentDestinationsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let recents = appState.persistence.loadRecentDestinations()

        Group {
            if recents.isEmpty {
                ContentUnavailableView {
                    Label("No Recent Destinations", systemImage: "clock")
                } description: {
                    Text("Folders you upload to will appear here.")
                }
            } else {
                List(recents) { recent in
                    HStack(spacing: 12) {
                        Image(systemName: recent.isSharedDrive ? "person.2.fill" : "folder.fill")
                            .font(.title2)
                            .foregroundStyle(recent.isSharedDrive ? .purple : .accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(recent.folderName)
                                .font(.body)
                            Text(recent.lastUsedDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            startUpload(to: recent)
                        } label: {
                            Text("Upload Here")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func startUpload(to destination: RecentDestination) {
        guard let account = appState.auth.activeAccount else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true

        if panel.runModal() == .OK {
            let files = FileDropHandler.processDroppedItems(panel.urls)
            if !files.isEmpty {
                _ = appState.engine.addFiles(
                    files: files,
                    destinationFolderID: destination.folderID,
                    destinationFolderName: destination.folderName,
                    accountID: account.id
                )
                appState.engine.startProcessing()
            }
        }
    }
}
