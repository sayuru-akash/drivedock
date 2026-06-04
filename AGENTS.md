# DriveDock Agent Context

## Project Overview

**DriveDock** is a native macOS app for uploading files and folders to Google Drive. Built with Swift 5.9+ and SwiftUI, targeting macOS 14 (Sonoma) and later. It is a focused uploader — not a sync client — emphasizing speed, clarity, privacy, and control.

- **Repository**: `https://github.com/sayuru-akash/drivedock`
- **License**: MIT
- **Platform**: macOS 14+ only
- **No external dependencies**: Pure Foundation/SwiftUI/Security.framework. No Alamofire, no Google SDK, no CocoaPods/SPM packages.
- **Key Features**: Drag-and-drop uploads, folder structure preservation, parallel resumable uploads, multi-account OAuth, menu bar background operation, bandwidth limiting, upload history with CSV/JSON/text export.

See `@README.md` for full feature list and `@SPEC.md` for product principles and non-goals.

---

## Architecture

### Module Layout

```
DriveDock/
├── App/                          # Entry point, root view, global state
│   ├── DriveDockApp.swift        # @main, WindowGroup, MenuBarExtra, commands
│   ├── ContentView.swift         # Root: OnboardingView or NavigationSplitView
│   └── AppState.swift            # Singleton coordinator (@Observable)
├── Core/
│   ├── Models/                   # Data models (structs, enums)
│   └── Services/                 # Business logic singletons
│       ├── Auth/                 # OAuth 2.0 + PKCE, Keychain storage
│       ├── DriveAPI/             # Google Drive API v3 client
│       ├── Upload/               # UploadEngine: queue, workers, resumable chunks
│       ├── Download/             # DownloadEngine
│       ├── FileAccess/           # Drop handling, MIME detection, bookmarks
│       ├── Persistence/          # JSON file I/O in ~/Library/Application Support/DriveDock
│       └── Notifications/        # macOS UserNotifications
├── UI/
│   ├── Main/                     # Sidebar, drop zone, detail, overview
│   ├── Queue/                    # Table-based queue list, toolbar, filtering
│   ├── Destination/              # Drive folder picker, browser, recents, starred
│   ├── Inspector/                # Right-side detail pane (280pt)
│   ├── Onboarding/               # Multi-step welcome wizard
│   ├── Settings/                 # Tabbed preferences (Form + .grouped)
│   ├── History/                  # Upload history with export
│   ├── MenuBar/                  # Popover with status, drop zone, controls
│   └── Components/               # Reusable: StatusBadge, AccountSelectorButton, etc.
├── Resources/
│   ├── Assets.xcassets/
│   ├── DriveDock.entitlements
│   └── Info.plist
└── Utilities/                    # (reserved for helpers/extensions)
```

### Design Patterns

| Pattern | Implementation |
|---------|---------------|
| **State Management** | `@Observable` singletons (`AppState.shared`, `UploadEngine.shared`) injected via `.environment(appState)` and `@Environment(AppState.self)`. Do NOT use `@StateObject` / `.environmentObject`. |
| **Service Layer** | All external interaction abstracted behind singleton services: `GoogleAuthService`, `DriveAPIService`, `UploadEngine`, `PersistenceService`, `NotificationService`, `KeychainService`. |
| **MVVM** | Views bind to `@Observable` view models/state. Views are declarative and composable. |
| **Repository/Persistence** | `PersistenceService` handles JSON file I/O with `NSLock`. No Core Data/SwiftData/GRDB. |
| **Actor Isolation** | `UploadEngine` is `@MainActor @Observable`. Heavy I/O methods (`performUpload`, `performResumableUpload`) are `nonisolated` to avoid blocking MainActor. |
| **Continuation Bridge** | OAuth callback from local HTTP server bridged to async/await via `CheckedContinuation`. |
| **Task Deduplication** | `GoogleAuthService.coalescedRefresh` prevents concurrent token refresh for the same account. |
| **Error Classification** | Domain-specific `LocalizedError` enums + `ErrorCategory` enum for retryability heuristics. |
| **Cancellation** | Upload `Task`s are stored in `activeTasks: [String: Task<Void, Never>]` and cancelled on pause/cancel. |

