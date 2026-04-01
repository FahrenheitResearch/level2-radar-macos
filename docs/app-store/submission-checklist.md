# App Store Submission Checklist

This app is already validated for an unsigned iPhone Release archive locally.

Validated on:
- `2026-03-31`

Validated commands:
- `xcodebuild -project ios/macdar.xcodeproj -scheme macdar -configuration Release -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`
- `xcodebuild -project ios/macdar.xcodeproj -scheme macdar -configuration Release -destination 'generic/platform=iOS' archive -archivePath /tmp/macdar.xcarchive CODE_SIGNING_ALLOWED=NO`

## Before You Open Xcode

- Have your Apple Developer team selected in Xcode.
- Decide the final bundle ID.
- Decide the launch version and build number.
- Have a public support URL ready.
- Have a public privacy policy URL ready.
- Have App Store screenshots ready.

## Project Values To Set

Use either Xcode build settings or command-line overrides for:
- `DEVELOPMENT_TEAM`
- `PRODUCT_BUNDLE_IDENTIFIER`
- `MARKETING_VERSION`
- `CURRENT_PROJECT_VERSION`

Default project values live in:
- [project.yml](/Users/drewsny/cursdar2-metal/ios/project.yml)

App metadata lives in:
- [Info.plist](/Users/drewsny/cursdar2-metal/ios/macdar/Resources/Info.plist)

## Local Release Steps

1. Regenerate the Xcode project:
   `cd /Users/drewsny/cursdar2-metal/ios && xcodegen generate`
2. Open the project:
   `open /Users/drewsny/cursdar2-metal/ios/macdar.xcodeproj`
3. Select your Apple team for the `macdar` target.
4. Update bundle ID, version, and build number.
5. Choose `Any iOS Device (arm64)` or a connected iPhone.
6. Run one final device smoke test.
7. Archive from `Product > Archive`.
8. Upload with Organizer.

## Optional Command-Line Archive

Use:
- [archive-ios-release.sh](/Users/drewsny/cursdar2-metal/scripts/archive-ios-release.sh)

Unsigned validation example:
```bash
ALLOW_UNSIGNED=1 /Users/drewsny/cursdar2-metal/scripts/archive-ios-release.sh
```

Signed archive example:
```bash
TEAM_ID=YOURTEAMID \
BUNDLE_ID=com.yourcompany.macdar \
MARKETING_VERSION=1.0.0 \
CURRENT_PROJECT_VERSION=1 \
/Users/drewsny/cursdar2-metal/scripts/archive-ios-release.sh
```

## Device Smoke Test

Before upload, verify:
- App launches cleanly on a real iPhone.
- Radar draws on first load.
- Pan and pinch stay smooth.
- Station picker works.
- Product picker works.
- Settings open and close cleanly.
- `INFO` and `POINT` sheets open and dismiss cleanly.
- Refresh works.
- Backgrounding and foregrounding do not break rendering.

## App Store Connect Tasks

- Create the app record.
- Paste the metadata from:
  [app-store-connect-copy.md](/Users/drewsny/cursdar2-metal/docs/app-store/app-store-connect-copy.md)
- Paste review notes from:
  [review-notes.md](/Users/drewsny/cursdar2-metal/docs/app-store/review-notes.md)
- Use a hosted version of:
  [support-page-template.md](/Users/drewsny/cursdar2-metal/docs/app-store/support-page-template.md)
- Use a hosted version of:
  [privacy-policy-template.md](/Users/drewsny/cursdar2-metal/docs/app-store/privacy-policy-template.md)
- Fill the privacy nutrition labels to match your final answers in App Store Connect.
- Submit for review.

## Current Known Non-Blockers

- The current shipping runtime is the existing app path, not the new Rust scaffolding.
- The repo contains shared-code build warnings outside the new submission surface. They do not block archive or validation.
