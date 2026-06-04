import SwiftUI

struct DetailView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.selectedSidebarItem {
            case .uploads:
                UploadsOverviewView()
            case .downloads:
                DownloadsView()
            case .queue, .active, .completed, .failed, .paused:
                FilteredQueueView(statusFilter: statusFilter)
            case .myDrive:
                DriveBrowserView()
            case .history:
                HistoryView()
            case .settings:
                SettingsView()
            default:
                UploadsOverviewView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
