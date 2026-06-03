import SwiftUI

struct FilteredQueueView: View {
    @Environment(AppState.self) private var appState
    let statusFilter: UploadItemStatus?

    var body: some View {
        let filtered = statusFilter.map { status in
            appState.engine.items.filter { $0.status == status }
        } ?? appState.engine.items

        if filtered.isEmpty {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: emptyIcon)
            } description: {
                Text(emptyDescription)
            }
        } else {
            List(filtered, selection: Binding(
                get: { appState.selectedUploadItemID.map { Set([$0]) } ?? Set() },
                set: { appState.selectedUploadItemID = $0.first }
            )) { item in
                QueueItemRow(item: item)
                    .tag(item.id)
                    .contextMenu {
                        ItemContextMenu(item: item)
                    }
            }
            .listStyle(.inset)
            .animation(.easeInOut(duration: 0.2), value: filtered.count)
        }
    }

    private var emptyTitle: String {
        switch statusFilter {
        case .waiting: return "No Queued Items"
        case .uploading: return "No Active Uploads"
        case .completed: return "No Completed Uploads"
        case .failed: return "No Failed Uploads"
        case .paused: return "No Paused Uploads"
        default: return "No Uploads"
        }
    }

    private var emptyIcon: String {
        switch statusFilter {
        case .waiting: return "clock"
        case .uploading: return "arrow.up.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "exclamationmark.circle"
        case .paused: return "pause.circle"
        default: return "arrow.up.circle"
        }
    }

    private var emptyDescription: String {
        switch statusFilter {
        case .waiting: return "All items are being processed."
        case .uploading: return "Start an upload to see it here."
        case .completed: return "Completed uploads will appear here."
        case .failed: return "Failed uploads that need attention will appear here."
        case .paused: return "Paused uploads will appear here."
        default: return "Drop files to start uploading."
        }
    }
}
