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
                List(selection: $selectedItems) {
                    ForEach(groupedSections, id: \.status) { section in
                        Section {
                            ForEach(section.items) { item in
                                QueueItemRow(item: item)
                                    .tag(item.id)
                                    .contextMenu {
                                        ItemContextMenu(item: item)
                                    }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: section.status.systemImage)
                                    .font(.caption)
                                    .foregroundStyle(section.color)
                                    .accessibilityHidden(true)
                                Text(section.status.displayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(section.items.count)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.tertiary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(section.status.displayName): \(section.items.count) items")
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
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

    private var groupedSections: [UploadGroupedSection] {
        let statuses: [UploadItemStatus] = [.uploading, .waiting, .paused, .completed, .failed]
        return statuses.compactMap { status in
            let items = filteredItems.filter { $0.status == status }
            guard !items.isEmpty else { return nil }
            return UploadGroupedSection(status: status, items: items)
        }
    }

    private func removeSelectedItems() {
        let idsToRemove = selectedItems
        selectedItems.removeAll()
        for itemID in idsToRemove {
            appState.engine.removeItem(itemID)
        }
    }
}

struct UploadGroupedSection {
    let status: UploadItemStatus
    let items: [UploadItem]

    var color: Color {
        switch status {
        case .uploading: return .blue
        case .waiting: return .secondary
        case .paused: return .yellow
        case .completed: return .green
        case .failed: return .red
        default: return .secondary
        }
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
