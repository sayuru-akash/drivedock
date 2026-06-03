import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var showAccountPicker = false

    var body: some View {
        @Bindable var state = appState

        List(selection: $state.selectedSidebarItem) {
            Section("Uploads") {
                ForEach([SidebarItem.uploads, .queue, .active, .completed, .failed, .paused], id: \.self) { item in
                    sidebarRow(for: item)
                }
            }

            Section("Destinations") {
                ForEach([SidebarItem.recentDestinations, .starredDestinations, .sharedDrives], id: \.self) { item in
                    sidebarRow(for: item)
                }
            }

            Section {
                sidebarRow(for: .history)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
    }

    @ViewBuilder
    private func sidebarRow(for item: SidebarItem) -> some View {
        Label(item.displayName, systemImage: item.systemImage)
            .tag(item)
            .badge(badgeCount(for: item))
            .accessibilityLabel("\(item.displayName), \(badgeCount(for: item)) items")
            .contextMenu {
                switch item.section {
                case .uploads:
                    Button("Show in Uploads") {
                        appState.selectedSidebarItem = .uploads
                    }
                    Divider()
                    Button("Pause All") {
                        appState.engine.pauseAll()
                    }
                    .disabled(!appState.engine.isProcessing)
                    Button("Resume All") {
                        appState.engine.resumeAll()
                    }
                    Divider()
                    Button("Clear Completed") {
                        appState.engine.clearCompleted()
                    }
                    .disabled(appState.engine.completedCount == 0)
                case .destinations:
                    Button("Browse Destination") {
                        appState.selectedSidebarItem = item
                    }
                case .other:
                    Button("Go to \(item.displayName)") {
                        appState.selectedSidebarItem = item
                    }
                }
            }
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
