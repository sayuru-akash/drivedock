import SwiftUI

struct CompletionSummaryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let batch: UploadBatch

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: batch.status == .completed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(batch.status == .completed ? .green : .orange)
                    .accessibilityHidden(true)

                Text(batch.status == .completed ? "Upload Complete" : "Upload Partially Complete")
                    .font(.title2.weight(.semibold))
            }

            // Stats
            VStack(spacing: 12) {
                StatRow(label: "Files Uploaded", value: "\(completedCount)")
                StatRow(label: "Total Size", value: batch.formattedTotalSize)
                StatRow(label: "Duration", value: batch.formattedDuration)
                StatRow(label: "Destination", value: batch.destinationFolderName)

                if failedCount > 0 {
                    StatRow(label: "Failed", value: "\(failedCount)", isNegative: true)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)

            // Actions
            HStack(spacing: 12) {
                if let driveLink = firstDriveLink {
                    Button {
                        if let url = URL(string: driveLink) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Open in Drive", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Open in Google Drive")
                }

                Button {
                    copyAllLinks()
                } label: {
                    Label("Copy Links", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Copy all Drive links")

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 400)
        .accessibilityElement(children: .contain)
    }

    private var completedCount: Int {
        appState.engine.items.filter { $0.batchID == batch.id && $0.status == .completed }.count
    }

    private var failedCount: Int {
        appState.engine.items.filter { $0.batchID == batch.id && $0.status == .failed }.count
    }

    private var firstDriveLink: String? {
        appState.engine.items.first(where: { $0.batchID == batch.id && $0.driveFileLink != nil })?.driveFileLink
    }

    private func copyAllLinks() {
        let links = appState.engine.items
            .filter { $0.batchID == batch.id && $0.driveFileLink != nil }
            .compactMap { $0.driveFileLink }
            .joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(links, forType: .string)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var isNegative: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isNegative ? .red : .primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
