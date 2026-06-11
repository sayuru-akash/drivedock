import SwiftUI
import UniformTypeIdentifiers

struct MenuBarIcon: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            Image(systemName: "arrow.up.circle")

            if appState.engine.isProcessing {
                Circle()
                    .trim(from: 0, to: appState.engine.overallProgress)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: appState.engine.overallProgress)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("DriveDock")
        .accessibilityValue(appState.engine.isProcessing ? "Uploading \(Int(appState.engine.overallProgress * 100)) percent" : "Idle")
    }
}

struct MenuBarPopoverView: View {
    @Environment(AppState.self) private var appState
    @State private var showFilePicker = false
    @State private var isDropTargeted = false
    @State private var droppedFiles: [URL] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DriveDock")
                    .font(.headline)
                Spacer()
                if appState.engine.isProcessing {
                    Text(appState.engine.overallProgress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut(duration: 0.3), value: appState.engine.overallProgress)
                }
            }

            if appState.engine.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No active uploads")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    StatusRow(label: "Active", count: appState.engine.activeUploadCount, color: .blue)
                    StatusRow(label: "Waiting", count: appState.engine.waitingCount, color: .secondary)
                    StatusRow(label: "Completed", count: appState.engine.completedCount, color: .green)
                    StatusRow(label: "Failed", count: appState.engine.failedCount, color: .red)
                }

                if appState.engine.totalSpeed > 0 {
                    HStack {
                        Text("Speed:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(appState.engine.totalSpeed), countStyle: .file) + "/s")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            MenuBarDropZone(isDropTargeted: $isDropTargeted, droppedFiles: $droppedFiles)
                .frame(height: 60)

            Divider()

            let recentCompleted = recentCompletedUploads
            if !recentCompleted.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Completions")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(recentCompleted) { item in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .accessibilityHidden(true)
                            Text(item.localFileName)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(item.formattedSize)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Completed: \(item.localFileName), \(item.formattedSize)")
                    }
                }

                Divider()
            }

            let accounts = appState.auth.accounts
            if accounts.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accounts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(accounts) { account in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(account.isActive ? Color.accentColor : Color.clear)
                                .stroke(Color.secondary, lineWidth: account.isActive ? 0 : 1)
                                .frame(width: 8, height: 8)
                                .accessibilityHidden(true)
                            Text(account.email)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundStyle(account.isActive ? .primary : .secondary)
                            Spacer()
                            if account.isActive {
                                Text("Active")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.auth.setActiveAccount(account)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(account.email)\(account.isActive ? ", active" : "")")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Tap to switch to this account")
                    }
                }

                Divider()
            }

            HStack(spacing: 8) {
                if !appState.engine.isProcessing && appState.engine.items.contains(where: { $0.status == .waiting }) {
                    Button {
                        appState.engine.startProcessing()
                    } label: {
                        Label("Resume All", systemImage: "play.fill")
                    }
                    .accessibilityLabel("Resume all uploads")
                } else if appState.engine.isProcessing {
                    Button {
                        appState.engine.pauseAll()
                    } label: {
                        Label("Pause All", systemImage: "pause.fill")
                    }
                    .accessibilityLabel("Pause all uploads")
                }

                Spacer()

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                } label: {
                    Image(systemName: "macwindow")
                }
                .buttonStyle(.borderless)
                .help("Open Main Window")
                .accessibilityLabel("Open main window")
            }

            Divider()

            Button("Quit DriveDock") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Quit DriveDock")
        }
        .padding()
        .frame(width: 260)
    }

    private var recentCompletedUploads: [UploadItem] {
        appState.engine.items
            .filter { $0.status == .completed }
            .sorted { ($0.completedDate ?? .distantPast) > ($1.completedDate ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }
}

struct StatusRow: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(count)")
    }
}

struct MenuBarDropZone: View {
    @Environment(AppState.self) private var appState
    @Binding var isDropTargeted: Bool
    @Binding var droppedFiles: [URL]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )

            HStack(spacing: 8) {
                Image(systemName: "arrow.up.doc")
                    .font(.title3)
                    .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                Text("Drop files to upload")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .accessibilityLabel("Drop zone for quick uploads")
        .accessibilityHint("Drag and drop files here to upload them to Google Drive")
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    droppedFiles.append(url)
                    if droppedFiles.count == providers.count {
                        processFiles(droppedFiles)
                        droppedFiles = []
                    }
                }
            }
        }
        return true
    }

    private func processFiles(_ urls: [URL]) {
        let files = FileDropHandler.processDroppedItems(urls)
        guard !files.isEmpty else { return }

        if let account = appState.auth.activeAccount {
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
