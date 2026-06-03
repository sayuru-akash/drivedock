import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var showAccountPicker = false

    var body: some View {
        @Bindable var state = appState

        List(selection: $state.selectedSidebarItem) {
            Section("Uploads") {
                ForEach([SidebarItem.uploads, .queue, .active, .completed, .failed, .paused], id: \.self) { item in
                    Label(item.displayName, systemImage: item.systemImage)
                        .tag(item)
                        .badge(badgeCount(for: item))
                }
            }

            Section("Destinations") {
                ForEach([SidebarItem.recentDestinations, .starredDestinations, .sharedDrives], id: \.self) { item in
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
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
    }

    private func badgeCount(for item: SidebarItem) -> Int {
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
