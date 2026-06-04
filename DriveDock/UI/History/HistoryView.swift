import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var history: [UploadHistoryEntry] = []
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("Search history...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .frame(maxWidth: 250)

                Spacer()

                Menu("Export") {
                    Button("Export as CSV") {
                        exportHistory(as: .csv)
                    }
                    Button("Export as JSON") {
                        exportHistory(as: .json)
                    }
                    Button("Export as Text") {
                        exportHistory(as: .text)
                    }
                }
                .menuStyle(.borderedButton)
                .controlSize(.small)
                .accessibilityLabel("Export history")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            if filteredHistory.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.secondary)
                    Text("No History")
                        .font(.title3.weight(.medium))
                    Text("Completed uploads will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredHistory) { entry in
                    HistoryRow(entry: entry)
                        .contextMenu {
                            if let link = entry.driveFileLink {
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
                        }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            history = appState.persistence.loadHistory()
        }
    }

    private var filteredHistory: [UploadHistoryEntry] {
        if searchText.isEmpty { return history }
        return history.filter {
            $0.fileName.localizedCaseInsensitiveContains(searchText) ||
            $0.destinationFolderName.localizedCaseInsensitiveContains(searchText) ||
            $0.accountEmail.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func exportHistory(as format: PersistenceService.ExportFormat) {
        guard let data = appState.persistence.exportHistory(as: format) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = format == .json ? [.json] : format == .csv ? [.commaSeparatedText] : [.plainText]
        panel.nameFieldStringValue = "drivedock-history"

        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}

struct HistoryRow: View {
    let entry: UploadHistoryEntry
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.status == .completed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundStyle(entry.status == .completed ? .green : .red)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.fileName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    Text(entry.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(entry.destinationFolderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(entry.accountEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let date = entry.completedDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(entry.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isHovering, let link = entry.driveFileLink {
                HStack(spacing: 4) {
                    Button {
                        if let url = URL(string: link) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.borderless)
                    .help("Open in Drive")
                    .accessibilityLabel("Open in Google Drive")

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(link, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy link")
                    .accessibilityLabel("Copy Drive link")
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
        .accessibilityLabel("\(entry.fileName), \(entry.formattedSize), \(entry.status.displayName)")
    }
}
