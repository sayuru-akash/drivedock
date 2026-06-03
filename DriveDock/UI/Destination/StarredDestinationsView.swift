import SwiftUI

struct StarredDestinationsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let starred = appState.persistence.loadStarredDestinations()

        Group {
            if starred.isEmpty {
                ContentUnavailableView {
                    Label("No Starred Destinations", systemImage: "star")
                } description: {
                    Text("Star your favorite destinations for quick access.")
                }
            } else {
                List(starred) { star in
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(star.folderName)
                                .font(.body)
                            Text(star.starredDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Unstar") {
                            appState.persistence.toggleStarred(star)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Upload Here") {
                            startUpload(to: star)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func startUpload(to destination: StarredDestination) {
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
