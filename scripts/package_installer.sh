#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/Info.plist"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
PKG_PATH="$ROOT_DIR/build/蚁序-${VERSION}.pkg"
ASCII_PKG_PATH="$ROOT_DIR/build/AntOrder-${VERSION}.pkg"
WORK_DIR="$(mktemp -d "$ROOT_DIR/build/pkgwork-${VERSION}.XXXXXX")"
APP_DIR="$WORK_DIR/蚁序.app"
PKG_ROOT="$WORK_DIR/pkgroot"
PKG_SCRIPTS="$WORK_DIR/pkgscripts"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cd "$ROOT_DIR"

APP_DIR_OVERRIDE="$APP_DIR" "$ROOT_DIR/scripts/package_app.sh" >/dev/null
xattr -cr "$APP_DIR"

rm -f "$PKG_PATH" "$ASCII_PKG_PATH"
mkdir -p "$PKG_ROOT/Applications" "$PKG_SCRIPTS"

export COPYFILE_DISABLE=1
ditto --norsrc --noextattr "$APP_DIR" "$PKG_ROOT/Applications/蚁序.app"
find "$PKG_ROOT" -name '._*' -delete
xattr -d -r com.apple.provenance "$PKG_ROOT" 2>/dev/null || true

cat > "$PKG_SCRIPTS/postinstall" <<'SCRIPT'
#!/bin/sh
set -eu

APP_PATH="/Applications/蚁序.app"

/usr/bin/killall DailyTodos >/dev/null 2>&1 || true
/bin/sleep 0.6

if [ -d "$APP_PATH" ]; then
  /usr/bin/open "$APP_PATH" >/dev/null 2>&1 || true
fi

exit 0
SCRIPT
chmod 755 "$PKG_SCRIPTS/postinstall"

pkgbuild \
  --root "$PKG_ROOT" \
  --scripts "$PKG_SCRIPTS" \
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
