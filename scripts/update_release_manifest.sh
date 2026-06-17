#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/Info.plist"
MANIFEST_PATH="$ROOT_DIR/releases/latest.json"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
DOWNLOAD_URL="${1:-https://github.com/huasheng718/todos/releases/download/v${VERSION}/AntOrder-${VERSION}.pkg}"
RELEASE_NOTES="${2:-蚁序 ${VERSION} 更新。}"

mkdir -p "$(dirname "$MANIFEST_PATH")"

python3 - "$MANIFEST_PATH" "$VERSION" "$BUILD" "$DOWNLOAD_URL" "$RELEASE_NOTES" <<'PY'
import json
import sys

path, version, build, download_url, release_notes = sys.argv[1:6]
manifest = {
    "version": version,
    "build": int(build),
    "downloadURL": download_url,
    "releaseNotes": release_notes,
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

echo "$MANIFEST_PATH"