---

## Technology Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI (primary), AppKit bridging where needed (`NSOpenPanel`, `NSWorkspace`)
- **Concurrency**: `async/await`, `Task`, `@MainActor`, `nonisolated`
- **Networking**: `URLSession` (custom configuration, no third-party clients)
- **Security**: `Security.framework` / Keychain Services (`SecItemAdd`, etc.)
- **Persistence**: JSON files in `FileManager.ApplicationSupportDirectory`
- **Notifications**: `UserNotifications` framework
- **Build System**: Xcode project (`.xcodeproj`), no Swift Package Manager dependencies

---

## Coding Standards

### Swift Style

- **Types**: PascalCase (`UploadEngine`, `DriveAPIService`)
- **Variables/Functions**: camelCase
- **Protocols/Enums**: Descriptive nouns (`UploadItemStatus`, `ErrorCategory`)
- **Singletons**: `static let shared` on final classes
- **Services**: Suffix `Service`
- **Views**: Suffix `View`
- **Models**: Suffix by type (`Item`, `Batch`, `Entry`, `Folder`, `Account`)
- **Actions**: Verb-led methods (`startProcessing`, `pauseAll`, `clearCompleted`)
- **Computed Properties**: Descriptive, often prefixed `formatted` (`formattedSize`, `formattedSpeed`, `formattedETA`)
- **Private Helpers**: Keep private and descriptive (`private func loadAccounts()`)

### SwiftUI Patterns (Mandatory)

- Use `@Observable` + `@Environment` / `@Bindable` for state. Never `@StateObject` or `.environmentObject`.
- Use `NavigationSplitView` for primary app navigation.
- Use `List(selection:)` for sidebars with selectable items.
- Use `Table` for data-heavy views (queue, history).
- Use `ContentUnavailableView` for empty states.
- Use `.onChange(of:)` for reactive side effects (settings persistence, state transitions).
- Use `withAnimation` / `.transition` for meaningful animations (onboarding, drop zone).
- Use `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityElement(children:)` everywhere.

### Enums

Enums are heavily used for domain modeling. Every enum should:

- Conform to `Codable`, `CaseIterable` where applicable
- Provide `displayName: String` for UI presentation
- Provide `systemImage: String` when representing a visual state
- Provide computed boolean properties (`isActive`, `isTerminal`, `isRetryable`) for business logic

Example:
```swift
enum UploadItemStatus: String, Codable, CaseIterable {
    case preparing, waiting, uploading, paused, completed, failed, cancelled

    var displayName: String { /* human-readable */ }
    var systemImage: String { /* SF Symbol name */ }
    var isActive: Bool { self == .uploading || self == .preparing }
    var isTerminal: Bool { self == .completed || self == .cancelled }
}
```

### Error Handling

- Define domain-specific `LocalizedError` enums for every service layer.
- Map all errors to `ErrorCategory` for retryability classification and user-facing guidance.
- Use `throw` for unrecoverable errors; use state mutation (`status = .failed`) for recoverable queue errors.

---

## Key Architectural Decisions

1. **No External Dependencies**: All functionality is built against native Apple frameworks. No Alamofire, no Google SDK, no third-party networking or persistence libraries.

2. **Custom OAuth HTTP Server**: `OAuthHTTPServer` binds to `localhost:18923` to receive OAuth callbacks. This avoids URL scheme registration conflicts. It is a raw BSD socket server, not a web framework.

3. **OAuth 2.0 with PKCE**: `GoogleAuthService` uses PKCE S256 code challenge. Tokens are stored exclusively in macOS Keychain. OAuth client ID/secret are injected via `Info.plist` / build settings (never hardcoded in source).

