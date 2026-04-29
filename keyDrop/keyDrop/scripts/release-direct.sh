#!/bin/bash
# release-direct.sh
# Build, sign, notarize, and publish Direct distribution with Sparkle updates.
#
# Usage: ./scripts/release-direct.sh [--skip-notarize] [--skip-upload]
#
# Prerequisites:
# - Xcode command line tools
# - Developer ID Application certificate in Keychain
# - App-specific password in Keychain for notarization
# - Sparkle EdDSA key generated (see generate-sparkle-key.sh)
# - AWS CLI installed (brew install awscli)
# - R2 credentials in scripts/.env.release

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
RELEASE_DIR="$PROJECT_ROOT/Release"
ARCHIVE_PATH="$BUILD_DIR/keyDrop.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_NAME="keyDrop"
BUNDLE_ID="com.neurix.keydrop"

# R2 configuration
R2_BASE_URL="https://pub-6917a81ec60742c685a6b5517bf87869.r2.dev"
APPCAST_PATH="$RELEASE_DIR/appcast.xml"

# Parse arguments
SKIP_NOTARIZE=false
SKIP_UPLOAD=false
for arg in "$@"; do
    case $arg in
        --skip-notarize)
            SKIP_NOTARIZE=true
            ;;
        --skip-upload)
            SKIP_UPLOAD=true
            ;;
    esac
done

echo "[*] keyDrop Direct Distribution Builder"
echo "[*] Project root: $PROJECT_ROOT"
echo ""

# Load R2 credentials
if [[ "$SKIP_UPLOAD" == "false" ]]; then
    if [[ -f "$SCRIPT_DIR/.env.release" ]]; then
        source "$SCRIPT_DIR/.env.release"
        R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
        echo "[*] R2 credentials loaded"
    else
        echo "[!] Warning: scripts/.env.release not found"
        echo "[!] Uploads will be skipped. Copy .env.release.example to .env.release"
        SKIP_UPLOAD=true
    fi
fi

# Read version from xcconfig
VERSION=$(grep "MARKETING_VERSION" "$PROJECT_ROOT/Config/Version.xcconfig" | cut -d= -f2 | tr -d ' ')
BUILD=$(grep "CURRENT_PROJECT_VERSION" "$PROJECT_ROOT/Config/Version.xcconfig" | cut -d= -f2 | tr -d ' ')
echo "[*] Version: $VERSION ($BUILD)"

# ============================================================
# Git Pre-Flight Validation
# ============================================================
echo ""
echo "[0] Git pre-flight checks..."

# [0.1] Check for clean working tree
if [[ -n "$(git -C "$PROJECT_ROOT" status --porcelain)" ]]; then
    echo "[!] ERROR: Working tree has uncommitted changes."
    echo ""
    echo "    Uncommitted files:"
    git -C "$PROJECT_ROOT" status --short
    echo ""
    echo "    Commit or stash changes before releasing."
    exit 1
fi
echo "    [+] Working tree is clean"

# [0.2] Check current branch
CURRENT_BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current)
echo "    [*] Current branch: $CURRENT_BRANCH"

if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo "    [!] Warning: Releasing from branch '$CURRENT_BRANCH' (not main)"
    read -p "    Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "    Aborted."
        exit 1
    fi
fi

# [0.3] Check if local is up-to-date with remote
git -C "$PROJECT_ROOT" fetch --quiet origin "$CURRENT_BRANCH" 2>/dev/null || true
LOCAL_COMMIT=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
REMOTE_COMMIT=$(git -C "$PROJECT_ROOT" rev-parse "origin/$CURRENT_BRANCH" 2>/dev/null || echo "")

