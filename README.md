# DriveDock

> The cleanest way to upload files to Google Drive from your Mac.

DriveDock is a native macOS app for uploading files and folders to Google Drive with speed, clarity, and control. Built with Swift and SwiftUI, it feels right at home on your Mac.

## Features

- **Native macOS experience** — Built with Swift and SwiftUI for a truly native feel
- **Drag-and-drop uploads** — Drop files or folders onto the app or menu bar
- **Multi-account support** — Connect multiple Google accounts and switch easily
- **Parallel uploads** — Upload multiple files simultaneously with adaptive concurrency
- **Resumable uploads** — Large files resume where they left off after interruptions
- **Background uploads** — Continue uploading when the window is closed
- **Queue management** — Pause, resume, cancel, retry, and reorder uploads
- **Folder structure preservation** — Upload folders with nested hierarchy intact
- **Shared Drive support** — Upload to Shared Drives you have access to
- **Destination picker** — Browse, search, and select Google Drive folders
- **Upload history** — Track every upload with detailed completion reports
- **Duplicate handling** — Choose how to handle files with the same name
- **Menu bar helper** — Quick access and progress from the menu bar
- **Native notifications** — Get notified when uploads complete or need attention
- **Secure token storage** — Credentials stored safely in macOS Keychain
- **Smart error recovery** — Automatic retry with exponential backoff

## Requirements

- macOS 14 Sonoma or later
- A Google account with Google Drive access
- Google Cloud project with Drive API enabled (for OAuth credentials)

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/sayuru-akash/drivedock.git
cd drivedock
```

### 2. Set up Google OAuth credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Drive API
4. Create OAuth 2.0 credentials (Desktop application type)
5. Copy the client ID and set it as an environment variable or in your build configuration

### 3. Build and run

Open `DriveDock.xcodeproj` in Xcode:

```bash
open DriveDock.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -scheme DriveDock -configuration Debug build
```

### 4. Configure OAuth

Set your Google OAuth client ID in the app's configuration. See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed setup instructions.

## Architecture

DriveDock follows a clean, modular architecture:

```
DriveDock/
├── App/                    # App entry point, window management
├── Core/
│   ├── Models/             # Data models
│   └── Services/
│       ├── Auth/           # OAuth, Keychain, token management
│       ├── DriveAPI/       # Google Drive API integration
│       ├── Upload/         # Upload engine, queue, retry logic
│       ├── Persistence/    # Local database (SQLite)
│       ├── Notifications/  # macOS notifications
│       └── FileAccess/     # Drag-drop, bookmarks, MIME detection
├── UI/
│   ├── Onboarding/         # First-launch screens
│   ├── Main/               # Main window layout
│   ├── Queue/              # Upload queue views
│   ├── Inspector/          # Item detail panel
│   ├── Destination/        # Drive folder picker
│   ├── Settings/           # Preferences window
│   ├── History/            # Upload history
│   ├── MenuBar/            # Menu bar popover
│   └── Components/         # Shared UI components
├── Utilities/              # Helpers and extensions
└── Resources/              # Assets, colors, icons
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Security

See [SECURITY.md](SECURITY.md) for our security policy.

## License

DriveDock is released under the [MIT License](LICENSE).
