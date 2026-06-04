import Foundation
import AppKit

final class DownloadFolderManager {
    static let shared = DownloadFolderManager()
    
    private init() {}
    
    var downloadFolder: URL {
        // Use real ~/Downloads, not sandbox container path
        let realHome = NSHomeDirectory()
        return URL(fileURLWithPath: realHome).appendingPathComponent("Downloads")
    }
    
    func requestDownloadFolder() -> URL {
        return downloadFolder
    }
    
    func resetFolder() {
        // No-op
    }
}
