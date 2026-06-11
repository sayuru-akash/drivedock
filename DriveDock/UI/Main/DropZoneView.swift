import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Environment(AppState.self) private var appState
    @Binding var isDropTargeted: Bool
    @State private var showFilePicker = false
    @State private var showFolderPicker = false
    @State private var showDestinationPicker = false
    @State private var showUploadSummary = false
    @State private var droppedFiles: [URL] = []
    @State private var isAnimating = false
    @State private var glowOpacity: Double = 0
    @State private var selectedDestination: DriveFolder?
    @State private var pendingFiles: [LocalFileInfo] = []

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
                        .frame(width: 360, height: 220)
                        .scaleEffect(isDropTargeted ? 1.02 : 1.0)
                        .shadow(color: Color.accentColor.opacity(glowOpacity), radius: isDropTargeted ? 12 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isDropTargeted)

                    VStack(spacing: 12) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 40))
                            .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)
                            .scaleEffect(isAnimating ? 1.05 : 0.95)
                            .animation(
                                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                                value: isAnimating
                            )

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
                .accessibilityLabel("Drop zone for files and folders")
                .accessibilityHint("Drag and drop files here to upload them to Google Drive")

                HStack(spacing: 12) {
                    Button("Choose Files") {
                        showFilePicker = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Choose files to upload")

                    Button("Choose Folder") {
                        showFolderPicker = true
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Choose a folder to upload")
                }

                // Destination selector
                Button {
                    showDestinationPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedDestination != nil ? "folder.fill" : "folder.badge.gearshape")
                            .font(.system(size: 14))
                        Text(selectedDestination?.name ?? "Choose Drive Destination")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 300)
                .accessibilityLabel("Choose destination folder in Google Drive")

                Text("Uploads continue safely in the background when enabled.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .padding(40)
        .onAppear {
            isAnimating = true
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.3
            }
        }
        .onChange(of: isDropTargeted) { _, targeted in
            withAnimation(.easeInOut(duration: 0.3)) {
                glowOpacity = targeted ? 0.5 : 0.3
            }
        }
        .sheet(isPresented: $showDestinationPicker) {
            if let account = appState.auth.activeAccount {
                DestinationPickerView(accountID: account.id) { folder in
                    selectedDestination = folder
                }
            }
        }
        .sheet(isPresented: $showUploadSummary) {
            UploadPlanSummaryView(
                files: pendingFiles,
                destinationName: selectedDestination?.name ?? "My Drive",
                accountEmail: appState.auth.activeAccount?.email ?? "Unknown"
            ) {
                confirmUpload()
            } onCancel: {
                showUploadSummary = false
                pendingFiles = []
            }
        }
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

        pendingFiles = files
        showUploadSummary = true
    }

    private func confirmUpload() {
        guard let account = appState.auth.activeAccount else { return }

        let destinationID = selectedDestination?.id ?? "root"
        let destinationName = selectedDestination?.name ?? "My Drive"

        let _ = appState.engine.addFiles(
            files: pendingFiles,
            destinationFolderID: destinationID,
            destinationFolderName: destinationName,
            accountID: account.id
        )
        appState.engine.startProcessing()

        showUploadSummary = false
        pendingFiles = []
    }
}
