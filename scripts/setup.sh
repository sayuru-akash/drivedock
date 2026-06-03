#!/bin/bash
# DriveDock Setup Script
# Run this after cloning to configure your OAuth credentials

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SECRETS_FILE="$PROJECT_DIR/Secrets.xcconfig"
INFO_PLIST="$PROJECT_DIR/DriveDock/Resources/Info.plist"

echo "🔧 DriveDock Setup"
echo ""

# Check if Secrets.xcconfig exists
if [ ! -f "$SECRETS_FILE" ]; then
    echo "📝 Creating Secrets.xcconfig from template..."
    cat > "$SECRETS_FILE" << 'EOF'
// DriveDock Build Secrets
// DO NOT COMMIT THIS FILE
// Fill in your Google OAuth credentials below

GOOGLE_CLIENT_ID = YOUR_CLIENT_ID_HERE
GOOGLE_CLIENT_SECRET = YOUR_CLIENT_SECRET_HERE
EOF
    echo "✅ Created Secrets.xcconfig"
    echo ""
    echo "⚠️  Please edit $SECRETS_FILE with your Google OAuth credentials"
    echo "   Then run this script again."
    exit 0
fi

# Read credentials from Secrets.xcconfig
CLIENT_ID=$(grep "GOOGLE_CLIENT_ID" "$SECRETS_FILE" | sed 's/.*= //' | tr -d ' ')
CLIENT_SECRET=$(grep "GOOGLE_CLIENT_SECRET" "$SECRETS_FILE" | sed 's/.*= //' | tr -d ' ')

if [ "$CLIENT_ID" = "YOUR_CLIENT_ID_HERE" ] || [ -z "$CLIENT_ID" ]; then
    echo "❌ Please set GOOGLE_CLIENT_ID in Secrets.xcconfig"
    exit 1
fi

if [ "$CLIENT_SECRET" = "YOUR_CLIENT_SECRET_HERE" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "❌ Please set GOOGLE_CLIENT_SECRET in Secrets.xcconfig"
    exit 1
fi

# Extract the reversed client ID for URL scheme
URL_SCHEME=$(echo "$CLIENT_ID" | sed 's/\.apps\.googleusercontent\.com//' | tr '.' '\n' | tac | tr '\n' '.' | sed 's/\.$//')
URL_SCHEME="com.googleusercontent.apps.${URL_SCHEME}"

echo "📝 Updating Info.plist with your credentials..."

# Update Info.plist
/usr/libexec/PlistBuddy -c "Set :GOOGLE_CLIENT_ID $CLIENT_ID" "$INFO_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :GOOGLE_CLIENT_ID string $CLIENT_ID" "$INFO_PLIST"

/usr/libexec/PlistBuddy -c "Set :GOOGLE_CLIENT_SECRET $CLIENT_SECRET" "$INFO_PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :GOOGLE_CLIENT_SECRET string $CLIENT_SECRET" "$INFO_PLIST"

/usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 $URL_SCHEME" "$INFO_PLIST" 2>/dev/null || \
echo "⚠️  Could not update URL scheme automatically. Please set it manually."

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Your configuration:"
echo "   Client ID: $CLIENT_ID"
echo "   URL Scheme: $URL_SCHEME"
echo ""
echo "🚀 Open DriveDock.xcodeproj in Xcode and press Cmd+R to build and run."