4. **Chunked Resumable Uploads**: Files < 5 MB use simple multipart upload. Files >= 5 MB use resumable upload with 8 MB chunks and `Content-Range` headers. Upload sessions survive app restarts via persisted `resumableSessionURL`.

5. **JSON File Persistence**: Queue, batches, history, recent/starred destinations are stored as JSON in `~/Library/Application Support/DriveDock/`. `PersistenceService` uses `NSLock` for thread safety and creates backups before writes.

6. **Bandwidth Limiting**: `UploadEngine` calculates per-chunk sleep duration based on `AppSettings.shared.bandwidthLimitKBps` and `SpeedTracker.currentWindowElapsed`.

7. **Speed Tracking**: `SpeedTracker` uses a 5-second sliding window (`[Date: Int64]` dictionary) with `NSLock` for thread-safe per-item speed calculation.

8. **Queue Persistence**: Queue and batch state are saved to disk after every state change (`persistence.saveQueue(items)`). This enables crash recovery and resume-on-launch.

9. **Menu Bar + Main Window Coexistence**: App uses `WindowGroup` for main window and `MenuBarExtra` with `.window` style. Closing the main window does not quit the app; uploads continue from the menu bar.

10. **Upload Concurrency Modes**: `UploadMode` enum defines max concurrent uploads: Balanced (3), Fast (6), Light (2).

---

## Service Reference

### GoogleAuthService
- `@Observable` singleton
- OAuth 2.0 + PKCE flow with local HTTP callback server on port `18923`
- Token refresh with coalesced deduplication (`activeRefreshTasks`)
- Keychain-only token storage (`token_<accountID>`)
- Account list persisted to `UserDefaults` as JSON

### DriveAPIService
- `@Observable` singleton
- Custom `URLSession` (30s request timeout, 600s resource timeout)
- Exponential backoff retry (`executeWithRetry`) for HTTP 500+, rate limits, timeouts
- Resumable upload: `initiateResumableUpload`, `uploadChunk`, `cancelResumableUpload`
- Simple upload for files < 5MB
- Shared Drive support

### UploadEngine
- `@MainActor @Observable` singleton
- Manages `items: [UploadItem]` and `batches: [UploadBatch]`
- Concurrent upload loop with configurable max concurrency
- `nonisolated` perform methods to avoid MainActor blocking during I/O
- Cancellation via stored `Task` references
- Automatic history logging on completion/failure
- Error classification → `ErrorCategory` mapping

### PersistenceService
- Singleton with `NSLock` for thread-safe JSON I/O
- Stores: `queue.json`, `batches.json`, `history.json`, `recent_destinations.json`, `starred_destinations.json`
- Automatic backup creation before writes
- Disk space check before writes
- History capped at 1000 entries; recent destinations capped at 20
- Export: JSON (pretty printed, ISO8601), CSV, plain text report

### KeychainService
- Wraps `Security.framework`
- Supports biometric-protected access control (`SecAccessControlCreateWithFlags`)
- Methods: `save(_:for:)`, `load(key:)`, `loadString(key:)`, `delete(key:)`, `deleteAll()`

---

## Models

### Core Value Types

| Type | Key Properties |
|------|---------------|
| `UploadItem` | `id`, `localFileName`, `localFilePath`, `fileSize`, `mimeType`, `destinationFolderID`, `accountID`, `status: UploadItemStatus`, `progress: Double`, `uploadedBytes`, `speed`, `eta`, `retryCount`, `errorMessage`, `errorCategory`, `driveFileID`, `resumableSessionURL`, `batchID`, `isFolder`, `folderPath`, `duplicateHandling` |
| `UploadBatch` | `id`, `name`, `accountID`, `destinationFolderID`, `status: UploadBatchStatus`, `itemIDs`, `totalSize`, `uploadedSize`, `duplicateHandling`, `preserveStructure` |
| `DriveAccount` | `id`, `email`, `displayName`, `avatarURL`, `connectedDate`, `isActive`, `tokenStatus: TokenStatus` |
| `DriveFolder` | `id`, `name`, `accountID`, `isSharedDrive`, `path` |
| `UploadHistoryEntry` | `id`, `fileName`, `fileSize`, `accountEmail`, `destinationFolderName`, `status`, `startedDate`, `completedDate`, `duration`, `averageSpeed`, `driveFileLink`, `batchID`, `isFolder` |
| `AppSettings` | `@Observable` singleton with all user preferences (upload mode, destination defaults, notification preferences, bandwidth limit, etc.) |

