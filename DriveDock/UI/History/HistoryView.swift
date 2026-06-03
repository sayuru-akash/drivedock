import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var history: [UploadHistoryEntry] = []
    @State private var searchText = ""
    @State private var showExportSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("Search history...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            if filteredHistory.isEmpty {
                ContentUnavailableView {
                    Label("No History", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Completed uploads will appear here.")
                }
            } else {
                List(filteredHistory) { entry in
                    HistoryRow(entry: entry)
                }
                .listStyle(.inset)
            }
        }
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.status == .completed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(entry.status == .completed ? .green : .red)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.fileName)
                    .font(.body)
                    .lineLimit(1)

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

            if let link = entry.driveFileLink {
                Button {
                    if let url = URL(string: link) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderless)
                .help("Open in Drive")
            }
        }
        .padding(.vertical, 2)
    }
}
