import SwiftUI

struct StatusBadge: View {
    let status: UploadItemStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.systemImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(status.displayName)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(backgroundColor.opacity(0.15))
        .foregroundStyle(backgroundColor)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.displayName)
        .accessibilityAddTraits(.isStaticText)
    }

    private var backgroundColor: Color {
        switch status {
        case .preparing: return .secondary
        case .waiting: return .secondary
        case .uploading: return .accentColor
        case .paused: return Color(nsColor: .systemOrange)
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return Color(nsColor: .tertiaryLabelColor)
        case .needsAccountReconnect: return Color(nsColor: .systemOrange)
        case .needsDestinationPermission: return Color(nsColor: .systemOrange)
        case .skipped: return Color(nsColor: .tertiaryLabelColor)
        }
    }
}
