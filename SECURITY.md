# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in DriveDock, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please email the maintainers directly. We will respond within 48 hours and work with you to address the issue.

## Security Design Decisions

DriveDock follows these security principles:

- **Keychain-only token storage** — OAuth tokens are stored exclusively in macOS Keychain, never in plain files or logs
- **No analytics or tracking** — DriveDock does not include any analytics, telemetry, or tracking code by default
- **Minimal permissions** — The app requests only the OAuth scopes necessary for its functionality
- **Local-first** — All data stays on your Mac. DriveDock communicates only with Google Drive APIs using your authorized account
- **Open source** — All code is publicly auditable

## Supported Versions

Security updates are provided for the latest release only.

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |
| Older   | No        |
