#!/bin/bash
set -e

APP_NAME="Level2 Radar.app"
ZIP_NAME="level2-radar-macos.zip"
REPO="FahrenheitResearch/level2-radar-macos"

echo "Installing Level2 Radar..."

# Download latest release
TMPDIR=$(mktemp -d)
ZIP="$TMPDIR/$ZIP_NAME"
curl -sL "https://github.com/$REPO/releases/latest/download/$ZIP_NAME" -o "$ZIP"

# Unzip
cd "$TMPDIR"
unzip -q "$ZIP"

# Remove quarantine flag (prevents Gatekeeper "damaged" error)
xattr -cr "$APP_NAME"

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
