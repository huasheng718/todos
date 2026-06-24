#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/ship_release.sh --version X.Y.Z --notes "release notes" [options]

Options:
  --build N       Set CFBundleVersion. Defaults to current build + 1.
  --publish       Commit, tag, push, and create the GitHub Release.
  --merge-pr      Create and merge a PR into main after publishing.
  --dry-run       Validate inputs and show the planned release only.
  --help          Show this help.

Default mode prepares the local release only: version, manifest, pkg, dmg, and hashes.
USAGE
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/Info.plist"
VERSION=""
BUILD=""
NOTES=""
PUBLISH=0
MERGE_PR=0
DRY_RUN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --build)
      BUILD="${2:-}"
      shift 2
      ;;
    --notes)
      NOTES="${2:-}"
      shift 2
      ;;
    --publish)
      PUBLISH=1
      shift
      ;;
    --merge-pr)
      MERGE_PR=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$VERSION" ] || [ -z "$NOTES" ]; then
  usage >&2
  exit 2
fi

if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Version must match X.Y.Z: $VERSION" >&2
  exit 2
fi

cd "$ROOT_DIR"

DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"

expected_download_url() {
  printf 'https://github.com/huasheng718/todos/releases/download/v%s/AntOrder-%s.pkg\n' "$VERSION" "$VERSION"
}

compare_versions() {
  python3 - "$1" "$2" <<'PY'
import sys

def parts(version):
    return [int(part) for part in version.split(".")]

left, right = parts(sys.argv[1]), parts(sys.argv[2])
length = max(len(left), len(right))
left += [0] * (length - len(left))
right += [0] * (length - len(right))

if left < right:
    print("-1")
elif left > right:
    print("1")
else:
    print("0")
PY
}

release_dirty_paths() {
  git status --short -- Info.plist releases/latest.json
}

unexpected_dirty_paths() {
  git status --short -- ':!Info.plist' ':!releases/latest.json'
}

manifest_matches_release() {
  python3 - "$ROOT_DIR/releases/latest.json" "$VERSION" "$BUILD" "$(expected_download_url)" "$NOTES" <<'PY'
import json
import sys

path, version, build, download_url, notes = sys.argv[1:]
try:
    data = json.load(open(path, encoding="utf-8"))
except FileNotFoundError:
    sys.exit(1)

if str(data.get("version")) != version:
    sys.exit(1)
if str(data.get("build")) != str(build):
    sys.exit(1)
if data.get("downloadURL") != download_url:
    sys.exit(1)
if data.get("releaseNotes") != notes:
    sys.exit(1)
PY
}

release_metadata_matches() {
  local plist_version plist_build

  plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
  plist_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"

  [ "$plist_version" = "$VERSION" ] &&
    [ "$plist_build" = "$BUILD" ] &&
    manifest_matches_release
}

ensure_only_release_metadata_changed() {
  local dirty

  dirty="$(unexpected_dirty_paths)"
  if [ -n "$dirty" ]; then
    echo "Release packaging changed non-release files. Refusing to publish mixed changes." >&2
    echo "$dirty" >&2
    exit 1
  fi
}

ensure_release_ready() {
  local branch dirty

  git fetch --prune origin "$DEFAULT_BRANCH" >/dev/null

  branch="$(git branch --show-current)"
  if [ -z "$branch" ]; then
    echo "Cannot release from a detached HEAD. Create a release branch first." >&2
    exit 1
  fi

  if [ "$branch" = "$DEFAULT_BRANCH" ]; then
    echo "Cannot release directly from $DEFAULT_BRANCH." >&2
    echo "Create a clean release worktree first:" >&2
    echo "  scripts/create_release_worktree.sh --version $VERSION" >&2
    exit 1
  fi

  if ! git rev-parse --verify "origin/$DEFAULT_BRANCH" >/dev/null 2>&1; then
    echo "origin/$DEFAULT_BRANCH is not available after fetch." >&2
    exit 1
  fi

  if ! git merge-base --is-ancestor "origin/$DEFAULT_BRANCH" HEAD; then
    echo "Current branch does not contain latest origin/$DEFAULT_BRANCH." >&2
    echo "Start from a fresh release worktree to avoid merge conflicts:" >&2
    echo "  scripts/create_release_worktree.sh --version $VERSION" >&2
    exit 1
  fi

  dirty="$(unexpected_dirty_paths)"
  if [ -n "$dirty" ]; then
    echo "Working tree has non-release changes." >&2
    echo "Commit feature changes first, then run this script so the release commit contains only version metadata." >&2
    echo "$dirty" >&2
    exit 1
  fi
}

if [ "$MERGE_PR" -eq 1 ] && [ "$PUBLISH" -ne 1 ]; then
  echo "--merge-pr requires --publish" >&2
  exit 2
fi

ensure_release_ready

if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Tag v$VERSION already exists" >&2
  exit 1
