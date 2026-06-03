import SwiftUI

struct DetailView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.selectedSidebarItem {
            case .uploads:
                UploadsOverviewView()
            case .queue, .active, .completed, .failed, .paused:
                FilteredQueueView(statusFilter: statusFilter)
            case .recentDestinations:
                RecentDestinationsView()
            case .starredDestinations:
                StarredDestinationsView()
            case .sharedDrives:
                SharedDrivesView()
            case .history:
                HistoryView()
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: appState.selectedSidebarItem)
    }

    private var statusFilter: UploadItemStatus? {
        switch appState.selectedSidebarItem {
        case .queue: return .waiting
        case .active: return .uploading
        case .completed: return .completed
        case .failed: return .failed
        case .paused: return .paused
        default: return nil
        }
    }
}
