#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/create_release_worktree.sh --version X.Y.Z [options]

Options:
  --branch NAME   Release branch name. Defaults to codex/daily-todos-release-X.Y.Z.
  --path PATH     Worktree path. Defaults to the sibling loop-engineering .loop workspace when available.
  --dry-run       Validate and print the planned worktree without creating it.
  --help          Show this help.

Creates a clean release worktree from origin/main. Dirty files in the current checkout are not copied.
USAGE
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
VERSION=""
BRANCH=""
TARGET_PATH=""
DRY_RUN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:-}"
      shift 2
      ;;
    --path)
      TARGET_PATH="${2:-}"
      shift 2
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

if [ -z "$VERSION" ]; then
  usage >&2
  exit 2
fi

if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Version must match X.Y.Z: $VERSION" >&2
  exit 2
fi

if [ -z "$BRANCH" ]; then
  BRANCH="codex/daily-todos-release-$VERSION"
fi

if ! printf '%s' "$BRANCH" | grep -Eq '^[A-Za-z0-9._/-]+$'; then
  echo "Branch contains unsupported characters: $BRANCH" >&2
  exit 2
fi

default_target_path() {
  local parent prefix

  parent="$(cd "$ROOT_DIR/.." && pwd)"
  if [ -d "$parent/loop-engineering/.loop/workspaces" ]; then
    printf '%s\n' "$parent/loop-engineering/.loop/workspaces/manual-daily-todos-release-$VERSION/daily-todos"
    return
  fi

  case "$ROOT_DIR" in
    */loop-engineering/.loop/workspaces/*/daily-todos)
      prefix="${ROOT_DIR%%/loop-engineering/.loop/workspaces/*}"
      if [ -d "$prefix/loop-engineering/.loop/workspaces" ]; then
        printf '%s\n' "$prefix/loop-engineering/.loop/workspaces/manual-daily-todos-release-$VERSION/daily-todos"
        return
      fi
      ;;
  esac

  printf '%s\n' "$ROOT_DIR/.release-worktrees/daily-todos-release-$VERSION"
}

if [ -z "$TARGET_PATH" ]; then
  TARGET_PATH="$(default_target_path)"
fi

case "$TARGET_PATH" in
  /*) ;;
  *) TARGET_PATH="$ROOT_DIR/$TARGET_PATH" ;;
esac

cd "$ROOT_DIR"

git fetch --prune origin "$DEFAULT_BRANCH" >/dev/null

if ! git rev-parse --verify "origin/$DEFAULT_BRANCH" >/dev/null 2>&1; then
  echo "origin/$DEFAULT_BRANCH is not available after fetch." >&2
  exit 1
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "Local branch already exists: $BRANCH" >&2
  echo "Choose a different --branch or remove the old release branch after verifying it is no longer needed." >&2
  exit 1
fi

if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  echo "Remote branch already exists: $BRANCH" >&2
  echo "Choose a different --branch or finish the existing release branch first." >&2
  exit 1
fi

if [ -e "$TARGET_PATH" ]; then
  echo "Target path already exists: $TARGET_PATH" >&2
  echo "Choose a different --path or archive the old worktree after verifying it is no longer needed." >&2
  exit 1
fi

if [ -n "$(git status --short)" ]; then
  echo "Note: current checkout has dirty files. They will not be copied into the release worktree." >&2
fi

echo "Release worktree plan:"
echo "  base:   origin/$DEFAULT_BRANCH"
echo "  branch: $BRANCH"
echo "  path:   $TARGET_PATH"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run only. No worktree created."
  exit 0
fi

mkdir -p "$(dirname "$TARGET_PATH")"
git worktree add -b "$BRANCH" "$TARGET_PATH" "origin/$DEFAULT_BRANCH"

cat <<NEXT

Created clean release worktree.

Next:
  cd "$TARGET_PATH"
  # make and commit feature changes here
  scripts/ship_release.sh --version $VERSION --notes "蚁序 $VERSION 更新：..." --publish --merge-pr
NEXT
