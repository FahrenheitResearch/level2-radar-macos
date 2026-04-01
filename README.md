# Level2 Radar for macOS

Mac Catalyst build of the iPhone-first Level II radar app. SwiftUI shell, Metal rendering path, live NEXRAD Level II data, and the same app surface as the iOS build running on macOS.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue) ![iOS](https://img.shields.io/badge/iOS-17%2B-blue) ![Metal](https://img.shields.io/badge/GPU-Metal-orange)

## Features

- Live NEXRAD Level 2 ingest from AWS (no API key needed)
- Single-site and national mosaic rendering
- 7 radar products: REF, VEL, SW, ZDR, CC, KDP, PHI
- Tilt browsing across all elevation angles
- 3D volume rendering and cross-sections (macOS)
- Storm-relative velocity mode
- Live NWS warning polygon overlays
- Historic event playback with frame scrubbing
- GR/RadarScope-style color table import
- Pinch-to-zoom, pan, click-to-select station

## Install (macOS)

Paste this in Terminal:

```bash
curl -sL https://raw.githubusercontent.com/FahrenheitResearch/level2-radar-macos/main/install.sh | bash
```

Downloads the latest DMG, installs to `/Applications`, and launches. That's it.

> Or grab `level2-radar-macos.dmg` manually from [Releases](https://github.com/FahrenheitResearch/level2-radar-macos/releases). Official GitHub release DMGs are intended to be Developer ID signed, notarized, and stapled.

## Build from Source (macOS)

```bash
git clone https://github.com/FahrenheitResearch/level2-radar-macos.git
cd level2-radar-macos
./package.sh
```

This generates:
- `Level2 Radar.app`
- `level2-radar-macos.zip`
- `level2-radar-macos.dmg`

Requires:
- macOS 14+
- Xcode 15+
- XcodeGen (`brew install xcodegen`)

## iOS

Open `ios/macdar.xcodeproj` in Xcode (or generate with `cd ios && xcodegen`), select your team, build and run on device.

Requires:
- Xcode 15+
- iOS 17+ device
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) if regenerating the project

## macOS Release Shape

This repo ships the iOS app on macOS via Mac Catalyst:
- SwiftUI app shell from `ios/macdar`
- same Metal-backed radar view used on iPhone
- same station picker, diagnostics, and core radar UX
- not the older standalone desktop `macdar` app

## GitHub Release Signing

This repo is set up for GitHub-hosted macOS releases that are Apple-signed and notarized. Add these GitHub Actions repository secrets:

- `MACOS_DEVELOPER_ID_P12_BASE64`: base64-encoded `.p12` export of your `Developer ID Application` certificate
- `MACOS_DEVELOPER_ID_P12_PASSWORD`: password used when exporting that `.p12`
- `APPLE_ID`: your Apple ID email
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization

The workflow already uses Team ID `X65S282G57`.

After the secrets are set, create and push a release tag:

```bash
git tag v0.1.2
git push origin v0.1.2
```

GitHub Actions will:
- build the Mac Catalyst app
- sign it with Developer ID
- notarize the DMG with Apple
- staple the notarization ticket
- publish the DMG on the GitHub release for that tag

Source builds on your own machine are not notarized unless you run the same Apple signing/notarization steps locally.

## License

MIT
