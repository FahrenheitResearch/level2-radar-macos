#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"
PROJECT_PATH="$IOS_DIR/macdar.xcodeproj"
SCHEME="${SCHEME:-macdar}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/macdar.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/export}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-}"

TEAM_ID="${TEAM_ID:-}"
BUNDLE_ID="${BUNDLE_ID:-}"
MARKETING_VERSION="${MARKETING_VERSION:-}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-}"
ALLOW_UNSIGNED="${ALLOW_UNSIGNED:-0}"

mkdir -p "$(dirname "$ARCHIVE_PATH")"

cd "$IOS_DIR"
xcodegen generate >/dev/null

archive_cmd=(
  xcodebuild
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "$DESTINATION"
  archive
  -archivePath "$ARCHIVE_PATH"
)

if [[ -n "$TEAM_ID" ]]; then
  archive_cmd+=("DEVELOPMENT_TEAM=$TEAM_ID")
fi

if [[ -n "$BUNDLE_ID" ]]; then
  archive_cmd+=("PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID")
fi

if [[ -n "$MARKETING_VERSION" ]]; then
  archive_cmd+=("MARKETING_VERSION=$MARKETING_VERSION")
fi

if [[ -n "$CURRENT_PROJECT_VERSION" ]]; then
  archive_cmd+=("CURRENT_PROJECT_VERSION=$CURRENT_PROJECT_VERSION")
fi

if [[ "$ALLOW_UNSIGNED" == "1" ]]; then
  archive_cmd+=("CODE_SIGNING_ALLOWED=NO")
fi

printf 'Running archive command:\n'
printf '  %q' "${archive_cmd[@]}"
printf '\n'
"${archive_cmd[@]}"

if [[ -n "$EXPORT_OPTIONS_PLIST" ]]; then
  mkdir -p "$EXPORT_PATH"
  export_cmd=(
    xcodebuild
    -exportArchive
    -archivePath "$ARCHIVE_PATH"
    -exportPath "$EXPORT_PATH"
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
  )

  printf 'Running export command:\n'
  printf '  %q' "${export_cmd[@]}"
  printf '\n'
  "${export_cmd[@]}"
fi
