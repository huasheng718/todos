#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/Info.plist"
APP_DIR="$ROOT_DIR/build/蚁序.app"
DMG_DIR="$ROOT_DIR/build/dmg"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
DMG_PATH="$ROOT_DIR/build/蚁序-${VERSION}.dmg"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/package_app.sh" >/dev/null

rm -rf "$DMG_DIR"
rm -f "$DMG_PATH"
mkdir -p "$DMG_DIR"

export COPYFILE_DISABLE=1
ditto --norsrc --noextattr "$APP_DIR" "$DMG_DIR/蚁序.app"
ln -s /Applications "$DMG_DIR/Applications"
find "$DMG_DIR" -name '._*' -delete
xattr -d -r com.apple.provenance "$DMG_DIR" 2>/dev/null || true

hdiutil create \
  -volname "蚁序" \
  -srcfolder "$DMG_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
