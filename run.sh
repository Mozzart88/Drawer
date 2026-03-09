#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building..."
swift build -c release 2>&1

BINARY=".build/release/Drawer"
APP_DIR="Drawer.app/Contents"
MACOS_DIR="$APP_DIR/MacOS"
RES_DIR="$APP_DIR/Resources"

echo "Creating app bundle..."
rm -rf Drawer.app
mkdir -p "$MACOS_DIR"
mkdir -p "$RES_DIR"

cp "$BINARY" "$MACOS_DIR/Drawer"

cat > "$APP_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Drawer</string>
    <key>CFBundleIdentifier</key>
    <string>com.drawer.app</string>
    <key>CFBundleName</key>
    <string>Drawer</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Launching Drawer.app..."
open Drawer.app
