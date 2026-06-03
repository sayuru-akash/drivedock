import SwiftUI

struct StatusBadge: View {
    let status: UploadItemStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.systemImage)
                .font(.system(size: 10))
            Text(status.displayName)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(backgroundColor.opacity(0.15))
        .foregroundStyle(backgroundColor)
        .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .preparing: return .orange
        case .waiting: return .secondary
        case .uploading: return .blue
        case .paused: return .yellow
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        case .needsAccountReconnect: return .orange
        case .needsDestinationPermission: return .purple
        case .skipped: return .gray
        }
    }
}
