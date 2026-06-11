import Foundation
import Network

enum ConnectionType: String, Codable {
    case wifi
    case ethernet
    case cellular
    case other
    case unavailable

    var displayName: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .ethernet: return "Ethernet"
        case .cellular: return "Cellular"
        case .other: return "Other"
        case .unavailable: return "No Connection"
        }
    }

    var systemImage: String {
        switch self {
        case .wifi: return "wifi"
        case .ethernet: return "cable.connector"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .other: return "network"
        case .unavailable: return "wifi.slash"
        }
    }
}

@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected: Bool = true
    private(set) var connectionType: ConnectionType = .wifi
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.drivedock.networkmonitor")

    var onConnectionLost: (() -> Void)?
    var onConnectionRestored: (() -> Void)?

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = path.status == .satisfied
            let type = self.connectionType(for: path)

            DispatchQueue.main.async {
                let previousConnection = self.isConnected
                self.isConnected = connected
                self.connectionType = type

                if previousConnection && !connected {
                    self.onConnectionLost?()
                } else if !previousConnection && connected {
                    self.onConnectionRestored?()
                }
            }
        }
        monitor.start(queue: queue)
    }

    private func connectionType(for path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.status == .satisfied {
            return .other
        }
        return .unavailable
    }

    deinit {
        monitor.cancel()
    }
}
