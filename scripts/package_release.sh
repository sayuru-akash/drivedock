#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="DriveDock"
CONFIGURATION="Release"
APP_NAME="DriveDock"
BUILD_ROOT="$ROOT_DIR/build/release"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
ARTIFACTS_DIR="$BUILD_ROOT/artifacts"

cd "$ROOT_DIR"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: scripts/package_release.sh [version]

Builds DriveDock for release and writes:
  build/release/artifacts/DriveDock-<version>-macOS.dmg
  build/release/artifacts/DriveDock-<version>-macOS.dmg.sha256
  build/release/artifacts/DriveDock-<version>-macOS.zip
  build/release/artifacts/DriveDock-<version>-macOS.zip.sha256
  build/release/artifacts/RELEASE_NOTES.md

Environment:
  SIGN_FOR_RELEASE=1             Require Developer ID signing inputs.
  NOTARIZE=1                     Submit to Apple notarization and staple.
  DEVELOPMENT_TEAM               Apple Developer team ID.
  DEVELOPER_ID_APPLICATION       Full Developer ID Application signing identity.
  APPLE_ID                       Apple ID for notarytool.
  APPLE_TEAM_ID                  Apple team ID for notarytool.
  APP_SPECIFIC_PASSWORD          App-specific password for notarytool.
USAGE
  exit 0
fi

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(
    xcodebuild -project DriveDock.xcodeproj -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings \
      | awk -F'= ' '/MARKETING_VERSION =/{print $2; exit}'
  )"
fi

if [[ -z "$VERSION" ]]; then
  echo "Could not determine MARKETING_VERSION." >&2
  exit 1
fi

rm -rf "$BUILD_ROOT"
mkdir -p "$ARTIFACTS_DIR"

BUILD_ARGS=(
  -project DriveDock.xcodeproj
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA"
  -destination "generic/platform=macOS"
  ARCHS="arm64 x86_64"
  ONLY_ACTIVE_ARCH=NO
  MARKETING_VERSION="$VERSION"
)

if [[ "${SIGN_FOR_RELEASE:-0}" == "1" ]]; then
  : "${DEVELOPMENT_TEAM:?DEVELOPMENT_TEAM is required when SIGN_FOR_RELEASE=1}"
  : "${DEVELOPER_ID_APPLICATION:?DEVELOPER_ID_APPLICATION is required when SIGN_FOR_RELEASE=1}"
  BUILD_ARGS+=(
    CODE_SIGN_STYLE=Manual
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
    CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION"
    OTHER_CODE_SIGN_FLAGS="--timestamp"
  )
else
  BUILD_ARGS+=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY=-
  )
fi

xcodebuild clean build "${BUILD_ARGS[@]}"

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle was not produced at $APP_PATH" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

if [[ "${SIGN_FOR_RELEASE:-0}" == "1" ]]; then
  ENTITLEMENTS_PATH="$BUILD_ROOT/entitlements.plist"
  codesign -d --entitlements :- "$APP_PATH" > "$ENTITLEMENTS_PATH"
  if /usr/bin/grep -q "com.apple.security.get-task-allow" "$ENTITLEMENTS_PATH"; then
    echo "Release-signed app contains get-task-allow; refusing to package for production." >&2
    exit 1
  fi
fi

ZIP_PATH="$ARTIFACTS_DIR/$APP_NAME-$VERSION-macOS.zip"
ZIP_CHECKSUM_PATH="$ZIP_PATH.sha256"
DMG_PATH="$ARTIFACTS_DIR/$APP_NAME-$VERSION-macOS.dmg"
DMG_CHECKSUM_PATH="$DMG_PATH.sha256"
DMG_ROOT="$BUILD_ROOT/dmgroot"
RELEASE_NOTES_PATH="$ARTIFACTS_DIR/RELEASE_NOTES.md"
SIGNING_LABEL="Unsigned/ad-hoc signed"
INSTALL_NOTE="Because this build is not Apple notarized, macOS Gatekeeper may require Control-click > Open on first launch. You can also build from source with your own local signing identity."

if [[ "${SIGN_FOR_RELEASE:-0}" == "1" ]]; then
  SIGNING_LABEL="Developer ID signed"
  INSTALL_NOTE="This build is Developer ID signed."
fi

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  : "${APPLE_ID:?APPLE_ID is required when NOTARIZE=1}"
  : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required when NOTARIZE=1}"
  : "${APP_SPECIFIC_PASSWORD:?APP_SPECIFIC_PASSWORD is required when NOTARIZE=1}"

  /usr/bin/ditto -c -k --keepParent --sequesterRsrc "$APP_PATH" "$ZIP_PATH"
  xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --wait
  xcrun stapler staple "$APP_PATH"
  SIGNING_LABEL="Developer ID signed and notarized"
  INSTALL_NOTE="This build is Developer ID signed, Apple notarized, and stapled."
  rm -f "$ZIP_PATH"
fi

mkdir -p "$DMG_ROOT"
cp -R "$APP_PATH" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
cat > "$DMG_ROOT/Install DriveDock.txt" <<EOF
DriveDock $VERSION

Install:
1. Drag DriveDock.app to Applications.
2. Open DriveDock from Applications.

$INSTALL_NOTE

Source code:
https://github.com/sayuru-akash/drivedock
EOF

/usr/bin/ditto -c -k --keepParent --sequesterRsrc "$APP_PATH" "$ZIP_PATH"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

/usr/bin/shasum -a 256 "$ZIP_PATH" > "$ZIP_CHECKSUM_PATH"
/usr/bin/shasum -a 256 "$DMG_PATH" > "$DMG_CHECKSUM_PATH"

cat > "$RELEASE_NOTES_PATH" <<EOF
# DriveDock $VERSION

DriveDock is a native macOS uploader for Google Drive. This release includes a drag-to-Applications DMG and a zipped app bundle.

## Downloads

- \`$APP_NAME-$VERSION-macOS.dmg\`: recommended installer. Open it, drag \`DriveDock.app\` to Applications, then launch the app.
- \`$APP_NAME-$VERSION-macOS.zip\`: plain app bundle archive for users who prefer zip downloads.
- \`*.sha256\`: checksums for verifying downloads.

## Signing

$SIGNING_LABEL.

$INSTALL_NOTE

## Verify

\`\`\`bash
shasum -a 256 -c "$APP_NAME-$VERSION-macOS.dmg.sha256"
shasum -a 256 -c "$APP_NAME-$VERSION-macOS.zip.sha256"
\`\`\`

## Build From Source

Users who prefer their own local signing can clone the repo, configure Google OAuth credentials, and build in Xcode or run:

\`\`\`bash
xcodebuild -scheme DriveDock -configuration Release build
\`\`\`
EOF

echo "Created $ZIP_PATH"
cat "$ZIP_CHECKSUM_PATH"
echo "Created $DMG_PATH"
cat "$DMG_CHECKSUM_PATH"
