#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HEADERS_DIR="$ROOT_DIR/crates/ffi/include"
BUILD_DIR="$ROOT_DIR/build/rust-ios"
XCFRAMEWORK_OUT="$ROOT_DIR/build/MetEngineFFI.xcframework"

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo is required to build the Rust XCFramework." >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"

IOS_DEVICE_TARGET="aarch64-apple-ios"
IOS_SIM_TARGET="aarch64-apple-ios-sim"

cargo build --manifest-path "$ROOT_DIR/Cargo.toml" -p ffi --release --target "$IOS_DEVICE_TARGET"
cargo build --manifest-path "$ROOT_DIR/Cargo.toml" -p ffi --release --target "$IOS_SIM_TARGET"

xcodebuild -create-xcframework \
  -library "$ROOT_DIR/target/$IOS_DEVICE_TARGET/release/libffi.a" -headers "$HEADERS_DIR" \
  -library "$ROOT_DIR/target/$IOS_SIM_TARGET/release/libffi.a" -headers "$HEADERS_DIR" \
  -output "$XCFRAMEWORK_OUT"

echo "Created $XCFRAMEWORK_OUT"
