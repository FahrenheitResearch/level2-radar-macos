# Level2 Radar for macOS

GPU-accelerated NEXRAD weather radar for macOS and iPhone. Metal compute pipeline with live Level II data from AWS.

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

Downloads, installs to `/Applications`, and launches. That's it.

> Or grab `level2-radar-macos.zip` or `level2-radar-macos.dmg` manually from [Releases](https://github.com/FahrenheitResearch/level2-radar-macos/releases). If macOS says the app is from an unidentified developer, remove quarantine with `xattr -cr "/Applications/Level2 Radar.app"` after install.

## Build from Source (macOS)

```bash
git clone https://github.com/FahrenheitResearch/level2-radar-macos.git
cd level2-radar-macos
./build.sh
./build/macdar
```

Requires macOS 14+, Xcode CLT (`xcode-select --install`), CMake (`brew install cmake`). Dependencies fetched automatically.

## iOS

Open `ios/macdar.xcodeproj` in Xcode (or generate with `cd ios && xcodegen`), select your team, build and run on device.

Requires:
- Xcode 15+
- iOS 17+ device
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) if regenerating the project

## Controls (macOS)

| Key | Action |
|-----|--------|
| `1-7` | Select radar product |
| `Left/Right` | Cycle products |
| `Up/Down` | Cycle tilts |
| `A` | Toggle national mosaic |
| `V` | Toggle 3D volume |
| `X` | Toggle cross-section |
| `S` | Storm-relative velocity |
| `R` | Refresh live data |
| Scroll | Pan |
| Pinch | Zoom |
| Click | Select nearest station |

## Architecture

13 Metal compute kernels ported from CUDA:
- Forward rasterization with 32-bit atomic depth compositing
- Spatial grid acceleration for mosaic rendering
- 3D volume building, smoothing, and ray marching
- GPU-accelerated Level 2 parsing pipeline
- Hardware-interpolated 1D color lookup textures

## Origin

Metal port of [cursdar2](https://github.com/FahrenheitResearch/cursdar2). Same rendering pipeline, runs on Apple Silicon instead of NVIDIA.

## License

MIT
