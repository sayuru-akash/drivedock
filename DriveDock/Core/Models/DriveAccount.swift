import Foundation
import AppKit

struct DriveAccount: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var email: String
    var displayName: String
    var avatarURL: URL?
    var connectedDate: Date
    var isActive: Bool
    var defaultDestinationID: String?
    var tokenStatus: TokenStatus

    enum TokenStatus: String, Codable, CaseIterable {
        case valid
        case expired
        case revoked
        case unknown

        var displayName: String {
            switch self {
            case .valid: return "Connected"
            case .expired: return "Token Expired"
            case .revoked: return "Access Revoked"
            case .unknown: return "Unknown"
            }
        }

        var systemImage: String {
            switch self {
            case .valid: return "checkmark.circle.fill"
            case .expired: return "clock.badge.exclamationmark"
            case .revoked: return "xmark.shield.fill"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    static func == (lhs: DriveAccount, rhs: DriveAccount) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
