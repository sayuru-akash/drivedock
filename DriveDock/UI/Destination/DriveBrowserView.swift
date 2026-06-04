import SwiftUI

struct DriveFileRow: View {
    @Environment(AppState.self) private var appState
    let item: DriveFile
    let onNavigate: () -> Void
    let onUpload: () -> Void
    let onOpenInBrowser: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    if let size = item.size, size > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 6) {
                    if item.isFolder {
                        Button("Open") {
                            onNavigate()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Upload Here") {
                            onUpload()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button {
                            downloadFolder()
                        } label: {
                            Image(systemName: "arrow.down.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Download folder")
                    } else {
                        Button {
                            downloadFile()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 12, height: 12)
                                Text("Download")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Download file")
                    }

                    Button {
                        onOpenInBrowser()
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.borderless)
                    .help("Open in Google Drive")
                }
            }
        }
        .padding(.vertical, 2)
        .onHover { hovering in isHovered = hovering }
        .onTapGesture {
            if item.isFolder {
                onNavigate()
            }
        }
    }

    private func downloadFile() {
        guard let account = appState.auth.activeAccount else { return }
        let downloadsFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        appState.downloadEngine.addFile(
            driveFileID: item.id,
            fileName: item.name,
            fileSize: item.size ?? 0,
            localDirectory: downloadsFolder,
            accountID: account.id
        )
        appState.downloadEngine.startProcessing()
    }

    private func downloadFolder() {
        guard let account = appState.auth.activeAccount else { return }
        let downloadsFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        Task {
            await appState.downloadEngine.addFolder(
                driveFolderID: item.id,
                folderName: item.name,
                localDirectory: downloadsFolder,
                accountID: account.id
            )
            appState.downloadEngine.startProcessing()
        }
    }

    private var icon: String {
        if item.isFolder { return "folder.fill" }
        let mime = item.mimeType
        if mime.hasPrefix("image/") { return "photo" }
        if mime.hasPrefix("video/") { return "video" }
        if mime.hasPrefix("audio/") { return "music.note" }
        if mime.contains("pdf") { return "doc.text" }
        if mime.contains("zip") || mime.contains("archive") { return "archivebox" }
        if mime.contains("spreadsheet") || mime.contains("excel") { return "tablecells" }
        if mime.contains("presentation") || mime.contains("powerpoint") { return "rectangle.on.rectangle" }
        if mime.contains("document") || mime.contains("word") { return "doc.richtext" }
        return "doc"
    }

    private var iconColor: Color {
        if item.isFolder { return .blue }
        let mime = item.mimeType
        if mime.hasPrefix("image/") { return .green }
        if mime.hasPrefix("video/") { return .purple }
        if mime.hasPrefix("audio/") { return .orange }
        if mime.contains("pdf") { return .red }
        return .secondary
    }
}