if [[ -n "$REMOTE_COMMIT" && "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]]; then
    BEHIND=$(git -C "$PROJECT_ROOT" rev-list --count HEAD..origin/"$CURRENT_BRANCH" 2>/dev/null || echo "0")
    AHEAD=$(git -C "$PROJECT_ROOT" rev-list --count origin/"$CURRENT_BRANCH"..HEAD 2>/dev/null || echo "0")
    if [[ "$BEHIND" -gt 0 ]]; then
        echo "    [!] Warning: Local is $BEHIND commit(s) behind origin/$CURRENT_BRANCH"
        echo "    Run: git pull origin $CURRENT_BRANCH"
        read -p "    Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "    Aborted."
            exit 1
        fi
    fi
    if [[ "$AHEAD" -gt 0 ]]; then
        echo "    [*] Local is $AHEAD commit(s) ahead of origin/$CURRENT_BRANCH"
    fi
else
    echo "    [+] Local is up-to-date with remote"
fi

echo "[+] Git pre-flight checks passed"
echo ""

# Clean build directory
echo "[1] Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$RELEASE_DIR"

# Archive
echo "[2] Archiving for Direct distribution..."

# Stream xcodebuild output through xcbeautify when available; otherwise raw.
# Using a function avoids duplicating the xcodebuild invocation and the bug
# where `cmd | xcbeautify || cmd` fell back silently when xcbeautify was missing.
run_archive() {
    xcodebuild archive \
        -project "$PROJECT_ROOT/keyDrop.xcodeproj" \
        -scheme keyDrop-Direct \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -xcconfig "$PROJECT_ROOT/Config/Direct.xcconfig" \
        KEYDROP_DISTRIBUTION_CHANNEL=DIRECT \
        CODE_SIGN_STYLE=Manual \
        "CODE_SIGN_IDENTITY=Developer ID Application" \
        "PROVISIONING_PROFILE_SPECIFIER=" \
        -allowProvisioningUpdates
}

if command -v xcbeautify >/dev/null 2>&1; then
    set -o pipefail
    run_archive | xcbeautify
    set +o pipefail
else
    run_archive
fi

# Export
echo "[3] Exporting signed app..."
cat > "$BUILD_DIR/ExportOptions.plist" << 'EXPORTPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>83698ZGFJP</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EXPORTPLIST

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    -allowProvisioningUpdates

APP_PATH="$EXPORT_PATH/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "[!] Export failed - app not found at $APP_PATH"
    exit 1
fi

echo "[+] App exported to: $APP_PATH"

# Notarize
if [[ "$SKIP_NOTARIZE" == "false" ]]; then
    echo "[4] Notarizing..."

    # Create zip for notarization
    NOTARIZE_ZIP="$BUILD_DIR/$APP_NAME-notarize.zip"
    ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"

    # Submit for notarization
    # Requires: xcrun notarytool store-credentials "AC_PASSWORD" (one-time setup)
    xcrun notarytool submit "$NOTARIZE_ZIP" \
        --keychain-profile "AC_PASSWORD" \
        --wait

    # Staple the notarization ticket
    xcrun stapler staple "$APP_PATH"

    echo "[+] Notarization complete and stapled"
else
    echo "[4] Skipping notarization (--skip-notarize)"
fi

# Create distribution DMG
echo "[5] Creating distribution DMG..."
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"

# Remove old DMG if exists
rm -f "$DMG_PATH"

# Create DMG with Applications symlink
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

echo "[+] DMG created: $DMG_PATH"

# Create ZIP for Sparkle
echo "[6] Creating Sparkle update archive..."
ZIP_NAME="$APP_NAME-$VERSION.zip"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "[+] ZIP created: $ZIP_PATH"

# Sign for Sparkle
echo "[7] Signing for Sparkle updates..."

# Find sign_update in SPM artifacts (preferred) or DerivedData
SPARKLE_SIGN=""
DERIVED_DATA=$(dirname "$(dirname "$(xcodebuild -project "$PROJECT_ROOT/keyDrop.xcodeproj" -showBuildSettings 2>/dev/null | grep -m1 'BUILD_DIR' | awk '{print $3}')")")
if [[ -d "$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin" ]]; then
    SPARKLE_SIGN="$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
fi

# Fallback: search DerivedData
if [[ ! -x "$SPARKLE_SIGN" ]]; then
    SPARKLE_SIGN=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -type f -perm +111 2>/dev/null | head -1)
fi

ED_SIGNATURE=""
LENGTH=""

# EdDSA key for Sparkle signing (raw base64 seed format)
SPARKLE_KEY_FILE="$HOME/.keydrop-keys/sparkle_eddsa_seed.txt"

if [[ -n "$SPARKLE_SIGN" && -x "$SPARKLE_SIGN" ]]; then
    if [[ -f "$SPARKLE_KEY_FILE" ]]; then
        # Sign the zip with EdDSA key file
        SIGNATURE_OUTPUT=$("$SPARKLE_SIGN" --ed-key-file "$SPARKLE_KEY_FILE" "$ZIP_PATH" 2>&1)
        echo "[+] Sparkle signature generated"

        # Extract values for appcast.xml
        ED_SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | grep "edSignature=" | cut -d'"' -f2)
        LENGTH=$(stat -f%z "$ZIP_PATH")
    else
        echo "[!] Sparkle EdDSA key not found at $SPARKLE_KEY_FILE"
        echo "[!] ZIP created but not signed for Sparkle."
    fi
else
    echo "[!] Sparkle sign_update not found. Build project first."
    echo "[!] ZIP created but not signed for Sparkle."
fi

# Generate/update appcast.xml
echo "[8] Updating appcast.xml..."

