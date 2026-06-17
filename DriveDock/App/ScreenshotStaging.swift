#if DEBUG
import AppKit
import Foundation
import SwiftUI

enum ScreenshotScene: String {
    case main
    case queue
    case destinationPicker = "destination-picker"
    case downloads
    case settings
    case driveBrowser = "drive-browser"
    case menuBar = "menu-bar"
}

@MainActor
enum ScreenshotStaging {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["DRIVEDOCK_SCREENSHOT_MODE"] == "1"
    }

    static var scene: ScreenshotScene {
        let rawValue = ProcessInfo.processInfo.environment["DRIVEDOCK_SCREENSHOT_SCENE"] ?? ScreenshotScene.main.rawValue
        return ScreenshotScene(rawValue: rawValue) ?? .main
    }

    static var windowSize: CGSize {
        switch scene {
        case .destinationPicker:
            return CGSize(width: 560, height: 510)
        case .settings:
            return CGSize(width: 680, height: 560)
        case .menuBar:
            return CGSize(width: 320, height: 560)
        default:
            return CGSize(width: 1180, height: 760)
        }
    }

    static var sampleDriveFiles: [DriveFile] {
        [
            DriveFile(id: "folder-marketing", name: "Marketing Launch Assets", mimeType: "application/vnd.google-apps.folder", size: nil, parentID: "root", webViewLink: nil, createdDate: nil, modifiedDate: Date().addingTimeInterval(-3600)),
            DriveFile(id: "folder-client", name: "Client Deliverables", mimeType: "application/vnd.google-apps.folder", size: nil, parentID: "root", webViewLink: nil, createdDate: nil, modifiedDate: Date().addingTimeInterval(-7200)),
            DriveFile(id: "folder-finance", name: "Finance Reports", mimeType: "application/vnd.google-apps.folder", size: nil, parentID: "root", webViewLink: nil, createdDate: nil, modifiedDate: Date().addingTimeInterval(-11800)),
            DriveFile(id: "file-video", name: "brand-film-final.mov", mimeType: "video/quicktime", size: 1_684_217_856, parentID: "root", webViewLink: "https://drive.google.com/file/d/file-video/view", createdDate: nil, modifiedDate: Date().addingTimeInterval(-18400)),
            DriveFile(id: "file-deck", name: "Q3-roadmap-presentation.pdf", mimeType: "application/pdf", size: 28_719_104, parentID: "root", webViewLink: "https://drive.google.com/file/d/file-deck/view", createdDate: nil, modifiedDate: Date().addingTimeInterval(-24000)),
            DriveFile(id: "file-image", name: "storefront-retouch-export.tif", mimeType: "image/tiff", size: 142_901_248, parentID: "root", webViewLink: "https://drive.google.com/file/d/file-image/view", createdDate: nil, modifiedDate: Date().addingTimeInterval(-38000))
        ]
    }

    static var sampleFolders: [DriveFolder] {
        [
            DriveFolder(id: "folder-marketing", name: "Marketing Launch Assets", parentID: "root", isSharedDrive: false, sharedDriveID: nil, ownerEmail: "maya@example.com", modifiedDate: Date().addingTimeInterval(-3600), childCount: 28),
            DriveFolder(id: "folder-client", name: "Client Deliverables", parentID: "root", isSharedDrive: false, sharedDriveID: nil, ownerEmail: "maya@example.com", modifiedDate: Date().addingTimeInterval(-7200), childCount: 14),
            DriveFolder(id: "folder-shared", name: "Agency Shared Drive", parentID: nil, isSharedDrive: true, sharedDriveID: "drive-agency", ownerEmail: nil, modifiedDate: Date().addingTimeInterval(-9200), childCount: 43),
            DriveFolder(id: "folder-archive", name: "Archive - Uploaded Originals", parentID: "root", isSharedDrive: false, sharedDriveID: nil, ownerEmail: "ops@example.com", modifiedDate: Date().addingTimeInterval(-16400), childCount: 112)
        ]
    }

    static func configure(_ appState: AppState) {
        guard isEnabled else { return }

        appState.hasCompletedOnboarding = true
        appState.showInspector = true
        appState.showSettings = false
        appState.showDestinationPicker = false

        appState.settings.theme = .light
        appState.settings.accentColor = .blue
        appState.settings.defaultUploadMode = .balanced
        appState.settings.maxParallelUploads = 3
        appState.settings.bandwidthLimitKBps = 4096

        appState.auth.replaceWithScreenshotAccounts(sampleAccounts)
        appState.engine.replaceWithScreenshotData(items: sampleUploads, batches: sampleUploadBatches)
        appState.downloadEngine.replaceWithScreenshotData(items: sampleDownloads, batches: sampleDownloadBatches)
        appState.selectedUploadItemID = sampleUploads.first?.id

        switch scene {
        case .main:
            appState.selectedSidebarItem = .uploads
        case .queue:
            appState.selectedSidebarItem = .active
        case .downloads:
            appState.selectedSidebarItem = .downloads
        case .driveBrowser:
            appState.selectedSidebarItem = .myDrive
        case .destinationPicker, .settings, .menuBar:
            appState.selectedSidebarItem = .uploads
        }
    }

    private static var sampleAccounts: [DriveAccount] {
        [
            DriveAccount(id: "demo-personal", email: "maya@codezela.com", displayName: "Maya Fernando", avatarURL: nil, connectedDate: Date().addingTimeInterval(-86400 * 28), isActive: true, tokenStatus: .valid),
            DriveAccount(id: "demo-agency", email: "ops@northstar.studio", displayName: "Northstar Studio", avatarURL: nil, connectedDate: Date().addingTimeInterval(-86400 * 12), isActive: false, tokenStatus: .valid)
        ]
    }

    private static var sampleUploadBatches: [UploadBatch] {
        [
            UploadBatch(id: "batch-launch", name: "Launch asset upload", accountID: "demo-personal", destinationFolderID: "folder-marketing", destinationFolderName: "Marketing Launch Assets", status: .uploading, itemIDs: sampleUploads.map(\.id), createdDate: Date().addingTimeInterval(-900), startedDate: Date().addingTimeInterval(-780), completedDate: nil, totalSize: sampleUploads.reduce(0) { $0 + $1.fileSize }, uploadedSize: sampleUploads.reduce(0) { $0 + $1.uploadedBytes }, duplicateHandling: .renameNew, preserveStructure: true)
        ]
    }

    private static var sampleUploads: [UploadItem] {
        [
            upload(id: "upload-video", name: "brand-film-final.mov", path: "/Users/maya/Projects/Launch/brand-film-final.mov", size: 1_684_217_856, mime: "video/quicktime", status: .uploading, progress: 0.64, uploaded: 1_077_899_427, speed: 11_923_456, eta: 52, destination: "Marketing Launch Assets", batchID: "batch-launch"),
            upload(id: "upload-deck", name: "Q3-roadmap-presentation.pdf", path: "/Users/maya/Projects/Launch/Q3-roadmap-presentation.pdf", size: 28_719_104, mime: "application/pdf", status: .completed, progress: 1, uploaded: 28_719_104, speed: 0, eta: nil, destination: "Marketing Launch Assets", batchID: "batch-launch", completed: true),
            upload(id: "upload-images", name: "retouched-product-gallery.zip", path: "/Users/maya/Projects/Launch/retouched-product-gallery.zip", size: 416_284_672, mime: "application/zip", status: .waiting, progress: 0, uploaded: 0, speed: 0, eta: nil, destination: "Marketing Launch Assets", batchID: "batch-launch"),
            upload(id: "upload-spec", name: "app-store-copy-draft.pages", path: "/Users/maya/Projects/Launch/app-store-copy-draft.pages", size: 8_241_152, mime: "application/octet-stream", status: .paused, progress: 0.27, uploaded: 2_225_111, speed: 0, eta: nil, destination: "Client Deliverables", batchID: "batch-launch"),
            upload(id: "upload-archive", name: "raw-camera-archive", path: "/Users/maya/Projects/Launch/raw-camera-archive", size: 7_642_382_336, mime: "application/octet-stream", status: .failed, progress: 0.18, uploaded: 1_375_628_820, speed: 0, eta: nil, destination: "Agency Shared Drive", batchID: "batch-launch", isFolder: true, error: "Shared Drive permission changed", category: .permission)
        ]
    }

    private static var sampleDownloadBatches: [DownloadBatch] {
        [
            DownloadBatch(id: "download-batch", name: "Client review folder", accountID: "demo-personal", sourceFolderID: "folder-client", sourceFolderName: "Client Deliverables", status: .downloading, itemIDs: sampleDownloads.map(\.id), createdDate: Date().addingTimeInterval(-420), totalSize: sampleDownloads.reduce(0) { $0 + $1.fileSize }, downloadedSize: sampleDownloads.reduce(0) { $0 + $1.downloadedBytes })
        ]
    }

    private static var sampleDownloads: [DownloadItem] {
        [
            download(id: "download-video", name: "client-feedback-cut.mp4", size: 624_951_296, downloaded: 387_469_803, progress: 0.62, speed: 8_412_000, status: .downloading),
            download(id: "download-notes", name: "approved-copy-notes.docx", size: 4_784_128, downloaded: 4_784_128, progress: 1, speed: 0, status: .completed),
            download(id: "download-brief", name: "brand-guidelines.pdf", size: 17_420_288, downloaded: 0, progress: 0, speed: 0, status: .waiting),
            download(id: "download-archive", name: "source-photography.zip", size: 956_301_312, downloaded: 204_401_233, progress: 0.21, speed: 0, status: .paused)
        ]
    }

    private static func upload(
        id: String,
        name: String,
        path: String,
        size: Int64,
        mime: String,
        status: UploadItemStatus,
        progress: Double,
        uploaded: Int64,
        speed: Double,
        eta: TimeInterval?,
        destination: String,
        batchID: String,
        completed: Bool = false,
        isFolder: Bool = false,
        error: String? = nil,
        category: ErrorCategory? = nil
    ) -> UploadItem {
        UploadItem(
            id: id,
            localFileName: name,
            localFilePath: path,
            fileSize: size,
            mimeType: mime,
            destinationFolderID: destination == "Agency Shared Drive" ? "folder-shared" : "folder-marketing",
            destinationFolderName: destination,
            accountID: "demo-personal",
            status: status,
            progress: progress,
            uploadedBytes: uploaded,
            speed: speed,
            eta: eta,
            retryCount: status == .failed ? 2 : 0,
            errorMessage: error,
            errorCategory: category,
            driveFileID: completed ? "drive-\(id)" : nil,
            driveFileLink: completed ? "https://drive.google.com/file/d/drive-\(id)/view" : nil,
            resumableSessionURL: status == .uploading ? "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&upload_id=\(id)" : nil,
            createdDate: Date().addingTimeInterval(-900),
            lastActivityDate: Date().addingTimeInterval(-20),
            completedDate: completed ? Date().addingTimeInterval(-120) : nil,
            batchID: batchID,
            isFolder: isFolder,
            folderPath: isFolder ? "Launch/raw-camera-archive" : nil,
            duplicateHandling: .renameNew,
            securityScopedBookmark: nil
        )
    }

    private static func download(
        id: String,
        name: String,
        size: Int64,
        downloaded: Int64,
        progress: Double,
        speed: Double,
        status: DownloadItemStatus
    ) -> DownloadItem {
        DownloadItem(
            id: id,
            fileName: name,
            driveFileID: "drive-\(id)",
            localPath: "/Users/maya/Downloads/DriveDock/\(name)",
            fileSize: size,
            downloadedBytes: downloaded,
            progress: progress,
            speed: speed,
            eta: status == .downloading ? 29 : nil,
            status: status,
            error: nil,
            accountID: "demo-personal",
            createdDate: Date().addingTimeInterval(-420),
            lastActivityDate: Date().addingTimeInterval(-12),
            completedDate: status == .completed ? Date().addingTimeInterval(-90) : nil,
            batchID: "download-batch",
            isFolder: false,
            folderPath: nil
        )
    }
}

