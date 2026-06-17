# Release Checklist

DriveDock distributes public macOS builds through GitHub Releases. The website download button points to the latest GitHub release, so a release must contain packaged macOS artifacts.

## Optional GitHub Secrets For Signed Releases

- `MACOS_CERTIFICATE_P12`: base64-encoded Developer ID Application `.p12`
- `MACOS_CERTIFICATE_PASSWORD`: password for the `.p12`
- `KEYCHAIN_PASSWORD`: temporary CI keychain password
- `DEVELOPMENT_TEAM`: Apple Developer team ID
- `DEVELOPER_ID_APPLICATION`: full signing identity, for example `Developer ID Application: Example, Inc. (TEAMID)`
- `APPLE_ID`: Apple ID used by notarization
- `APPLE_TEAM_ID`: Apple team ID used by notarization
- `APP_SPECIFIC_PASSWORD`: app-specific password for `notarytool`

If these secrets are present, the release workflow signs with Developer ID, submits to Apple notarization, staples the app, and publishes notarized artifacts.

If the secrets are missing, the workflow still publishes a DMG and zip using ad-hoc signing. Those builds are usable, but macOS Gatekeeper may require Control-click > Open on first launch. Users can also build from source with their own signing identity.

## Local Validation

```bash
xcodebuild -scheme DriveDock -configuration Debug test
scripts/package_release.sh 1.0.0
```

The local package command creates an ad-hoc signed DMG, zip, checksums, and release notes for inspection. Public releases should use the GitHub Actions release workflow; it upgrades the artifacts to Developer ID signed and notarized automatically when Apple secrets are configured.

## Publish

Create and push a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The `Release` workflow builds, tests, signs, notarizes, packages, and publishes the release asset.
