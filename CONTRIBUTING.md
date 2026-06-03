# Contributing to DriveDock

Thank you for your interest in contributing to DriveDock! This document provides guidelines and instructions for contributing to the project. Whether you are fixing a bug, adding a feature, improving documentation, or reporting an issue, your help is appreciated.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Code Style](#code-style)
- [Making Changes](#making-changes)
- [Pull Request Process](#pull-request-process)
- [Testing](#testing)
- [Reporting Bugs](#reporting-bugs)
- [Requesting Features](#requesting-features)
- [Documentation](#documentation)
- [License](#license)

---

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behaviour to the project maintainers.

---

## Getting Started

### Prerequisites

Before you begin, make sure you have:

- **macOS 14 Sonoma** or later
- **Xcode 15.0** or later
- **Git** installed (`git --version` to check)
- **A Google Cloud project** with OAuth 2.0 credentials (see below)

### Fork and Clone

1. Fork the repository on GitHub.
2. Clone your fork locally:

```bash
git clone https://github.com/YOUR_USERNAME/drivedock.git
cd drivedock
```

3. Add the upstream remote:

```bash
git remote add upstream https://github.com/sayuru-akash/drivedock.git
```

4. Verify your remotes:

```bash
git remote -v
```

---

## Development Setup

### 1. Set Up Google OAuth Credentials

DriveDock requires Google OAuth 2.0 credentials for development. These are local to your machine and should never be committed.

1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project (e.g., `DriveDock Dev`).
3. Enable the **Google Drive API**:
   - Go to **APIs & Services > Library**
   - Search for "Google Drive API"
   - Click **Enable**
4. Configure the **OAuth consent screen**:
   - Go to **APIs & Services > OAuth consent screen**
   - Select **External** user type
   - Fill in app name, support email, and developer contact
   - Add the scope `https://www.googleapis.com/auth/drive.file`
   - Add your email as a test user
5. Create **OAuth 2.0 credentials**:
   - Go to **APIs & Services > Credentials**
   - Click **Create Credentials > OAuth client ID**
   - Select **Desktop application**
   - Name it `DriveDock Dev`
   - Click **Create**
   - Copy the **Client ID**

### 2. Configure the Client ID

Set the client ID as an environment variable or in a local xcconfig file:

**Option A: Xcode Scheme Environment Variable**

1. In Xcode, go to **Product > Scheme > Edit Scheme**
2. Select **Run > Arguments > Environment Variables**
3. Add `GOOGLE_OAUTH_CLIENT_ID` with your Client ID value

**Option B: Local xcconfig file**

Create a file named `Local.xcconfig` in the project root (this file is gitignored):

```
GOOGLE_OAUTH_CLIENT_ID = YOUR_CLIENT_ID_HERE.apps.googleusercontent.com
```

### 3. Build and Run

```bash
open DriveDock.xcodeproj
```

Select the `DriveDock` scheme, choose your Mac as the destination, and press `Cmd+R`.

From the command line:

```bash
xcodebuild -scheme DriveDock -configuration Debug build
```

### 4. Run Tests

In Xcode, press `Cmd+U` to run all tests.

From the command line:

```bash
xcodebuild -scheme DriveDock -configuration Debug test
```

---

## Project Structure

```
DriveDock/
├── App/                    # App entry point, window management, lifecycle
├── Core/
│   ├── Models/             # Data models (Upload, Account, QueueItem, etc.)
│   └── Services/
│       ├── Auth/           # OAuth flow, Keychain, token management
│       ├── DriveAPI/       # Google Drive API v3 integration
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
└── Resources/              # Assets, colours, icons
```

When adding new code, follow this existing structure. If you are unsure where a file belongs, open a discussion in your pull request.

---

## Code Style

### Swift Conventions

- **Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).** These are the foundation for all Swift code in this project.
- **Use SwiftUI for all new views** unless AppKit is genuinely required for functionality that SwiftUI does not support.
- **Prefer `async/await`** over completion handlers for asynchronous code.
- **Use `@Observable`** (macOS 14+) over `ObservableObject` where possible. The project targets macOS 14 minimum.
- **Use actors** for shared mutable state in concurrent code, especially in the upload engine.
- **Keep views small and composable.** If a view exceeds ~150 lines, consider extracting subviews.
- **Use meaningful names.** Variable and function names should clearly describe their purpose.

### Naming

| Element | Convention | Example |
|---------|------------|---------|
| Types (structs, classes, enums) | `UpperCamelCase` | `UploadQueueItem`, `DriveFolder` |
| Functions and methods | `lowerCamelCase` | `startUpload()`, `fetchFolderContents()` |
| Variables and constants | `lowerCamelCase` | `uploadSpeed`, `maxRetries` |
| Protocols | `UpperCamelCase`, often adjective or noun | `UploadServiceProtocol`, `Authenticatable` |
| Enums cases | `lowerCamelCase` | `.uploading`, `.needsAttention` |

### Formatting

- Use **4 spaces** for indentation (no tabs).
- Keep lines under **120 characters** where practical.
- Use trailing commas in multi-line arrays and dictionaries.
- Add a blank line between logical sections of a function.
- Use `// MARK: -` to organise code sections within a file.

### Documentation Comments

Write documentation comments for all public APIs:

```swift
/// Starts uploading the given files to the specified Drive destination.
///
/// - Parameters:
///   - files: An array of local file URLs to upload.
///   - destination: The Drive folder to upload to.
///   - account: The Google account to use for the upload.
/// - Returns: An array of created queue items.
func startUpload(
    files: [URL],
    destination: DriveFolder,
    account: GoogleAccount
) async throws -> [QueueItem] {
    // implementation
}
```

### What to Avoid

- Do not force-unwrap (`!`) unless you can prove the value is never nil and there is no better alternative.
- Do not use `try!` in production code.
- Do not add third-party dependencies without discussion in an issue first.
- Do not commit API keys, client IDs, or secrets.
- Do not add comments unless they explain *why* something is done a non-obvious way (the code should explain *what*).

---

## Making Changes

### Branch Naming

Use descriptive branch names:

| Type | Format | Example |
|------|--------|---------|
| Feature | `feature/short-description` | `feature/bandwidth-limit` |
| Bug fix | `fix/short-description` | `fix/queue-persistence-crash` |
| Documentation | `docs/short-description` | `docs/update-readme` |
| Refactor | `refactor/short-description` | `refactor/upload-engine-cleanup` |

### Commit Messages

Write clear, concise commit messages:

- Use the imperative mood: "Add feature" not "Added feature"
- Keep the first line under 72 characters
- Add a body for non-trivial changes explaining *why* the change was made

```
Add bandwidth limit setting for upload speed control

Users on metered connections or shared networks need the ability to
limit DriveDock's upload speed. This adds a configurable bandwidth
limit in Settings > Uploads that caps the per-upload speed using
a token bucket algorithm.
```

### Keep Changes Focused

Each pull request should address a single concern. If you find an unrelated issue while working, open a separate issue or PR for it.

---

## Pull Request Process

### Before Submitting

1. **Sync with upstream**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Build without warnings**: The project must build cleanly with no warnings.

3. **Run all tests**: Press `Cmd+U` in Xcode. All tests must pass.

4. **Test manually**: Run the app and verify your changes work as expected. See the [Manual QA Checklist](#manual-qa-checklist) below.

### Submitting

1. Push your branch to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

2. Open a pull request on GitHub against the `main` branch.

3. Fill in the PR template completely:
   - Describe what the PR does and why.
   - Link to any related issues.
   - Include screenshots or screen recordings for UI changes.
   - List any breaking changes.

4. Request a review from a maintainer.

### PR Checklist

Use the checklist in the PR template:

- [ ] Code follows the project's code style
- [ ] Build succeeds without warnings
- [ ] All tests pass
- [ ] New tests added for new functionality
- [ ] Documentation updated where needed
- [ ] No secrets or API keys committed
- [ ] Manual testing completed

### Review Process

- A maintainer will review your PR and may request changes.
- Address review comments by pushing new commits (do not force-push during review).
- Once approved, a maintainer will merge your PR.

---

## Testing

### Unit Tests

Unit tests cover core logic without network or UI dependencies:

- Queue state transitions
- Retry policy and backoff calculations
- Duplicate handling decisions
- Destination model behaviour
- Account state management
- Upload session persistence
- MIME type detection
- File size formatting

Write unit tests for any new logic you add. Place tests in the `DriveDockTests/` directory, mirroring the main project structure.

### Integration Tests

Integration tests cover service interactions with mocked APIs:

- OAuth mock flow
- Google Drive API mock server responses
- Resumable upload success and interruption/recovery
- Rate limit handling
- Folder tree creation

### Manual QA Checklist

Before submitting a PR, verify these scenarios if your changes affect uploads, the queue, or accounts:

- [ ] Upload one small file successfully
- [ ] Upload one large file (>100 MB) with progress tracking
- [ ] Upload a folder with nested subfolders
- [ ] Pause and resume an upload
- [ ] Cancel an upload
- [ ] Retry a failed upload
- [ ] Disconnect and reconnect a Google account
- [ ] Switch between accounts
- [ ] Verify menu bar shows correct upload status
- [ ] Verify notifications appear on completion

---

## Reporting Bugs

Use the [Bug Report](https://github.com/sayuru-akash/drivedock/issues/new?template=bug_report.md) issue template. Include:

- **macOS version** (e.g., 14.5)
- **DriveDock version** (e.g., 1.0.0)
- **Mac model** (e.g., MacBook Pro M3)
- **Steps to reproduce** -- as specific as possible
- **Expected behaviour** -- what you expected to happen
- **Actual behaviour** -- what actually happened
- **Screenshots or screen recordings** -- if applicable
- **Console logs** -- if you can reproduce the issue, check Console.app for DriveDock logs

---

## Requesting Features

Use the [Feature Request](https://github.com/sayuru-akash/drivedock/issues/new?template=feature_request.md) issue template. Include:

- The problem you are trying to solve
- Your proposed solution
- Alternatives you have considered
- Any additional context or mockups

---

## Documentation

Good documentation is as important as good code. Contributions to documentation are welcome:

- Fix typos or unclear explanations in the README
- Add usage examples
- Improve code comments for complex logic
- Write guides for common workflows
- Update the changelog for notable changes

---

## License

By contributing to DriveDock, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

Thank you for contributing to DriveDock.
