#!/bin/bash
set -euo pipefail

APP_NAME="Level2 Radar.app"
DMG_NAME="level2-radar-macos.dmg"
REPO="FahrenheitResearch/level2-radar-macos"

echo "Installing Level2 Radar..."

# Download latest release DMG
TMPDIR=$(mktemp -d)
DMG="$TMPDIR/$DMG_NAME"
curl -sL "https://github.com/$REPO/releases/latest/download/$DMG_NAME" -o "$DMG"

# Mount DMG and copy app out
MOUNT_POINT="$TMPDIR/mount"
mkdir -p "$MOUNT_POINT"
hdiutil attach "$DMG" -mountpoint "$MOUNT_POINT" -nobrowse -quiet
cp -R "$MOUNT_POINT/$APP_NAME" "$TMPDIR/$APP_NAME"
hdiutil detach "$MOUNT_POINT" -quiet

# Move to Applications
if [ -d "/Applications/$APP_NAME" ]; then
    echo "Removing old version..."
    rm -rf "/Applications/$APP_NAME"
fi
mv "$APP_NAME" /Applications/

# Cleanup
rm -rf "$TMPDIR"

echo ""
echo "Installed to /Applications/$APP_NAME"
echo "Opening Level2 Radar..."
open "/Applications/$APP_NAME"
