#!/usr/bin/env bash
# release-unsigned.sh - build a Homebrew-distributed DMG with ad-hoc signing.
#
# Distribution is Homebrew-only: upload the DMG to a GitHub Release, then bump
# the cask in the separate blas0/homebrew-keydrop tap. No Sparkle, no R2, no
# Gumroad, and no Apple notarization are part of this flow.
#
# Usage:
#   ./scripts/release-unsigned.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
DIST_DIR="$PROJECT_ROOT/dist"
ARCHIVE_PATH="$BUILD_DIR/keyDrop.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_NAME="keyDrop"
SCHEME="keyDrop-Direct"
PROJECT="$PROJECT_ROOT/keyDrop.xcodeproj"

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) echo "[!] Unknown arg: $arg"; exit 1 ;;
    esac
done

run() {
    if $DRY_RUN; then
        echo "[dry-run] $*"
    else
        "$@"
    fi
}

echo "[*] keyDrop release builder (Homebrew / ad-hoc)"
echo "[*] Project: $PROJECT_ROOT"

VERSION=$(awk -F' = ' '/^MARKETING_VERSION/ {gsub(/[ \t]/, "", $2); print $2}' "$PROJECT_ROOT/Config/Version.xcconfig")
BUILD=$(awk -F' = ' '/^CURRENT_PROJECT_VERSION/ {gsub(/[ \t]/, "", $2); print $2}' "$PROJECT_ROOT/Config/Version.xcconfig")
[[ -n "$VERSION" && -n "$BUILD" ]] || { echo "[!] Couldn't parse version from Config/Version.xcconfig"; exit 1; }
echo "[*] Version: $VERSION ($BUILD)"

echo ""
echo "[0] Git pre-flight..."
if [[ -n "$(git -C "$PROJECT_ROOT" status --porcelain --untracked-files=no)" ]]; then
    echo "[!] Working tree dirty:"
    git -C "$PROJECT_ROOT" status --short --untracked-files=no
    echo "    Commit or stash before releasing."
    exit 1
fi
echo "    [+] Tracked working tree clean"

CURRENT_BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo "    [!] On branch '$CURRENT_BRANCH', not main."
    if ! $DRY_RUN; then
        read -p "    Continue? [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || { echo "    Aborted."; exit 1; }
    else
        echo "    [dry-run] Would ask before releasing from a non-main branch."
    fi
fi

if git -C "$PROJECT_ROOT" rev-parse "v$VERSION" >/dev/null 2>&1; then
    if $DRY_RUN; then
        echo "[dry-run] Tag v$VERSION already exists locally; a real release would require a version bump."
    else
        echo "[!] Tag v$VERSION already exists locally. Bump Config/Version.xcconfig."
        exit 1
    fi
fi

git -C "$PROJECT_ROOT" fetch --quiet --tags origin "$CURRENT_BRANCH" 2>/dev/null || true
LOCAL=$(git -C "$PROJECT_ROOT" rev-parse HEAD)
REMOTE=$(git -C "$PROJECT_ROOT" rev-parse "origin/$CURRENT_BRANCH" 2>/dev/null || echo "")
if [[ -n "$REMOTE" && "$LOCAL" != "$REMOTE" ]]; then
    echo "    [!] Local out of sync with origin/$CURRENT_BRANCH."
    if ! $DRY_RUN; then
        read -p "    Continue anyway? [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
    else
        echo "    [dry-run] Would ask before continuing with an out-of-sync branch."
    fi
fi
echo "[+] Git checks passed"

echo ""
echo "[1] Cleaning build dir..."
run rm -rf "$BUILD_DIR"
run mkdir -p "$BUILD_DIR" "$DIST_DIR"

echo "[2] Archiving (Release, ad-hoc signing)..."
run_archive() {
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -xcconfig "$PROJECT_ROOT/Config/Direct.xcconfig" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGNING_REQUIRED=YES \
        CODE_SIGNING_ALLOWED=YES \
        DEVELOPMENT_TEAM=""
}

if $DRY_RUN; then
    echo "[dry-run] xcodebuild archive (ad-hoc) ..."
elif command -v xcbeautify >/dev/null 2>&1; then
    set -o pipefail
    run_archive | xcbeautify
    set +o pipefail
else
    run_archive
fi

echo "[3] Extracting .app from archive..."
run mkdir -p "$EXPORT_PATH"
ARCHIVE_APP="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
if ! $DRY_RUN; then
    rm -rf "$APP_PATH"
    cp -R "$ARCHIVE_APP" "$APP_PATH"
fi

echo "[3b] Ad-hoc signing .app..."
run codesign --force --deep --options runtime --sign - "$APP_PATH"
if ! $DRY_RUN; then
    codesign --verify --deep --strict --verbose=2 "$APP_PATH" || {
        echo "[!] Codesign verify failed"
        exit 1
    }
fi
echo "[+] Signed (ad-hoc): $APP_PATH"

echo "[4] Building DMG..."
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
DMG_STAGING="$BUILD_DIR/dmg-staging"
run rm -f "$DMG_PATH"
run rm -rf "$DMG_STAGING"
run mkdir -p "$DMG_STAGING"
if ! $DRY_RUN; then
    cp -R "$APP_PATH" "$DMG_STAGING/"
    ln -s /Applications "$DMG_STAGING/Applications"
fi
run hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

run codesign --force --sign - "$DMG_PATH"
echo "[+] DMG: $DMG_PATH"

echo ""
echo "[+] Build pipeline complete."
echo ""
echo "Artifact: $DMG_PATH"
echo ""
echo "Next steps:"
echo ""
SHA256=""
if ! $DRY_RUN; then
    SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
    echo "  sha256: $SHA256"
fi
echo ""
echo "  git tag -a v$VERSION -m \"Release $VERSION\""
echo "  git push origin v$VERSION"
echo ""
echo "  gh release create v$VERSION \\"
echo "    \"$DMG_PATH\" \\"
echo "    --title \"v$VERSION\" \\"
echo "    --notes \"See CHANGELOG.md for details.\""
echo ""
echo "  # Bump the Homebrew tap cask (separate repo: blas0/homebrew-keydrop):"
echo "  cd \"\$TAP_REPO_ROOT\""
echo "  sed -i '' \"s/version \\\".*\\\"/version \\\"$VERSION\\\"/\" Casks/keydrop.rb"
if [[ -n "$SHA256" ]]; then
    echo "  sed -i '' \"s/sha256 \\\"[a-f0-9]*\\\"/sha256 \\\"$SHA256\\\"/\" Casks/keydrop.rb"
fi
echo "  git add Casks/keydrop.rb && git commit -m \"keyDrop $VERSION\" && git push"
echo ""
echo "Verification:"
echo "  codesign -dv --verbose=4 \"$APP_PATH\""
echo "  hdiutil verify \"$DMG_PATH\""
echo "  spctl --assess --type install \"$DMG_PATH\" # expected: rejected because ad-hoc builds are not notarized"
