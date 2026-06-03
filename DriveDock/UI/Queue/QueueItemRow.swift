import SwiftUI

struct QueueItemRow: View {
    @Environment(AppState.self) private var appState
    let item: UploadItem

    var body: some View {
        HStack(spacing: 12) {
            StatusBadge(status: item.status)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: item.isFolder ? "folder.fill" : fileIcon)
                        .foregroundStyle(item.isFolder ? Color.accentColor : Color.secondary)
                        .font(.system(size: 14))

                    Text(item.localFileName)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 8) {
                    Text(item.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(item.destinationFolderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if item.status == .uploading {
                        Text(item.formattedSpeed)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if item.status == .uploading {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.progressPercent, format: .percent)
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)

                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 80)

                    if let eta = item.eta {
                        Text(eta.formatted(.units(width: .abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else if item.status == .failed {
                VStack(alignment: .trailing, spacing: 4) {
                    if let category = item.errorCategory {
                        Text(category.displayName)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button("Retry") {
                        appState.engine.retryItem(item.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else if item.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            ItemActionsMenu(item: item)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectedUploadItemID = item.id
            appState.showInspector = true
        }
    }

    private var fileIcon: String {
        if item.mimeType.hasPrefix("image/") { return "photo" }
        if item.mimeType.hasPrefix("video/") { return "video" }
        if item.mimeType.hasPrefix("audio/") { return "music.note" }
        return "doc"
    }
}
