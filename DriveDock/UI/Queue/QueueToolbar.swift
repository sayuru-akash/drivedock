import SwiftUI

struct QueueToolbar: View {
    @Environment(AppState.self) private var appState
    @State private var showFilePicker = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                showFilePicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.medium))
            }
            .help("Add files")

            Divider()
                .frame(height: 16)

            Button {
                if appState.engine.isProcessing {
                    appState.engine.pauseAll()
                } else {
                    appState.engine.resumeAll()
                }
            } label: {
                Image(systemName: appState.engine.isProcessing ? "pause.fill" : "play.fill")
            }
            .help(appState.engine.isProcessing ? "Pause all" : "Resume all")

            Button {
                appState.engine.clearCompleted()
            } label: {
                Image(systemName: "checkmark.circle")
            }
            .help("Clear completed")
            .disabled(appState.engine.completedCount == 0)

            Spacer()

            Text("\(appState.engine.activeUploadCount) active")
                .font(.caption)
                .foregroundStyle(.secondary)

            if appState.engine.totalSpeed > 0 {
                Text(ByteCountFormatter.string(fromByteCount: Int64(appState.engine.totalSpeed), countStyle: .file) + "/s")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                let files = FileDropHandler.processDroppedItems(urls)
                if let account = appState.auth.activeAccount, !files.isEmpty {
                    _ = appState.engine.addFiles(
                        files: files,
                        destinationFolderID: "root",
                        destinationFolderName: "My Drive",
                        accountID: account.id
                    )
                    appState.engine.startProcessing()
                }
            }
        }
    }
}
