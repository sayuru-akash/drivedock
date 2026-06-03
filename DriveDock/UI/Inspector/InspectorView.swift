import SwiftUI

struct InspectorView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let itemID = appState.selectedUploadItemID,
               let item = appState.engine.items.first(where: { $0.id == itemID }) {
                ItemInspectorContent(item: item)
            } else {
                ContentUnavailableView {
                    Label("No Selection", systemImage: "sidebar.right")
                } description: {
                    Text("Select an upload to view details.")
                }
            }
        }
        .frame(width: 280)
    }
}

struct ItemInspectorContent: View {
    @Environment(AppState.self) private var appState
    let item: UploadItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: item.isFolder ? "folder.fill" : fileIcon)
                            .font(.title2)
                            .foregroundStyle(item.isFolder ? Color.accentColor : Color.secondary)
                        Text(item.localFileName)
                            .font(.headline)
                            .lineLimit(2)
                    }

                    StatusBadge(status: item.status)
                }

                Divider()

                // Details
                Group {
                    DetailRow(label: "Size", value: item.formattedSize)
                    DetailRow(label: "Destination", value: item.destinationFolderName)
                    DetailRow(label: "Account", value: accountEmail)

                    if item.status == .uploading {
                        DetailRow(label: "Progress", value: "\(item.progressPercent)%")
                        DetailRow(label: "Uploaded", value: item.formattedUploaded)
                        DetailRow(label: "Speed", value: item.formattedSpeed)
                        if let eta = item.eta {
                            DetailRow(label: "ETA", value: eta.formatted(.units(width: .abbreviated)))
                        }
                    }

                    if item.status == .completed, let date = item.completedDate {
                        DetailRow(label: "Completed", value: date.formatted(date: .abbreviated, time: .shortened))
                        if let link = item.driveFileLink {
                            DetailRow(label: "Drive Link", value: "Available")
                        }
                    }

                    if item.retryCount > 0 {
                        DetailRow(label: "Retries", value: "\(item.retryCount)")
                    }
                }

                if let error = item.errorMessage {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Error")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)

                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let category = item.errorCategory {
                            Text(category.userAction)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                // Actions
                VStack(spacing: 8) {
                    if item.status == .uploading {
                        ActionButton(title: "Pause", icon: "pause.fill") {
                            appState.engine.pauseItem(item.id)
                        }
                    } else if item.status == .paused || item.status == .waiting {
                        ActionButton(title: "Resume", icon: "play.fill") {
                            appState.engine.resumeItem(item.id)
                        }
                    } else if item.status == .failed {
                        ActionButton(title: "Retry", icon: "arrow.clockwise") {
                            appState.engine.retryItem(item.id)
                        }
                    }

                    if item.status != .completed {
                        ActionButton(title: "Cancel", icon: "xmark.circle") {
                            appState.engine.cancelItem(item.id)
                        }
                    }

                    if let link = item.driveFileLink {
                        ActionButton(title: "Open in Drive", icon: "arrow.up.right.square") {
                            if let url = URL(string: link) {
                                NSWorkspace.shared.open(url)
                            }
                        }

                        ActionButton(title: "Copy Link", icon: "doc.on.doc") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(link, forType: .string)
                        }
                    }

                    ActionButton(title: "Reveal in Finder", icon: "folder") {
                        NSWorkspace.shared.selectFile(
                            item.localFilePath,
                            inFileViewerRootedAtPath: (item.localFilePath as NSString).deletingLastPathComponent
                        )
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    private var fileIcon: String {
        if item.mimeType.hasPrefix("image/") { return "photo" }
        if item.mimeType.hasPrefix("video/") { return "video" }
        if item.mimeType.hasPrefix("audio/") { return "music.note" }
        return "doc"
    }

    private var accountEmail: String {
        appState.auth.accounts.first { $0.id == item.accountID }?.email ?? "Unknown"
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption)
                .lineLimit(3)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
