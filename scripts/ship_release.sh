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

if [ "$MERGE_PR" -eq 1 ] && [ "$PUBLISH" -ne 1 ]; then
  echo "--merge-pr requires --publish" >&2
  exit 2
fi

if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Tag v$VERSION already exists" >&2
  exit 1
fi
if git ls-remote --exit-code --tags origin "refs/tags/v$VERSION" >/dev/null 2>&1; then
  echo "Remote tag v$VERSION already exists" >&2
  exit 1
fi

CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
if [ -z "$BUILD" ]; then
  BUILD=$((CURRENT_BUILD + 1))
fi

if ! printf '%s' "$BUILD" | grep -Eq '^[0-9]+$'; then
  echo "Build must be an integer: $BUILD" >&2
  exit 2
fi

echo "Preparing 蚁序 $VERSION (build $BUILD)"

if [ "$DRY_RUN" -eq 1 ]; then
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

git add -u -- .
while IFS= read -r -d '' path; do
  git add -- "$path"
done < <(git ls-files --others --exclude-standard -z)
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
