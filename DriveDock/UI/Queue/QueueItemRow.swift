import SwiftUI

struct QueueItemRow: View {
    @Environment(AppState.self) private var appState
    let item: UploadItem
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            StatusBadge(status: item.status)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: item.isFolder ? "folder.fill" : fileIcon)
                        .foregroundStyle(item.isFolder ? Color.accentColor : Color.secondary)
                        .font(.system(size: 14))
                        .accessibilityHidden(true)

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

            if isHovering {
                hoverActions
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if item.status == .uploading {
                uploadProgress
            } else if item.status == .failed {
                failedActions
            } else if item.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Completed")
            }

            ItemActionsMenu(item: item)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            appState.selectedUploadItemID = item.id
            appState.showInspector = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var hoverActions: some View {
        HStack(spacing: 4) {
            if item.status == .uploading {
                hoverButton(icon: "pause.fill", label: "Pause") {
                    appState.engine.pauseItem(item.id)
                }
            } else if item.status == .paused || item.status == .waiting {
                hoverButton(icon: "play.fill", label: "Resume") {
                    appState.engine.resumeItem(item.id)
                }
            } else if item.status == .failed {
                hoverButton(icon: "arrow.clockwise", label: "Retry") {
                    appState.engine.retryItem(item.id)
                }
            }

            if item.status != .completed {
                hoverButton(icon: "xmark.circle", label: "Cancel") {
                    appState.engine.cancelItem(item.id)
                }
            }
        }
    }

    @ViewBuilder
    private func hoverButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
        .help(label)
    }

    @ViewBuilder
    private var uploadProgress: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(item.progressPercent, format: .percent)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)

            ProgressView(value: item.progress)
                .progressViewStyle(.linear)
                .frame(width: 80)
                .animation(.easeInOut(duration: 0.3), value: item.progress)

            if let eta = item.eta, eta > 0 {
                Text(formattedETA(eta))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Upload progress: \(item.progressPercent) percent")
    }

    @ViewBuilder
    private var failedActions: some View {
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
    }

    private var fileIcon: String {
        if item.mimeType.hasPrefix("image/") { return "photo" }
        if item.mimeType.hasPrefix("video/") { return "video" }
        if item.mimeType.hasPrefix("audio/") { return "music.note" }
        return "doc"
    }

    private var accessibilityDescription: String {
        var parts = [item.localFileName]
        parts.append(item.formattedSize)
        parts.append(item.status.displayName)
        if item.status == .uploading {
            parts.append("\(item.progressPercent) percent")
        }
        return parts.joined(separator: ", ")
    }

    private func formattedETA(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? "—"
    }
}
