import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        List(selection: $state.selectedSidebarItem) {
            Section("Transfers") {
                ForEach([SidebarItem.uploads, .downloads], id: \.self) { item in
                    Label(item.displayName, systemImage: item.systemImage)
                        .tag(item)
                }
            }

            Section("Upload Queue") {
                ForEach([SidebarItem.queue, .active, .completed, .failed, .paused], id: \.self) { item in
                    Label(item.displayName, systemImage: item.systemImage)
                        .tag(item)
                        .badge(uploadBadgeCount(for: item))
                }
            }

            Section("Google Drive") {
                ForEach([SidebarItem.myDrive], id: \.self) { item in
                    Label(item.displayName, systemImage: item.systemImage)
                        .tag(item)
                }
            }

            Section {
                Label(SidebarItem.history.displayName, systemImage: SidebarItem.history.systemImage)
                    .tag(SidebarItem.history)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 240)
    }

    private func uploadBadgeCount(for item: SidebarItem) -> Int {
        let engine = appState.engine
        switch item {
        case .queue: return engine.items.filter { $0.status == .waiting }.count
        case .active: return engine.activeUploadCount
        case .completed: return engine.completedCount
        case .failed: return engine.failedCount
        case .paused: return engine.pausedCount
        default: return 0
        }
    }
}
