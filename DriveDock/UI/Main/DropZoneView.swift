import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Environment(AppState.self) private var appState
    @Binding var isDropTargeted: Bool
    @State private var showFilePicker = false
    @State private var showFolderPicker = false
    @State private var showDestinationPicker = false
    @State private var droppedFiles: [URL] = []
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                        )
                        .frame(width: 320, height: 200)
                        .scaleEffect(isDropTargeted ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isDropTargeted)

                    VStack(spacing: 12) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 40))
                            .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)
                            .symbolEffect(.bounce, value: isAnimating)

                        Text("Drop files or folders here")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.primary)

                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleDrop(providers)
                }

                HStack(spacing: 12) {
                    Button("Choose Files") {
                        showFilePicker = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Choose Folder") {
                        showFolderPicker = true
                    }
                    .buttonStyle(.bordered)
                }

                Text("Uploads continue safely in the background when enabled.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .padding(40)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                handleSelectedFiles(urls)
            }
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result {
                handleSelectedFiles(urls)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    droppedFiles.append(url)
                    if droppedFiles.count == providers.count {
                        handleSelectedFiles(droppedFiles)
                        droppedFiles = []
                    }
                }
            }
        }
        return true
    }

    private func handleSelectedFiles(_ urls: [URL]) {
        let files = FileDropHandler.processDroppedItems(urls)
        guard !files.isEmpty else { return }

        if let activeAccount = appState.auth.activeAccount {
            let _ = appState.engine.addFiles(
                files: files,
                destinationFolderID: "root",
                destinationFolderName: "My Drive",
                accountID: activeAccount.id
            )
            appState.engine.startProcessing()
        }
    }
}