PUB_DATE=$(date -R)
NEW_ITEM=$(cat << APPCAST_ITEM
        <item>
            <title>Version $VERSION</title>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>$BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <enclosure url="$R2_BASE_URL/releases/$ZIP_NAME"
                       sparkle:edSignature="$ED_SIGNATURE"
                       length="$LENGTH"
                       type="application/octet-stream"/>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
        </item>
APPCAST_ITEM
)

if [[ -f "$APPCAST_PATH" ]]; then
    # Insert new item after the <language> line (before first existing <item>)
    # Write new item to temp file to avoid awk newline issues
    NEW_ITEM_FILE="$BUILD_DIR/new_item.xml"
    echo "$NEW_ITEM" > "$NEW_ITEM_FILE"

    awk '
        /<language>.*<\/language>/ {
            print
            while ((getline line < "'"$NEW_ITEM_FILE"'") > 0) {
                print line
            }
            next
        }
        { print }
    ' "$APPCAST_PATH" > "$APPCAST_PATH.tmp"
    mv "$APPCAST_PATH.tmp" "$APPCAST_PATH"
    rm -f "$NEW_ITEM_FILE"
    echo "[+] Updated existing appcast.xml"
else
    # Create new appcast.xml
    cat > "$APPCAST_PATH" << APPCAST_HEADER
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>keyDrop Updates</title>
        <link>$R2_BASE_URL/appcast.xml</link>
        <description>Updates for keyDrop</description>
        <language>en</language>
$NEW_ITEM
    </channel>
</rss>
APPCAST_HEADER
    echo "[+] Created new appcast.xml"
fi

# Upload to R2
if [[ "$SKIP_UPLOAD" == "false" && -n "$R2_ACCESS_KEY_ID" ]]; then
    echo "[9] Uploading to Cloudflare R2..."

    # Configure AWS CLI for R2
    export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
    export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
    export AWS_DEFAULT_REGION="auto"

    # Upload ZIP (Sparkle updates)
    echo "    Uploading $ZIP_NAME..."
    aws s3 cp "$ZIP_PATH" "s3://$R2_BUCKET/releases/$ZIP_NAME" \
        --endpoint-url "$R2_ENDPOINT" \
        --content-type "application/zip"

    # Upload DMG (manual downloads / Gumroad versioned URL)
    echo "    Uploading $DMG_NAME..."
    aws s3 cp "$DMG_PATH" "s3://$R2_BUCKET/releases/$DMG_NAME" \
        --endpoint-url "$R2_ENDPOINT" \
        --content-type "application/x-apple-diskimage"

    # Upload DMG as keyDrop-latest.dmg (stable URL for Gumroad - never needs to change).
    # Short cache so new buyers always get the freshest installer.
    echo "    Uploading keyDrop-latest.dmg (Gumroad stable pointer)..."
    aws s3 cp "$DMG_PATH" "s3://$R2_BUCKET/releases/keyDrop-latest.dmg" \
        --endpoint-url "$R2_ENDPOINT" \
        --content-type "application/x-apple-diskimage" \
        --cache-control "max-age=300"

    # Upload appcast.xml
    echo "    Uploading appcast.xml..."
    aws s3 cp "$APPCAST_PATH" "s3://$R2_BUCKET/appcast.xml" \
        --endpoint-url "$R2_ENDPOINT" \
        --content-type "application/xml" \
        --cache-control "max-age=300"

    echo "[+] All files uploaded to R2"
    echo ""
    echo "[*] Published URLs:"
    echo "    Appcast:      $R2_BASE_URL/appcast.xml"
    echo "    ZIP:          $R2_BASE_URL/releases/$ZIP_NAME"
    echo "    DMG (versioned): $R2_BASE_URL/releases/$DMG_NAME"
    echo "    DMG (latest):    $R2_BASE_URL/releases/keyDrop-latest.dmg  <- Gumroad uses this"
else
    echo "[9] Skipping upload (--skip-upload or missing credentials)"
    echo ""
    echo "[*] Appcast entry to add manually:"
    echo "================================================"
    echo "$NEW_ITEM"
    echo "================================================"
    echo ""
    echo "Manual upload steps:"
    echo "  1. Upload $ZIP_NAME to $R2_BASE_URL/releases/"
    echo "  2. Upload appcast.xml to $R2_BASE_URL/appcast.xml"
    echo "  3. Upload $DMG_NAME to $R2_BASE_URL/releases/"
    echo "  4. Upload $DMG_NAME to $R2_BASE_URL/releases/keyDrop-latest.dmg (Gumroad stable URL)"
fi

echo ""
echo "[+] Release build complete!"
echo ""
echo "Artifacts in $RELEASE_DIR:"
ls -lh "$RELEASE_DIR"
