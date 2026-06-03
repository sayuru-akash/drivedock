import SwiftUI

struct StatusBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 16) {
            if appState.engine.isProcessing {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text("Uploading")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if appState.engine.items.contains(where: { $0.status == .uploading || $0.status == .waiting }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.yellow)
                        .frame(width: 6, height: 6)
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.secondary)
                        .frame(width: 6, height: 6)
                    Text("Idle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .frame(height: 12)

            Text("\(appState.engine.activeUploadCount) active")
                .font(.caption)
                .foregroundStyle(.secondary)

            if appState.engine.totalSpeed > 0 {
                Text(ByteCountFormatter.string(fromByteCount: Int64(appState.engine.totalSpeed), countStyle: .file) + "/s")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !appState.engine.items.isEmpty {
                Text("\(appState.engine.completedCount)/\(appState.engine.items.count) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if appState.engine.overallProgress > 0 {
                    Text(appState.engine.overallProgress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
