#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
DEFAULT_APP_PARENT="$ROOT_DIR/.build/package-app"
APP_DIR="${APP_DIR_OVERRIDE:-$DEFAULT_APP_PARENT/蚁序.app}"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/build/AppIcon.iconset"
ICON_SOURCE="$ROOT_DIR/Assets/AppIcon.png"

cd "$ROOT_DIR"

mkdir -p "$ROOT_DIR/.build" "$ROOT_DIR/build"
touch "$ROOT_DIR/.build/.metadata_never_index" "$ROOT_DIR/build/.metadata_never_index"

SWIFTPM_FLAGS=(
  -c release
  --disable-sandbox
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
  --manifest-cache local
  --cache-path "$ROOT_DIR/.build/swiftpm-cache"
  --config-path "$ROOT_DIR/.build/swiftpm-config"
  --security-path "$ROOT_DIR/.build/swiftpm-security"
)

CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache" swift build "${SWIFTPM_FLAGS[@]}"

if [ -z "${APP_DIR_OVERRIDE:-}" ]; then
  rm -rf "$DEFAULT_APP_PARENT"
fi

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

cp "$BUILD_DIR/DailyTodos" "$MACOS_DIR/DailyTodos"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
if [ -d "$BUILD_DIR/DailyTodos_DailyTodos.bundle" ]; then
  cp -R "$BUILD_DIR/DailyTodos_DailyTodos.bundle" "$RESOURCES_DIR/"
fi
cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.png"

for size in 16 32 128 256 512; do
  sips -s format png "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" --resampleHeightWidth "$size" "$size" >/dev/null
done

sips -s format png "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" --resampleHeightWidth 32 32 >/dev/null
sips -s format png "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" --resampleHeightWidth 64 64 >/dev/null
sips -s format png "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" --resampleHeightWidth 256 256 >/dev/null
sips -s format png "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" --resampleHeightWidth 512 512 >/dev/null
sips -s format png "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" --resampleHeightWidth 1024 1024 >/dev/null

xattr -cr "$ICONSET_DIR"
python3 "$ROOT_DIR/tools/make_icns.py" "$ICONSET_DIR" "$RESOURCES_DIR/AppIcon.icns"

echo "$APP_DIR"
