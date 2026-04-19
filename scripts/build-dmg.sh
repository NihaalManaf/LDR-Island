#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LDRIsland"
SCHEME="LDRIsland"
PROJECT="LDRIsland.xcodeproj"
CONFIGURATION="Release"

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi
BUILD_DIR="$(pwd)/build"
ARCHIVE_DIR="$BUILD_DIR/archive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_DIR="$BUILD_DIR/dmg"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' LDRIsland/Info.plist)}"
DMG_NAME="LDR-Island-${VERSION}.dmg"
VOLUME_NAME="LDR Island"

rm -rf "$ARCHIVE_DIR" "$EXPORT_DIR" "$DMG_DIR"
mkdir -p "$ARCHIVE_DIR" "$EXPORT_DIR" "$DMG_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$ARCHIVE_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="$(find "$ARCHIVE_DIR/Build/Products/$CONFIGURATION" -maxdepth 1 -name "$APP_NAME.app" -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "Could not find built app bundle"
  exit 1
fi

cp -R "$APP_PATH" "$EXPORT_DIR/"
ln -s /Applications "$EXPORT_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$EXPORT_DIR" \
  -ov \
  -format UDZO \
  "$DMG_DIR/$DMG_NAME"

echo "DMG created: $DMG_DIR/$DMG_NAME"
