import SwiftUI

struct SharedDrivesView: View {
    @Environment(AppState.self) private var appState
    @State private var sharedDrives: [SharedDrive] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sharedDrives.isEmpty {
                ContentUnavailableView {
                    Label("No Shared Drives", systemImage: "person.2")
                } description: {
                    Text("Shared Drives you have access to will appear here.")
                }
            } else {
                List(sharedDrives) { drive in
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(drive.name)
                                .font(.body)
                            if let date = drive.createdDate {
                                Text("Created \(date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button("Browse") {
                            // TODO: Navigate to shared drive
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .task {
            await loadSharedDrives()
        }
    }

    private func loadSharedDrives() async {
        guard let accountID = appState.auth.activeAccount?.id else { return }
        isLoading = true
        do {
            sharedDrives = try await DriveAPIService.shared.listSharedDrives(accountID: accountID)
        } catch {
            // Silently fail
        }
        isLoading = false
    }
}
