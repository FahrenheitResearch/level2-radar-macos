# cursdar2 v0.2.0 Port Map

This is the working file-by-file map for bringing the iPhone app in line with `cursdar2 v0.2.0` instead of the older CUDA snapshot it originally mirrored.

## Ground Rules

- Keep the app barebones: fast single-radar loop, minimal UI, minimal transient allocations.
- Use one canonical radar path: `ingest/catalog -> cleanup -> QC/preprocess -> canonical sweep/tensor -> detect/colorize -> display`.
- Keep shared storage for CPU-visible buffers only. Scratch buffers and GPU-only working sets should be private.
- Size threadgroups from the compiled Metal pipeline and dispatch with `dispatchThreads`.

## Current Live iOS Path

- App runtime: `ios/shared_src/app.cpp`
- Live parser: `ios/shared_src/nexrad/level2_parser.cpp`
- Canonical sweep storage: `ios/shared_src/nexrad/sweep_data.h`
- Metal host/runtime: `ios/shared_src/metal/MetalRenderer.mm`
- Metal shaders: `ios/shared_src/metal/renderer.metal`, `ios/shared_src/metal/gpu_pipeline.metal`, `ios/shared_src/metal/volume3d.metal`
- Swift render shell: `ios/macdar/Renderer/MetalRenderCoordinator.swift`

## Source-of-Truth Mapping

| Stage | `cursdar2 v0.2.0` | iOS target file(s) | Status |
| --- | --- | --- | --- |
| Archive decode split | `src/nexrad/level2_parser.cpp` | `ios/shared_src/nexrad/level2_parser.cpp` | Ported this pass |
| Per-station stage timings | `src/app.h`, `src/app.cpp` | `ios/shared_src/app.h`, `ios/shared_src/app.cpp` | Ported this pass |
| Canonical precomputed sweep build | `src/app.cpp` (`buildPrecomputedSweep`, `buildPrecomputedSweeps`) | `ios/shared_src/app.cpp` | Ported this pass |
| Remove duplicate parsed/display graphs | `src/app.h` station state | `ios/shared_src/app.h`, `ios/shared_src/app.cpp` | Ported this pass |
| GPU render scratch ownership | `src/cuda/*` memory model | `ios/shared_src/metal/MetalRenderer.mm` | Partial this pass |
| Pipeline-derived thread dispatch | `src/cuda/*` launch sizing equivalent | `ios/shared_src/metal/MetalRenderer.mm` | Ported this pass |
| Lowest-sweep GPU ingest/catalog | `src/cuda/gpu_pipeline.cu` | `ios/shared_src/metal/gpu_pipeline.metal` + missing host wiring | Not yet wired live |
| GPU sweep cleanup | `src/cuda/gpu_pipeline.cu` cleanup/normalize flow | `ios/shared_src/metal/gpu_pipeline.metal` + host glue | Not yet wired live |
| GPU QC/preprocess | `src/cuda/gpu_pipeline.cu`, `src/app.cpp` preprocess | new Metal host stage in `ios/shared_src/metal/MetalRenderer.mm` | Not yet wired live |
| Canonical tensor build | `src/cuda/gpu_tensor.cu/.cuh` | no iOS equivalent yet | Missing |
| Detect from same tensor | `src/cuda/gpu_detection.cu/.cuh` | no iOS equivalent yet | Missing |
| Product-specialized kernels via function constants | `v0.2.0` review requirement | `ios/shared_src/metal/renderer.metal`, `MetalRenderer.mm` | Planned next |

## What Changed In This Pass

- `Level2Parser` on iOS now exposes `decodeArchiveBytes()` and `parseDecodedMessages()` so decode and parse are timed separately.
- `StationState` now keeps raw archive bytes plus one canonical `precomputed` sweep working set instead of holding a second long-lived `ParsedRadarData` graph.
- iOS station state now tracks explicit `decode_ms`, `parse_ms`, `sweep_build_ms`, `preprocess_ms`, `detection_ms`, and `upload_ms`.
- The Metal host now uses `dispatchThreads` and derives threadgroup shape from `threadExecutionWidth` and `maxTotalThreadsPerThreadgroup`.
- Forward-render accumulation buffers and 3D volume scratch buffers moved to private storage.

## Next GPU Pass

1. Add host-side Metal wiring for `gpu_pipeline.metal` so the live iPhone path can ingest the lowest sweep without a CPU-built preview graph.
2. Port cleanup normalization from `cursdar2` into explicit Metal stages:
   - short-sweep drop
   - azimuth dedupe
   - seam handling
3. Introduce function-constant-specialized render kernels, starting with product-specialized single-station and forward-render variants.
4. Add Metal-side QC/preprocess so detection and display consume the same canonical device-resident buffer.
5. Port `gpu_tensor` and `gpu_detection` concepts to Metal so detection stops walking CPU sweep arrays.

## Parity Harness

- Probe source: `tools/stage_probe.cpp`
- Compare script: `scripts/compare-parser-parity.sh`

Current harness scope:

- archive decode parity
- decoded-byte hash parity
- parsed sweep count / lowest sweep parity
- canonical precomputed sweep hash parity
- separate stage timings for decode, parse, and sweep build

This is the first parity rung. GPU ingest, cleanup, QC, tensor, detect, and render parity need the next Metal stage ports before they can be compared meaningfully.
