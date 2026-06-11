# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in DriveDock, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please email the maintainers directly. We will respond within 48 hours and work with you to address the issue.

## Security Design Decisions

DriveDock follows these security principles:

- **Keychain-only token storage** -- OAuth tokens are stored exclusively in macOS Keychain, never in plain files, logs, or databases
- **Biometric protection** -- Keychain tokens can optionally be protected with Touch ID or Apple Watch via `SecAccessControlCreateWithFlags(.biometryCurrentSet)`
- **Security-scoped bookmarks** -- Dragged files are accessed through security-scoped bookmarks for proper sandbox compliance
- **No analytics or tracking** -- DriveDock does not include any analytics, telemetry, or tracking code
- **Minimal permissions** -- The app requests only the OAuth scopes necessary for its functionality (`drive.file`, `drive.readonly`, `userinfo.email`, `userinfo.profile`)
- **Local-first** -- All data stays on your Mac as JSON files in `~/Library/Application Support/DriveDock/`. DriveDock communicates only with Google Drive APIs using your authorized account
- **No external dependencies** -- Built entirely against native Apple frameworks (Foundation, SwiftUI, Security, UserNotifications). No third-party networking or persistence libraries
- **Secrets not committed** -- OAuth client ID and secret are injected via `Secrets.xcconfig` or build settings, never hardcoded in source
- **Open source** -- All code is publicly auditable

## Token Storage Detail

OAuth tokens are stored using macOS Keychain Services (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`). Each account's tokens are keyed by `token_<accountID>`. Tokens are never written to:

- Disk files
- JSON persistence
- SQLite databases
- Console logs
- UserDefaults

When an account is disconnected, all associated tokens are deleted from Keychain.

## Supported Versions

Security updates are provided for the latest release only.

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |
| Older   | No        |
