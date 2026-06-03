import SwiftUI

struct ItemActionsMenu: View {
    @Environment(AppState.self) private var appState
    let item: UploadItem

    var body: some View {
        Menu {
            if item.status == .uploading {
                Button("Pause") {
                    appState.engine.pauseItem(item.id)
                }
            } else if item.status == .paused || item.status == .waiting {
                Button("Resume") {
                    appState.engine.resumeItem(item.id)
                }
            }

            if item.status == .failed {
                Button("Retry") {
                    appState.engine.retryItem(item.id)
                }

                Button("Change Destination") {
                    appState.selectedUploadItemID = item.id
                    appState.showDestinationPicker = true
                }
            }

            Divider()

            if item.status != .completed {
                Button("Cancel") {
                    appState.engine.cancelItem(item.id)
                }
            }

            Button("Remove") {
                appState.engine.removeItem(item.id)
            }

            if item.status == .completed {
                Divider()

                if let link = item.driveFileLink {
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

                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(
                        item.localFilePath,
                        inFileViewerRootedAtPath: (item.localFilePath as NSString).deletingLastPathComponent
                    )
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 20)
    }
}
