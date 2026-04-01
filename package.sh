#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

VERSION="${VERSION:-0.1.0}"
APP_NAME="Level2 Radar"
APP_BUNDLE="${APP_NAME}.app"
EXECUTABLE_NAME="Level2Radar"
BUNDLE_ID="com.fahrenheitresearch.level2radar"
ZIP_NAME="level2-radar-macos.zip"
DMG_NAME="level2-radar-macos.dmg"
ENTITLEMENTS_PLIST="/tmp/level2-radar-entitlements.plist"

# Build first
./build.sh

rm -rf "$APP_BUNDLE"

# Create .app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp build/macdar "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

# Copy metallib if it exists
if [ -f build/default.metallib ]; then
    cp build/default.metallib "$APP_BUNDLE/Contents/MacOS/default.metallib"
fi

# Copy shader sources as fallback (for runtime compilation)
mkdir -p "$APP_BUNDLE/Contents/Resources/shaders"
cp src/metal/metal_common.h "$APP_BUNDLE/Contents/Resources/shaders/"
cp src/metal/renderer.metal "$APP_BUNDLE/Contents/Resources/shaders/"
cp src/metal/volume3d.metal "$APP_BUNDLE/Contents/Resources/shaders/"
cp src/metal/gpu_pipeline.metal "$APP_BUNDLE/Contents/Resources/shaders/"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

cat > "$ENTITLEMENTS_PLIST" <<'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
ENT

IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')
if [ -z "$IDENTITY" ]; then
    IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)"/\1/')
fi

if [ -z "$IDENTITY" ]; then
    echo "No signing identity found. Ad-hoc signing..."
    codesign --force --deep -s - "$APP_BUNDLE"
else
    echo "Signing with: $IDENTITY"
    codesign --force --deep --options runtime \
        --entitlements "$ENTITLEMENTS_PLIST" \
        -s "$IDENTITY" "$APP_BUNDLE"
fi

if xcrun notarytool history --keychain-profile "level2-radar-macos" &>/dev/null; then
    echo ""
    echo "Submitting for notarization..."
    ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"
    xcrun notarytool submit "$ZIP_NAME" --keychain-profile "level2-radar-macos" --wait
    echo "Stapling notarization ticket..."
    xcrun stapler staple "$APP_BUNDLE"
else
    echo ""
    echo "Skipping notarization (no keychain profile 'level2-radar-macos' found)."
fi

rm -f "$ZIP_NAME" "$DMG_NAME"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"

DMG_STAGING=$(mktemp -d "/tmp/level2-radar-dmg.XXXXXX")
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_NAME"
rm -rf "$DMG_STAGING"

echo ""
echo "Packaged: $APP_BUNDLE"
echo "Distribution ZIP: $ZIP_NAME ($(du -h "$ZIP_NAME" | cut -f1))"
echo "Distribution DMG: $DMG_NAME ($(du -h "$DMG_NAME" | cut -f1))"
