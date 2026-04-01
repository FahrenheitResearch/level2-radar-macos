#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 /path/to/level2-archive [output-dir]" >&2
  exit 2
fi

SAMPLE_FILE="$1"
OUT_DIR="${2:-/Users/drewsny/cursdar2-metal/.parity}"
CURRENT_ROOT="/Users/drewsny/cursdar2-metal/ios/shared_src"
UPSTREAM_ROOT="/Users/drewsny/cursdar2/src"
PROBE_SRC="/Users/drewsny/cursdar2-metal/tools/stage_probe.cpp"

mkdir -p "$OUT_DIR"

CURRENT_BIN="$OUT_DIR/current-stage-probe"
UPSTREAM_BIN="$OUT_DIR/upstream-stage-probe"
CURRENT_JSON="$OUT_DIR/current-stage.json"
UPSTREAM_JSON="$OUT_DIR/upstream-stage.json"
UPSTREAM_PARSER_CPP="$OUT_DIR/upstream-level2_parser.cpp"

clang++ -std=c++17 -O2 \
  -I"$CURRENT_ROOT" -I"$CURRENT_ROOT/nexrad" \
  "$PROBE_SRC" "$CURRENT_ROOT/nexrad/level2_parser.cpp" \
  -lbz2 -lz -o "$CURRENT_BIN"

python3 - "$UPSTREAM_ROOT/nexrad/level2_parser.cpp" "$UPSTREAM_PARSER_CPP" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1]).read_text()
src = src.replace(
    "std::min(output.size() * 2, 200u * 1024u * 1024u)",
    "std::min(output.size() * 2, size_t(200u * 1024u * 1024u))",
)
Path(sys.argv[2]).write_text(src)
PY

clang++ -std=c++17 -O2 \
  -I"$UPSTREAM_ROOT" -I"$UPSTREAM_ROOT/nexrad" \
  "$PROBE_SRC" "$UPSTREAM_PARSER_CPP" \
  -lbz2 -lz -o "$UPSTREAM_BIN"

"$CURRENT_BIN" "$SAMPLE_FILE" > "$CURRENT_JSON"
"$UPSTREAM_BIN" "$SAMPLE_FILE" > "$UPSTREAM_JSON"

python3 - "$CURRENT_JSON" "$UPSTREAM_JSON" <<'PY'
import json
import sys
from pathlib import Path

current = json.loads(Path(sys.argv[1]).read_text())
upstream = json.loads(Path(sys.argv[2]).read_text())

compare_keys = [
    "station_id",
    "station_lat",
    "station_lon",
    "decoded_bytes",
    "decoded_hash",
    "sweep_count",
    "lowest_sweep_index",
    "lowest_sweep_elevation",
    "sweeps",
]

mismatches = []
for key in compare_keys:
    if current.get(key) != upstream.get(key):
        mismatches.append(key)

print("Current timings:")
print(f"  decode_ms={current['decode_ms']:.3f}")
print(f"  parse_ms={current['parse_ms']:.3f}")
print(f"  sweep_build_ms={current['sweep_build_ms']:.3f}")

print("Upstream timings:")
print(f"  decode_ms={upstream['decode_ms']:.3f}")
print(f"  parse_ms={upstream['parse_ms']:.3f}")
print(f"  sweep_build_ms={upstream['sweep_build_ms']:.3f}")

if mismatches:
    print("Parity mismatches:")
    for key in mismatches:
        print(f"  {key}")
    sys.exit(1)

print("Parser-stage parity matched.")
PY

echo "Wrote:"
echo "  $CURRENT_JSON"
echo "  $UPSTREAM_JSON"
