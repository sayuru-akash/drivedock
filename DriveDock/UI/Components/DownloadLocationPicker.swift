import SwiftUI
import AppKit

struct DownloadLocationPicker {
    static func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Download Location"
        panel.message = "Select where to save the downloaded files"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            panel.directoryURL = downloadsURL
        }
        
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        
        // Start accessing security-scoped resource
        _ = url.startAccessingSecurityScopedResource()
        
        return url
    }
    
    static func pickSaveLocation(for fileName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save Download"
        panel.message = "Choose where to save \(fileName)"
        panel.nameFieldStringValue = fileName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            panel.directoryURL = downloadsURL
        }
        
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        
        // Start accessing security-scoped resource
        _ = url.startAccessingSecurityScopedResource()
        
        return url
    }
    
    static func pickDownloadFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Download To..."
        panel.message = "Choose where to save downloads"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            panel.directoryURL = downloadsURL
        }
        
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        
        // Start accessing security-scoped resource
        _ = url.startAccessingSecurityScopedResource()
        
        return url
    }
}
