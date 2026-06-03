import SwiftUI

struct UploadQueueView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedItems = Set<String>()
    @State private var sortOrder = [KeyPathComparator(\UploadItem.createdDate, order: .reverse)]

    var body: some View {
        VStack(spacing: 0) {
            QueueToolbar()

            Divider()

            if filteredItems.isEmpty {
                ContentUnavailableView {
                    Label("No Uploads", systemImage: "arrow.up.circle")
                } description: {
                    Text("Drop files or folders to start uploading.")
                }
            } else {
                Table(filteredItems, selection: $selectedItems, sortOrder: $sortOrder) {
                    TableColumn("Status") { item in
                        StatusBadge(status: item.status)
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("Name", value: \.localFileName) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.isFolder ? "folder.fill" : fileIcon(for: item.mimeType))
                                .foregroundStyle(item.isFolder ? Color.accentColor : Color.secondary)
                            Text(item.localFileName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .width(min: 200, ideal: 300)

                    TableColumn("Size", value: \.formattedSize) { item in
                        Text(item.formattedSize)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 70, ideal: 90)

                    TableColumn("Progress") { item in
                        if item.status == .uploading {
                            ProgressView(value: item.progress)
                                .progressViewStyle(.linear)
                        } else if item.status == .completed {
                            Text("100%")
                                .foregroundStyle(.green)
                        } else {
                            Text(item.progressPercent, format: .percent)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 100, ideal: 150)

                    TableColumn("Speed") { item in
                        Text(item.formattedSpeed)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 70, ideal: 90)

                    TableColumn("Destination", value: \.destinationFolderName) { item in
                        Text(item.destinationFolderName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .width(min: 100, ideal: 150)

                    TableColumn("Actions") { item in
                        ItemActionsMenu(item: item)
                    }
                    .width(min: 40, ideal: 50)
                }
            }

            StatusBar()
        }
        .onChange(of: selectedItems) { _, newValue in
            if let firstID = newValue.first {
                appState.selectedUploadItemID = firstID
                appState.showInspector = true
            }
        }
    }

    private var filteredItems: [UploadItem] {
        appState.engine.items.sorted(using: sortOrder)
    }

    private func fileIcon(for mimeType: String) -> String {
        if mimeType.hasPrefix("image/") { return "photo" }
        if mimeType.hasPrefix("video/") { return "video" }
        if mimeType.hasPrefix("audio/") { return "music.note" }
        if mimeType.contains("pdf") { return "doc.text" }
        if mimeType.contains("zip") || mimeType.contains("archive") { return "archivebox" }
        return "doc"
    }
}