---

## UI Conventions

### Navigation
- `NavigationSplitView` with `SidebarView` (left) and `DetailView` (right)
- `SidebarItem` enum defines all navigable destinations with `displayName` and `systemImage`
- `SidebarSection` groups items: uploads, destinations, other

### Modals & Sheets
- `DestinationPickerView`: 500×450 sheet with tabbed interface (Browse, Recent, Starred, Shared Drives)
- `SettingsView`: 620×500 tabbed settings (`TabView` with General, Uploads, Accounts, Network, Privacy, Advanced)
- `OnboardingView`: Full-screen multi-step wizard with `.opacity` transitions

### Status Indicators
- `StatusBadge`: Capsule with SF Symbol + label, colored by status (green=completed, red=failed, blue=uploading, yellow=paused, etc.)
- `MenuBarIcon`: System symbol with circular progress overlay
- `StatusBar`: Live status dot, active count, total speed, overall progress

### Keyboard Shortcuts
All shortcuts are defined in `DriveDockApp.swift` via `.commands`:

| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New Upload |
| `Cmd+O` | Add Files |
| `Cmd+Shift+O` | Add Folder |
| `Cmd+P` | Pause/Resume All |
| `Cmd+R` | Resume All |
| `Cmd+Shift+K` | Clear Completed |
| `Cmd+Shift+I` | Toggle Inspector |
| `Cmd+1`–`Cmd+6` | Switch sidebar views |
| `Cmd+,` | Settings |

---

## Concurrency & Threading Rules

1. **MainActor**: `UploadEngine`, `AppState`, and all SwiftUI views run on `@MainActor`. State mutations (array updates, progress changes) must happen on MainActor.
2. **Non-Blocking I/O**: File reading, network requests, and chunk uploads are `nonisolated` methods that hop to MainActor only to update state.
3. **Locks**: `PersistenceService` uses `NSLock`. `SpeedTracker` uses `NSLock`. `GoogleAuthService` uses `NSLock` for refresh task deduplication.
4. **Task Cancellation**: All active uploads are `Task` instances stored in `activeTasks`. Cancel via `task.cancel()` and check `Task.isCancelled` in upload loops.
5. **URLSession**: `waitsForConnectivity = true` for resilience during transient network loss.

---

## Testing Standards

- **Framework**: XCTest with `@testable import DriveDock`
- **Location**: `DriveDockTests/` (one test file per model/service)
- **Patterns**:
  - Exhaustive enum testing: verify every case's `displayName`, `systemImage`, computed properties
  - Edge cases: zero values, nil values, boundary conditions (`testFormattedSpeedWhenZero`)
  - State isolation: verify independent keys don't interfere
  - Error conditions: verify non-throwing behavior on missing data
- **Files**: `UploadItemTests`, `UploadBatchTests`, `DriveAccountTests`, `DriveFolderTests`, `AppSettingsTests`, `PersistenceServiceTests`, `KeychainServiceTests`, `FileDropHandlerTests`, `MIMETypeDetectorTests`, `SpeedTrackerTests`

---

## Common Workflows

