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
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                            .foregroundStyle(item.isFolder ? Color.accentColor : Color.secondary)
                            .accessibilityHidden(true)
                        Text(item.localFileName)
                            .font(.headline)
                            .lineLimit(2)
                    }

                    StatusBadge(status: item.status)
                }

                Divider()

                // Details
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "Size", value: item.formattedSize)
                    DetailRow(label: "Destination", value: item.destinationFolderName)
                    DetailRow(label: "Account", value: accountEmail)
                    DetailRow(label: "Method", value: uploadMethod)

                    if item.status == .uploading {
                        DetailRow(label: "Progress", value: "\(item.progressPercent)%")
                        DetailRow(label: "Uploaded", value: item.formattedUploaded)
                        DetailRow(label: "Remaining", value: formattedRemaining)
                        DetailRow(label: "Speed", value: item.formattedSpeed)
                        if let eta = item.eta, eta > 0 {
                            DetailRow(label: "ETA", value: formatETA(eta))
                        }
                    }

                    if item.status == .completed, let date = item.completedDate {
                        DetailRow(label: "Completed", value: date.formatted(date: .abbreviated, time: .shortened))
                        if item.driveFileLink != nil {
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
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Error: \(error)")
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

    private var uploadMethod: String {
        let threshold = Int64(5 * 1024 * 1024)
        if item.fileSize < threshold {
            return "Simple (< 5 MB)"
        } else {
            return "Resumable (≥ 5 MB)"
        }
    }

    private var formattedRemaining: String {
        let remaining = max(0, item.fileSize - item.uploadedBytes)
        return ByteCountFormatter.string(fromByteCount: remaining, countStyle: .file)
    }

    private func formatETA(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? "—"
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
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
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 11, height: 11)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(title)
    }
}
