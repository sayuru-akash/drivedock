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
                    StarredDestinationRow(star: star) {
                        startUpload(to: star)
                    } onUnstar: {
                        appState.persistence.toggleStarred(star)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: starred.count)
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

struct StarredDestinationRow: View {
    let star: StarredDestination
    let onUpload: () -> Void
    let onUnstar: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(star.folderName)
                    .font(.body)
                Text(star.starredDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    Button("Unstar") {
                        onUnstar()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Upload Here") {
                        onUpload()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
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
        .accessibilityLabel("\(star.folderName), starred \(star.starredDate.formatted(date: .abbreviated, time: .shortened))")
    }
}
