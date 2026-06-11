import SwiftUI
import Network

struct StatusBar: View {
    @Environment(AppState.self) private var appState
    @State private var isOnline = true
    @State private var monitor = NWPathMonitor()
    @State private var monitorQueue = DispatchQueue(label: "NetworkMonitor")

    var body: some View {
        HStack(spacing: 16) {
            if appState.engine.isProcessing {
                HStack(spacing: 4) {
                    PulsingDot(color: .green)
                        .frame(width: 6, height: 6)
                    Text("Uploading")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Status: Uploading")
            } else if appState.engine.items.contains(where: { $0.status == .uploading || $0.status == .waiting }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.yellow)
                        .frame(width: 6, height: 6)
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Status: Paused")
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.secondary)
                        .frame(width: 6, height: 6)
                    Text("Idle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Status: Idle")
            }

            Divider()
                .frame(height: 12)

            Text("\(appState.engine.activeUploadCount) active")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(appState.engine.activeUploadCount) active uploads")

            if appState.engine.totalSpeed > 0 {
                Text(ByteCountFormatter.string(fromByteCount: Int64(appState.engine.totalSpeed), countStyle: .file) + "/s")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Speed: \(ByteCountFormatter.string(fromByteCount: Int64(appState.engine.totalSpeed), countStyle: .file)) per second")
            }

            if remainingBytes > 0 {
                Text(ByteCountFormatter.string(fromByteCount: remainingBytes, countStyle: .file) + " left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(ByteCountFormatter.string(fromByteCount: remainingBytes, countStyle: .file)) remaining")
            }

            Spacer()

            if appState.engine.isProcessing, let eta = overallETA, eta > 0 {
                Text("ETA: \(formattedETA(eta))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Estimated time remaining: \(formattedETA(eta))")
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(isOnline ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(isOnline ? "Online" : "Offline")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Network: \(isOnline ? "Online" : "Offline")")

            if !appState.engine.items.isEmpty {
                Text("\(appState.engine.completedCount)/\(appState.engine.items.count) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(appState.engine.completedCount) of \(appState.engine.items.count) files completed")

                if appState.engine.overallProgress > 0 {
                    Text(appState.engine.overallProgress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Overall progress: \(Int(appState.engine.overallProgress * 100)) percent")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .lineLimit(1)
        .accessibilityElement(children: .contain)
        .onAppear {
            startNetworkMonitor()
        }
    }

    private var remainingBytes: Int64 {
        appState.engine.items
            .filter { $0.status == .uploading || $0.status == .waiting || $0.status == .paused }
            .reduce(Int64(0)) { $0 + max(0, $1.fileSize - $1.uploadedBytes) }
    }

    private var overallETA: TimeInterval? {
        let speed = appState.engine.totalSpeed
        guard speed > 0 else { return nil }
        return TimeInterval(Double(remainingBytes) / speed)
    }

    private func formattedETA(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? "—"
    }

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: monitorQueue)
    }
}
