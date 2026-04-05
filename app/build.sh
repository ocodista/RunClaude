#!/bin/bash
set -euo pipefail

APP_NAME="Claude Eyes"
BUNDLE_ID="com.caioborghi.ClaudeEyes"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

echo "Building Claude Eyes..."

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
  ClaudeEyes/ClaudeEyesApp.swift \
  ClaudeEyes/AppDelegate.swift \
  ClaudeEyes/EyeState.swift \
  ClaudeEyes/EyeAnimator.swift \
  ClaudeEyes/EyeRenderer.swift \
  ClaudeEyes/ServerClient.swift \
  ClaudeEyes/PopoverView.swift \
  -o "$APP_DIR/Contents/MacOS/ClaudeEyes"

# Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Claude Eyes</string>
    <key>CFBundleExecutable</key>
    <string>ClaudeEyes</string>
    <key>CFBundleIdentifier</key>
    <string>com.caioborghi.ClaudeEyes</string>
    <key>CFBundleName</key>
    <string>Claude Eyes</string>
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
