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

CERT_NAME="ClaudeUsageMenuBar Local Signing"

if ! security find-certificate -c "$CERT_NAME" -p >/dev/null 2>&1; then
    echo "Creating a local self-signed signing certificate (one-time; you may be prompted to trust it)..."
    CERT_DIR="$(mktemp -d)"
    trap 'rm -rf "$CERT_DIR"' EXIT

    cat > "$CERT_DIR/cert.conf" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $CERT_NAME

[v3_req]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

    openssl req -x509 -newkey rsa:2048 -keyout "$CERT_DIR/key.pem" -out "$CERT_DIR/cert.pem" \
        -days 3650 -nodes -config "$CERT_DIR/cert.conf" -extensions v3_req >/dev/null 2>&1
    P12_PASS="cumb-local-signing"
    openssl pkcs12 -export -out "$CERT_DIR/cert.p12" -inkey "$CERT_DIR/key.pem" -in "$CERT_DIR/cert.pem" \
        -passout "pass:$P12_PASS" -legacy >/dev/null 2>&1 || \
    openssl pkcs12 -export -out "$CERT_DIR/cert.p12" -inkey "$CERT_DIR/key.pem" -in "$CERT_DIR/cert.pem" \
        -passout "pass:$P12_PASS" >/dev/null 2>&1

    security import "$CERT_DIR/cert.p12" -k ~/Library/Keychains/login.keychain-db -P "$P12_PASS" -T /usr/bin/codesign
    security add-trusted-cert -r trustAsRoot -p codeSign -k ~/Library/Keychains/login.keychain-db "$CERT_DIR/cert.pem" 2>/dev/null || \
        echo "Note: certificate trust could not be set automatically; you may see one more keychain prompt."

    rm -rf "$CERT_DIR"
    trap - EXIT
fi

codesign --force --deep --sign "$CERT_NAME" "$APP_BUNDLE" >/dev/null 2>&1 || \
    codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "Built $APP_BUNDLE"
echo "Move it to /Applications, then Spotlight/Finder can find and launch it:"
echo "  mv \"$APP_BUNDLE\" /Applications/"
