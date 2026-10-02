#!/usr/bin/env bash
set -euo pipefail

# Project root directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "==> Building AHK Dynamic Island (Release)..."
swift build -c release

APP_NAME="AHK Dynamic Island"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Packaging $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
cp "$PROJECT_DIR/.build/release/AHKDynamicIsland" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

# Copy AppIcon if available
if [[ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Code sign with Sandbox entitlements
echo "==> Code signing application..."
codesign --force --deep --sign - \
    --entitlements "$PROJECT_DIR/Resources/App.entitlements" \
    "$APP_BUNDLE"

echo "==> Verifying code signature..."
codesign --verify --deep --strict "$APP_BUNDLE"

echo "==> Successfully built: $APP_BUNDLE"
