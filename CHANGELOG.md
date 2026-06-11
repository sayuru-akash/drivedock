# Changelog

All notable changes to DriveDock will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

#### Core
- Native macOS app built with Swift 5.9+ and SwiftUI, targeting macOS 14 Sonoma+
- Google OAuth 2.0 with PKCE and local HTTP server callback (port 18923)
- Multi-account support with account switching and per-upload account selection
- Google Drive API v3 integration with full Drive browsing and Shared Drive support
- Download engine with parallel downloads

#### Uploads
- Drag-and-drop file and folder uploads (main window, menu bar popover, Dock icon)
- Clipboard paste support (`Cmd+V`) for adding files
- Parallel upload engine with adaptive concurrency (error rate and HTTP 429 aware)
- Resumable upload support for large files (8 MB chunks, session recovery across restarts)
- Folder structure preservation during uploads
- Upload queue management: pause, resume, cancel, retry, reorder, prioritise
- Duplicate file handling: keep both, rename, skip, or replace
- Smart error recovery with exponential backoff and jitter
- Bandwidth limiting with configurable speed cap

#### Destinations & Drive
- Destination picker with My Drive, Shared Drives, search, and folder creation
- Recent and starred destination bookmarks
- Upload plan summary before starting

#### Queue & History
- Queue persistence across app restarts
- Upload history with timestamps, file size, duration, average speed, destination, and Drive links
- Completion summary with export
- Export history as CSV, JSON, or plain text

#### Menu Bar & Background
- Menu bar helper with progress ring, active count, drop zone, recent completions, and account switch
- Background upload support (uploads continue when main window is closed)
- Sleep/wake detection with automatic pause and resume
- Network monitoring with auto-pause on disconnection and auto-resume on reconnect

#### Security & Privacy
- Secure token storage in macOS Keychain with optional biometric protection
- Security-scoped bookmarks for sandboxed file access
- Minimal OAuth scopes (`drive.file`, `drive.readonly`, `userinfo.email`, `userinfo.profile`)
- No analytics, telemetry, or tracking

#### UI & Accessibility
- Native macOS design with light, dark, and system theme support
- Accent colour customisation (6 colour options)
- Settings panel with 6 tabs: General, Uploads, Accounts, Network, Privacy, Advanced
- Native macOS notifications with action buttons
- Reduced motion accessibility support
- `NavigationSplitView` sidebar with Uploads, Queue, Active, Completed, Failed, Paused, Destinations, History, and Settings views

#### Testing & Documentation
- Comprehensive test suite with 10 test files: UploadItemTests, UploadBatchTests, DriveAccountTests, DriveFolderTests, AppSettingsTests, PersistenceServiceTests, KeychainServiceTests, FileDropHandlerTests, MIMETypeDetectorTests, SpeedTrackerTests
- DESIGN.md design system documentation
