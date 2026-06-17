#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/蚁序.app"
PKG_ROOT="$ROOT_DIR/build/pkgroot"
INFO_PLIST="$ROOT_DIR/Info.plist"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
PKG_PATH="$ROOT_DIR/build/蚁序-${VERSION}.pkg"
ASCII_PKG_PATH="$ROOT_DIR/build/AntOrder-${VERSION}.pkg"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/package_app.sh" >/dev/null
xattr -cr "$APP_DIR"

rm -rf "$PKG_ROOT"
rm -f "$PKG_PATH" "$ASCII_PKG_PATH"
mkdir -p "$PKG_ROOT/Applications"

export COPYFILE_DISABLE=1
ditto --norsrc --noextattr "$APP_DIR" "$PKG_ROOT/Applications/蚁序.app"
find "$PKG_ROOT" -name '._*' -delete
xattr -d -r com.apple.provenance "$PKG_ROOT" 2>/dev/null || true

pkgbuild \
  --root "$PKG_ROOT" \
  --install-location "/" \
  --identifier "${BUNDLE_ID}.pkg" \
  --version "$VERSION" \
  --ownership recommended \
  "$PKG_PATH"

cp "$PKG_PATH" "$ASCII_PKG_PATH"
"$ROOT_DIR/scripts/update_release_manifest.sh" \
  "https://github.com/huasheng718/todos/releases/download/v${VERSION}/AntOrder-${VERSION}.pkg" \
  "蚁序 ${VERSION} 更新。"

echo "$PKG_PATH"
echo "$ASCII_PKG_PATH"
