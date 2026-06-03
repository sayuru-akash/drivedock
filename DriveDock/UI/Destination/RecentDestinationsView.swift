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
                    RecentDestinationRow(recent: recent) {
                        startUpload(to: recent)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: recents.count)
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

struct RecentDestinationRow: View {
    let recent: RecentDestination
    let onUpload: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recent.isSharedDrive ? "person.2.fill" : "folder.fill")
                .font(.title2)
                .foregroundStyle(recent.isSharedDrive ? .purple : .accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(recent.folderName)
                    .font(.body)
                Text(recent.lastUsedDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isHovering {
                Button {
                    onUpload()
                } label: {
                    Text("Upload Here")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recent.folderName), used \(recent.lastUsedDate.formatted(date: .abbreviated, time: .shortened))")
    }
}
