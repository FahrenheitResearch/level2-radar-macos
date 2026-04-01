#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

VERSION="${VERSION:-0.1.0}"
APP_NAME="Level2 Radar"
APP_BUNDLE="${APP_NAME}.app"
ZIP_NAME="level2-radar-macos.zip"
DMG_NAME="level2-radar-macos.dmg"
DERIVED_DATA_PATH="${PWD}/build/catalyst-derived"
PRODUCT_PATH="${DERIVED_DATA_PATH}/Build/Products/Release-maccatalyst/${APP_BUNDLE}"

rm -rf "$DERIVED_DATA_PATH" "$APP_BUNDLE"
mkdir -p build

cd ios
xcodegen generate
xcodebuild \
  -project macdar.xcodeproj \
  -scheme macdar \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination 'generic/platform=macOS,variant=Mac Catalyst' \
  build \
  CODE_SIGNING_ALLOWED=NO
cd ..

cp -R "$PRODUCT_PATH" "$APP_BUNDLE"

if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')
  echo "Signing with: $IDENTITY"
  codesign --force --deep --options runtime -s "$IDENTITY" "$APP_BUNDLE"
else
  echo "No Developer ID identity found. Ad-hoc signing..."
  codesign --force --deep -s - "$APP_BUNDLE"
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
