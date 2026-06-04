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
                                .accessibilityHidden(true)
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
                                .accessibilityLabel("Upload progress: \(item.progressPercent) percent")
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
                .contextMenu(forSelectionType: String.self) { items in
                    if let itemID = items.first,
                       let item = appState.engine.items.first(where: { $0.id == itemID }) {
                        ItemContextMenu(item: item)
                    }
                } primaryAction: { items in
                    if let itemID = items.first {
                        appState.selectedUploadItemID = itemID
                        appState.showInspector = true
                    }
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
        .onDeleteCommand {
            removeSelectedItems()
        }
    }

    private var filteredItems: [UploadItem] {
        appState.engine.items.sorted(using: sortOrder)
    }

    private func removeSelectedItems() {
        let idsToRemove = selectedItems
        selectedItems.removeAll()
        for itemID in idsToRemove {
            appState.engine.removeItem(itemID)
        }
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

struct ItemContextMenu: View {
    @Environment(AppState.self) private var appState
    let item: UploadItem

    var body: some View {
        if item.status == .uploading {
            Button("Pause") {
                appState.engine.pauseItem(item.id)
            }
        } else if item.status == .paused || item.status == .waiting {
            Button("Resume") {
                appState.engine.resumeItem(item.id)
            }
        }

        if item.status == .failed {
            Button("Retry") {
                appState.engine.retryItem(item.id)
            }

            Button("Change Destination") {
                appState.selectedUploadItemID = item.id
                appState.showDestinationPicker = true
            }
        }

        Divider()

        if item.status != .completed {
            Button("Cancel") {
                appState.engine.cancelItem(item.id)
            }
        }

        Button("Remove") {
            appState.selectedUploadItemID = nil
            appState.engine.removeItem(item.id)
        }

        if item.status == .completed {
            Divider()

            if let link = item.driveFileLink {
                Button("Open in Drive") {
                    if let url = URL(string: link) {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("Copy Drive Link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(link, forType: .string)
                }
            }

            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(
                    item.localFilePath,
                    inFileViewerRootedAtPath: (item.localFilePath as NSString).deletingLastPathComponent
                )
            }
        }
    }
}
