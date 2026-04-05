#!/bin/bash
set -euo pipefail

APP_NAME="RunClaude"
BUNDLE_ID="com.caioborghi.RunClaude"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME..."

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Compile
xcrun swiftc \
  -sdk "$(xcrun --show-sdk-path -sdk macosx)" \
  -target arm64-apple-macosx14.0 \
  -framework AppKit -framework SwiftUI \
  -parse-as-library \
  -O \
  RunClaude/RunClaudeApp.swift \
  RunClaude/AppDelegate.swift \
  RunClaude/EyeState.swift \
  RunClaude/EyeAnimator.swift \
  RunClaude/EyeRenderer.swift \
  RunClaude/ServerClient.swift \
  RunClaude/PopoverView.swift \
  -o "$APP_DIR/Contents/MacOS/$APP_NAME"

# Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>RunClaude</string>
    <key>CFBundleExecutable</key>
    <string>RunClaude</string>
    <key>CFBundleIdentifier</key>
    <string>com.caioborghi.RunClaude</string>
    <key>CFBundleName</key>
    <string>RunClaude</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Built: $APP_DIR"
echo "Run with: open \"$APP_DIR\""
