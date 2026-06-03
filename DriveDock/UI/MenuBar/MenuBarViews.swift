import SwiftUI

struct MenuBarIcon: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            Image(systemName: "arrow.up.circle")

            if appState.engine.isProcessing {
                Circle()
                    .trim(from: 0, to: appState.engine.overallProgress)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

struct MenuBarPopoverView: View {
    @Environment(AppState.self) private var appState
    @State private var showFilePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DriveDock")
                    .font(.headline)
                Spacer()
                if appState.engine.isProcessing {
                    Text(appState.engine.overallProgress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            if appState.engine.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No active uploads")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    StatusRow(label: "Active", count: appState.engine.activeUploadCount, color: .blue)
                    StatusRow(label: "Waiting", count: appState.engine.waitingCount, color: .secondary)
                    StatusRow(label: "Completed", count: appState.engine.completedCount, color: .green)
                    StatusRow(label: "Failed", count: appState.engine.failedCount, color: .red)
                }

                if appState.engine.totalSpeed > 0 {
                    HStack {
                        Text("Speed:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(appState.engine.totalSpeed), countStyle: .file) + "/s")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                if !appState.engine.isProcessing && appState.engine.items.contains(where: { $0.status == .waiting }) {
                    Button {
                        appState.engine.startProcessing()
                    } label: {
                        Label("Resume All", systemImage: "play.fill")
                    }
                } else if appState.engine.isProcessing {
                    Button {
                        appState.engine.pauseAll()
                    } label: {
                        Label("Pause All", systemImage: "pause.fill")
                    }
                }

                Spacer()

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                } label: {
                    Image(systemName: "macwindow")
                }
                .buttonStyle(.borderless)
                .help("Open Main Window")
            }

            Divider()

            Button("Quit DriveDock") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 240)
    }
}

struct StatusRow: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
        }
    }
}
