# iPhone Radar Migration Notes

This repository now carries the phase-0 workspace layout for the iPhone-first architecture:

- `ios/macdar` remains the active SwiftUI + Metal shell.
- `crates/*` defines the Rust-side meteorological engine boundaries.
- `crates/ffi` owns the coarse C ABI intended for XCFramework export.
- `backend/gateway` and `backend/model-prep` document the thin services expected by the app.

## Why this split

The existing app is still a direct Swift/ObjC++ bridge into the legacy C++ `App` object. That keeps the product moving, but it is the wrong long-term ownership model for:

- immutable frame snapshots
- Rust-owned sounding and plot compute
- thin, stable Swift/Rust boundary calls
- app-ready model data contracts

The migration path is:

1. Keep the current iOS shell shipping.
2. Move meteorological state and packing into Rust crates.
3. Preserve Metal ownership in Swift/iOS.
4. Replace per-frame engine traversal with snapshot uploads.

## What is implemented in this pass

- Cargo workspace and crate boundaries matching the new architecture.
- Frame snapshot domain types and C ABI contracts.
- An iOS bridge type that reports Rust runtime bundling status.
- A higher-level app orchestrator on the Swift side.
- Interaction-time render scaling in the current Metal coordinator so the app already behaves closer to the target dynamic-quality policy.

## What is still stubbed

- Real Level II decoding in Rust.
- `sharprs` integration.
- `wrf-rust-plots` palette export and offscreen rendering.
- XCFramework production and linkage into Xcode.
- Model backend tile/profile services.

Those pieces are represented by real module boundaries and contracts so they can be filled in without rewriting the shell again.
