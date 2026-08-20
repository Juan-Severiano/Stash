#!/bin/bash
set -euo pipefail

# Builds the distributable Mac app, then creates a signed and notarized DMG.
# Required for a release: DEVELOPMENT_TEAM, SIGNING_IDENTITY, NOTARIZATION_KEY_PATH,
# NOTARIZATION_KEY_ID, and NOTARIZATION_ISSUER_ID.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="${SCHEME:-Stash}"
CONFIGURATION="${CONFIGURATION:-Release}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
ARCHIVE_PATH="$OUTPUT_DIR/$SCHEME.xcarchive"
DMG_PATH="$OUTPUT_DIR/Stash.dmg"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"
SKIP_SIGNING="${SKIP_SIGNING:-0}"

require() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

if [[ "$SKIP_SIGNING" != "1" ]]; then
  require DEVELOPMENT_TEAM
  require SIGNING_IDENTITY
fi

if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
  require NOTARIZATION_KEY_PATH
  require NOTARIZATION_KEY_ID
  require NOTARIZATION_ISSUER_ID
fi

rm -rf "$ARCHIVE_PATH" "$DMG_PATH"
mkdir -p "$OUTPUT_DIR"

BUILD_SETTINGS=(
  -project "$ROOT_DIR/Stash.xcodeproj"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "generic/platform=macOS"
  -archivePath "$ARCHIVE_PATH"
)

if [[ "$SKIP_SIGNING" == "1" ]]; then
  BUILD_SETTINGS+=(CODE_SIGNING_ALLOWED=NO)
else
  BUILD_SETTINGS+=(
    CODE_SIGN_STYLE=Manual
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY"
  )
fi

xcodebuild archive "${BUILD_SETTINGS[@]}"

APP_PATH="$ARCHIVE_PATH/Products/Applications/Stash.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle not found: $APP_PATH" >&2
  exit 1
fi

if [[ "$SKIP_SIGNING" != "1" ]]; then
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
fi

hdiutil create \
  -volname "Stash" \
  -srcfolder "$APP_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ "$SKIP_SIGNING" != "1" ]]; then
  codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"
fi

if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
  xcrun notarytool submit "$DMG_PATH" \
    --key "$NOTARIZATION_KEY_PATH" \
    --key-id "$NOTARIZATION_KEY_ID" \
    --issuer "$NOTARIZATION_ISSUER_ID" \
    --wait
  xcrun stapler staple "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature -vv "$DMG_PATH"
fi

echo "Created $DMG_PATH"
