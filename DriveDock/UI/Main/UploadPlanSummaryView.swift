import SwiftUI

struct UploadPlanSummaryView: View {
    let files: [LocalFileInfo]
    let destinationName: String
    let accountEmail: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "arrow.up.doc")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text("Upload Summary")
                    .font(.title2.weight(.semibold))
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                SummaryRow(label: "Files", value: "\(files.count)")
                SummaryRow(label: "Total Size", value: formattedTotalSize)
                SummaryRow(label: "Destination", value: destinationName)
                SummaryRow(label: "Account", value: accountEmail)
                SummaryRow(label: "Method", value: uploadMethod)
            }

            if files.count <= 20 {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Files")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(files.enumerated()), id: \.offset) { _, file in
                                HStack(spacing: 8) {
                                    Image(systemName: fileIcon(for: file.mimeType))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 16)
                                        .accessibilityHidden(true)
                                    Text(file.fileName)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(file.fileName), \(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))")
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Cancel upload")

                Button("Upload") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Confirm and start upload")
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private var formattedTotalSize: String {
        let total = files.reduce(Int64(0)) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private var uploadMethod: String {
        let threshold = Int64(5 * 1024 * 1024)
        let hasLargeFiles = files.contains { $0.fileSize >= threshold }
        if hasLargeFiles && files.count > 1 {
            return "Mixed (Simple + Resumable)"
        } else if hasLargeFiles {
            return "Resumable (≥ 5 MB)"
        } else {
            return "Simple (< 5 MB)"
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

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
