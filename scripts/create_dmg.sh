#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="AHK Dynamic Island"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="AHK Dynamic Island v0.6.1.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
STAGING_DIR="$BUILD_DIR/dmg_staging"
VOLUME_NAME="$APP_NAME"

echo "==> Preparing DMG packaging for $APP_NAME..."

if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "Error: $APP_BUNDLE does not exist. Run scripts/build_app.sh first."
    exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$STAGING_DIR" "$DMG_PATH" "${DMG_PATH}.sha256"
mkdir -p "$STAGING_DIR"

echo "==> Populating DMG staging contents..."
cp -R "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating compressed DMG: $DMG_PATH..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

echo "==> Cleaning up staging..."
rm -rf "$STAGING_DIR"

echo "==> Verifying DMG checksum and structure..."
hdiutil verify "$DMG_PATH"

echo "==> Generating SHA-256 checksum..."
shasum -a 256 "$DMG_PATH" > "${DMG_PATH}.sha256"

echo "==> Successfully created and verified production DMG: $DMG_PATH"
ls -lh "$DMG_PATH"
cat "${DMG_PATH}.sha256"