@MainActor
final class ScreenshotWindowController {
    private static var screenshotWindow: NSWindow?

    static func show() {
        guard ScreenshotStaging.isEnabled else { return }

        let appState = AppState.shared
        ScreenshotStaging.configure(appState)

        let size = ScreenshotStaging.windowSize
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "DriveDock"
        window.center()
        window.setContentSize(size)
        window.contentView = NSHostingView(
            rootView: ScreenshotStagingRootView()
                .environment(appState)
                .frame(width: size.width, height: size.height)
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        screenshotWindow = window
        fputs("DriveDock screenshot staging window ready: \(ScreenshotStaging.scene.rawValue)\n", stderr)
    }
}

@MainActor
struct ScreenshotStagingRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch ScreenshotStaging.scene {
        case .destinationPicker:
            DestinationPickerView(accountID: appState.auth.activeAccount?.id ?? "demo-personal") { _ in }
                .padding(24)
                .background(Color(nsColor: .windowBackgroundColor))
        case .settings:
            SettingsView()
                .padding(24)
                .background(Color(nsColor: .windowBackgroundColor))
        case .menuBar:
            MenuBarPopoverView()
                .padding(20)
                .background(Color(nsColor: .windowBackgroundColor))
        default:
            NavigationSplitView {
                SidebarView()
            } detail: {
                DetailView()
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    AccountSelectorButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Image(systemName: "gearshape")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                    }
                    .accessibilityLabel("Settings")
                    .help("Open Settings")
                }
            }
        }
    }
}
#endif
