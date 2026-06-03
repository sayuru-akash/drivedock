# Contributing to DriveDock

Thank you for your interest in contributing to DriveDock! This document provides guidelines and instructions for contributing.

## Getting Started

### Prerequisites

- macOS 14 Sonoma or later
- Xcode 15.0 or later
- A Google Cloud project with Drive API enabled

### Setting Up Google OAuth for Development

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project
3. Enable the Google Drive API
4. Configure the OAuth consent screen (External for testing)
5. Create OAuth 2.0 credentials (Desktop application type)
6. Add the client ID to your local configuration

### Building the Project

1. Clone the repository
2. Open `DriveDock.xcodeproj` in Xcode
3. Select the `DriveDock` scheme
4. Build and run (Cmd+R)

## Code Style

- Follow Swift API Design Guidelines
- Use SwiftUI for all new views unless AppKit is genuinely required
- Prefer `async/await` over completion handlers
- Use `@Observable` (macOS 14+) over `ObservableObject` where possible
- Keep views small and composable
- Write documentation comments for public APIs

## Pull Request Process

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Write or update tests as needed
5. Ensure the project builds without warnings
6. Submit a pull request with a clear description

## Reporting Bugs

Use the GitHub issue tracker. Include:

- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