### Adding a New Upload Feature
1. Update `UploadItem` or `UploadBatch` model if data changes
2. Add business logic to `UploadEngine`
3. Update UI in `UploadQueueView` or `QueueItemRow`
4. Update `InspectorView` if detail pane needs new info
5. Add tests in `DriveDockTests/`
6. Persist new state in `PersistenceService` if needed

### Adding a New Settings Option
1. Add property to `AppSettings` with default value
2. Add `load()` and `save()` logic with `UserDefaults` key
3. Add UI control in `SettingsView` inside appropriate tab
4. Use `.onChange(of:)` to trigger `settings.save()`
5. Reference setting from `UploadEngine` or relevant service

### Adding OAuth / Account Logic
1. Use `GoogleAuthService` for all token operations
2. Use `KeychainService` for secure storage (never UserDefaults for tokens)
3. Update `DriveAccount` model if account metadata changes
4. Update `AccountSelectorButton` and settings account list UI

### Adding Drive API Operations
1. Add method to `DriveAPIService`
2. Define response/request structs if needed
3. Use `executeWithRetry` for resilience
4. Map errors to `DriveAPIError` cases
5. Update `ErrorCategory` classification in `UploadEngine` if new error types emerge

---

## Security & Privacy Rules

- **OAuth tokens**: Keychain ONLY. Never write to disk, logs, SQLite, or JSON.
- **Secrets**: `Secrets.xcconfig` contains `CLIENT_ID` and `CLIENT_SECRET`. It is gitignored but verify it is not committed.
- **Scopes**: Minimal OAuth scopes (`drive.file`, `drive.readonly`, `userinfo.email`, `userinfo.profile`). No unnecessary profile/contact scopes.
- **No Analytics/Telemetry**: Zero hidden tracking. All data stays local.
- **Sandbox**: App uses entitlements; respect sandbox boundaries for file access. Use security-scoped bookmarks for dragged files.
- **Biometric Auth**: `KeychainService` supports `SecAccessControlCreateWithFlags(.biometryCurrentSet)` for optional biometric protection.

---

## Build & Development

### Requirements
- macOS 14 Sonoma+
- Xcode 15.0+
- Google Cloud project with OAuth 2.0 Desktop credentials

### Configuration
Set `GOOGLE_OAUTH_CLIENT_ID` via:
- `Secrets.xcconfig` (local, gitignored)
- Xcode scheme environment variables
- Build settings / `Info.plist` injection

### Scripts
- `scripts/setup.sh` — Development environment setup
- `scripts/generate_icon.py` — App icon generation utility

### Build Commands
```bash
# Open in Xcode
open DriveDock.xcodeproj

# Command line build
xcodebuild -scheme DriveDock -configuration Debug build

# Run tests
xcodebuild -scheme DriveDock -configuration Debug test
```

---

## Agent Instructions

When modifying code in this project:

1. **Read first**: Always read existing files before modifying. Follow established patterns.
2. **No new dependencies**: Do not add Swift Package Manager, CocoaPods, or Carthage dependencies. Use native frameworks only.
3. **Observable pattern**: Use `@Observable` and `@Environment`. Do not introduce `@StateObject` or Combine publishers for state.
4. **MainActor discipline**: Keep `@MainActor` state mutations lightweight. Offload I/O and network to `nonisolated` methods.
5. **Error completeness**: Every new error path needs a `LocalizedError` enum case and an `ErrorCategory` mapping if retryability is relevant.
6. **Accessibility**: Add `.accessibilityLabel` and `.accessibilityHint` to all interactive UI elements.
7. **Persistence**: If you introduce new persisted state, add it to `PersistenceService` with JSON encoding, `NSLock`, and backup behavior.
8. **Tests**: Add unit tests for new model behavior and enum cases. Follow the exhaustive testing pattern.
9. **Security**: Never log tokens, file paths containing PII, or OAuth credentials. Keychain is the only token store.
10. **macOS native feel**: Use standard macOS window behaviors, toolbars, sheets, and menu commands. Match Apple's Human Interface Guidelines.
