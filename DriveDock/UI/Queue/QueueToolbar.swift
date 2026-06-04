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
            .accessibilityLabel("Add files")

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
            .accessibilityLabel(appState.engine.isProcessing ? "Pause all uploads" : "Resume all uploads")
            .keyboardShortcut("p", modifiers: .command)

            Button {
                appState.engine.clearCompleted()
            } label: {
                Image(systemName: "checkmark.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
            }
            .help("Clear completed")
            .accessibilityLabel("Clear completed uploads")
            .disabled(appState.engine.completedCount == 0)

            Button {
                appState.engine.clearFailed()
            } label: {
                Image(systemName: "xmark.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
            }
            .help("Clear failed")
            .accessibilityLabel("Clear failed uploads")
            .disabled(appState.engine.failedCount == 0)

            Spacer()

            Text("\(appState.engine.activeUploadCount) active")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(appState.engine.activeUploadCount) active uploads")

            if appState.engine.totalSpeed > 0 {
                Text(ByteCountFormatter.string(fromByteCount: Int64(appState.engine.totalSpeed), countStyle: .file) + "/s")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Upload speed: \(ByteCountFormatter.string(fromByteCount: Int64(appState.engine.totalSpeed), countStyle: .file)) per second")
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
