import SwiftUI

struct DownloadsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedItems = Set<String>()

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                Button {
                    if appState.downloadEngine.isProcessing {
                        appState.downloadEngine.pauseAll()
                    } else {
                        appState.downloadEngine.resumeAll()
                    }
                } label: {
                    Image(systemName: appState.downloadEngine.isProcessing ? "pause.fill" : "play.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                }
                .help(appState.downloadEngine.isProcessing ? "Pause all" : "Resume all")

                Button {
                    appState.downloadEngine.clearCompleted()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                }
                .help("Clear completed")
                .disabled(appState.downloadEngine.completedCount == 0)

                Button {
                    appState.downloadEngine.clearFailed()
                } label: {
                    Image(systemName: "xmark.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                }
                .help("Clear failed")
                .disabled(appState.downloadEngine.failedCount == 0)

                Spacer()

                if appState.downloadEngine.activeDownloadCount > 0 {
                    Text("\(appState.downloadEngine.activeDownloadCount) active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if appState.downloadEngine.totalSpeed > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(appState.downloadEngine.totalSpeed), countStyle: .file) + "/s")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            if appState.downloadEngine.items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "arrow.down.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.secondary)
                    Text("No Downloads")
                        .font(.title3.weight(.medium))
                    Text("Download files from your Google Drive\nusing the browser.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.downloadEngine.items, selection: $selectedItems) { item in
                    DownloadItemRow(item: item)
                        .tag(item.id)
                }
                .listStyle(.inset)
            }

            // Status bar
            if !appState.downloadEngine.items.isEmpty {
                Divider()
                HStack {
                    Text("\(appState.downloadEngine.completedCount) of \(appState.downloadEngine.items.count) completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if appState.downloadEngine.failedCount > 0 {
                        Text("\(appState.downloadEngine.failedCount) failed")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.bar)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DownloadItemRow: View {
    @Environment(AppState.self) private var appState
    let item: DownloadItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.status.systemImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    if item.fileSize > 0 {
                        Text(item.formattedSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Size unknown")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if item.status == .downloading {
                        Text(item.formattedSpeed)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                // Show file path
                Text(item.localPath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if item.status == .downloading {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(item.progressPercent, format: .percent)
                        .font(.caption.monospaced())
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 100)
                    if let eta = item.eta, eta > 0 {
                        Text(formattedETA(eta))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else if item.status == .completed {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.green)

                    Button {
                        NSWorkspace.shared.selectFile(item.localPath, inFileViewerRootedAtPath: (item.localPath as NSString).deletingLastPathComponent)
                    } label: {
                        Image(systemName: "folder")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.borderless)
                    .help("Reveal in Finder")
                }
            } else if item.status == .failed {
                VStack(alignment: .trailing, spacing: 4) {
                    if let error = item.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                    Button("Retry") {
                        appState.downloadEngine.retryItem(item.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Menu {
                if item.status == .downloading {
                    Button("Pause") { appState.downloadEngine.pauseItem(item.id) }
                } else if item.status == .paused || item.status == .waiting {
                    Button("Resume") { appState.downloadEngine.resumeItem(item.id) }
                }
                if item.status == .failed {
                    Button("Retry") { appState.downloadEngine.retryItem(item.id) }
                }
                Divider()
                Button("Cancel") { appState.downloadEngine.cancelItem(item.id) }
                Button("Remove") { appState.downloadEngine.removeItem(item.id) }
                if item.status == .completed {
                    Divider()
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(item.localPath, inFileViewerRootedAtPath: (item.localPath as NSString).deletingLastPathComponent)
                    }
                    Button("Open File") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: item.localPath))
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch item.status {
        case .waiting: return .secondary
        case .downloading: return .blue
        case .paused: return .yellow
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }

    private func formattedETA(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? "—"
    }
}
