#!/bin/bash
set -euo pipefail

APP_NAME="ClaudeUsageMenuBar"
BUILD_CONFIG="release"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

swift build -c "$BUILD_CONFIG"

BIN_PATH=".build/$BUILD_CONFIG/$APP_NAME"
APP_BUNDLE="$APP_NAME.app"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [ -f "Assets/AppIcon.icns" ]; then
    cp "Assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.kelvinlee97.claudeusagemenubar</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "Built $APP_BUNDLE"
echo "Move it to /Applications, then Spotlight/Finder can find and launch it:"
echo "  mv \"$APP_BUNDLE\" /Applications/"
