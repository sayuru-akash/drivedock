import SwiftUI

struct UploadsOverviewView: View {
    @Environment(AppState.self) private var appState
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if appState.engine.items.isEmpty {
                DropZoneView(isDropTargeted: $isDropTargeted)
            } else {
                UploadQueueView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