fi
if git ls-remote --exit-code --tags origin "refs/tags/v$VERSION" >/dev/null 2>&1; then
  echo "Remote tag v$VERSION already exists" >&2
  exit 1
fi

CURRENT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
if [ -z "$BUILD" ]; then
  if [ "$CURRENT_VERSION" = "$VERSION" ]; then
    BUILD="$CURRENT_BUILD"
  else
    BUILD=$((CURRENT_BUILD + 1))
  fi
fi

if ! printf '%s' "$BUILD" | grep -Eq '^[0-9]+$'; then
  echo "Build must be an integer: $BUILD" >&2
  exit 2
fi

VERSION_COMPARISON="$(compare_versions "$VERSION" "$CURRENT_VERSION")"
if [ "$VERSION_COMPARISON" -gt 0 ] && [ "$BUILD" -le "$CURRENT_BUILD" ]; then
  echo "Build must increase when releasing a newer version." >&2
  echo "Current: $CURRENT_VERSION ($CURRENT_BUILD); requested: $VERSION ($BUILD)" >&2
  exit 2
fi

echo "Preparing 蚁序 $VERSION (build $BUILD)"

if [ "$DRY_RUN" -eq 1 ]; then
  if [ -n "$(release_dirty_paths)" ] && ! release_metadata_matches; then
    echo "Dry run failed: existing release metadata does not match requested version/build/notes." >&2
    git status --short -- Info.plist releases/latest.json >&2
    exit 1
  fi
  echo "Dry run only. No files changed."
  echo "Release notes: $NOTES"
  exit 0
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$INFO_PLIST"

DOWNLOAD_URL="https://github.com/huasheng718/todos/releases/download/v${VERSION}/AntOrder-${VERSION}.pkg"
"$ROOT_DIR/scripts/update_release_manifest.sh" "$DOWNLOAD_URL" "$NOTES" >/dev/null

if [ -d Tests ]; then
  swift test
else
  echo "No Tests target detected; skipping swift test."
fi

PACKAGE_APP_LOG="/tmp/daily-todos-package-app.log"
"$ROOT_DIR/scripts/package_app.sh" >"$PACKAGE_APP_LOG"
cat "$PACKAGE_APP_LOG"
APP_PATH="$(tail -n 1 "$PACKAGE_APP_LOG")"
test -d "$APP_PATH"
RELEASE_NOTES="$NOTES" PREBUILT_APP_DIR="$APP_PATH" "$ROOT_DIR/scripts/package_installer.sh" >/tmp/daily-todos-package-installer.log
PREBUILT_APP_DIR="$APP_PATH" "$ROOT_DIR/scripts/package_dmg.sh" >/tmp/daily-todos-package-dmg.log

PKG_PATH="$ROOT_DIR/build/AntOrder-${VERSION}.pkg"
DMG_PATH="$ROOT_DIR/build/AntOrder-${VERSION}.dmg"

python3 -m json.tool "$ROOT_DIR/releases/latest.json" >/dev/null
test -f "$PKG_PATH"
test -f "$DMG_PATH"

echo "Artifacts:"
ls -lh "$PKG_PATH" "$DMG_PATH"
shasum -a 256 "$PKG_PATH" "$DMG_PATH"

if [ "$PUBLISH" -ne 1 ]; then
  echo
  echo "Prepared locally. Re-run with --publish to commit, tag, push, and create the GitHub Release."
  exit 0
fi

command -v gh >/dev/null 2>&1 || {
  echo "gh is required for --publish" >&2
  exit 1
}
gh auth status >/dev/null
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

BRANCH="$(git branch --show-current)"
if [ -z "$BRANCH" ]; then
  echo "Cannot publish from a detached HEAD" >&2
  exit 1
fi

ensure_only_release_metadata_changed
git add -- Info.plist releases/latest.json
git commit -m "release: ship $VERSION"
git tag "v$VERSION"
git push -u origin "$BRANCH"
git push origin "v$VERSION"

gh release create "v$VERSION" \
  --target "$BRANCH" \
  --title "蚁序 $VERSION" \
  --notes "$NOTES" \
  "$PKG_PATH" \
  "$DMG_PATH"

if [ "$MERGE_PR" -eq 1 ]; then
  PR_URL="$(GH_REPO="$REPO" gh pr create --base main --head "$BRANCH" --title "v$VERSION release: ship $VERSION" --body "Release $VERSION." 2>/dev/null || GH_REPO="$REPO" gh pr view --json url -q .url)"
  PR_NUMBER="$(GH_REPO="$REPO" gh pr view "$PR_URL" --json number -q .number)"
  gh api -X PUT "repos/$REPO/pulls/$PR_NUMBER/merge" -f merge_method=merge >/dev/null
  gh api -X DELETE "repos/$REPO/git/refs/heads/$BRANCH" >/dev/null || true
  echo "$PR_URL"
fi
