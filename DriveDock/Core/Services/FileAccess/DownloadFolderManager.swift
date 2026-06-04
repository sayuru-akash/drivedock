import Foundation
import AppKit

final class DownloadFolderManager {
    static let shared = DownloadFolderManager()
    
    private let bookmarkKey = "downloadFolderBookmark"
    private var resolvedURL: URL?
    
    private init() {
        loadSavedFolder()
    }
    
    var downloadFolder: URL? {
        return resolvedURL
    }
    
    func requestDownloadFolder() -> URL? {
        // If we already have a saved folder, use it
        if let existing = resolvedURL {
            return existing
        }
        
        // Ask user to select Downloads folder
        let panel = NSOpenPanel()
        panel.title = "Select Downloads Folder"
        panel.message = "DriveDock needs permission to save downloaded files. Please select your Downloads folder."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        // Default to ~/Downloads
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            panel.directoryURL = downloadsURL
        }
        
        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return nil
        }
        
        // Save bookmark for future use
        saveFolderBookmark(url: selectedURL)
        resolvedURL = selectedURL
        
        return selectedURL
    }
    
    func resetFolder() {
        resolvedURL = nil
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }
    
    private func saveFolderBookmark(url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        } catch {
            print("Failed to save bookmark: \(error)")
        }
    }
    
    private func loadSavedFolder() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                // Bookmark is stale, need to re-select
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
                return
            }
            
            // Start accessing the security-scoped resource
            if url.startAccessingSecurityScopedResource() {
                resolvedURL = url
            } else {
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
            }
        } catch {
            print("Failed to load bookmark: \(error)")
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
        }
    }
}
