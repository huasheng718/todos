# Final Review Fix Report

## Scope

Fix the native handbook body editor identity so switching between different note
IDs always creates a fresh AppKit editor, even when both notes have the same
stored body text.

## RED Evidence

Focused check command:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
XDG_CACHE_HOME=/tmp/daily-todos-final-review-red-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-final-review-red-cache/clang \
SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-final-review-red-cache/swift \
bash -x ./scripts/run_quality_checks.sh /tmp/DailyTodosFinalReviewRedChecks
```

Result: exit 1 with the intended failure:

```text
DailyTodosChecks failed: 正文编辑器身份必须同时包含手记 ID 和重置代次，不能只依赖正文内容变化
```

## Implementation

`HandbookDetailPanel` now keys `HandbookBodyEditorSection` with
`[item.id, bodyEditorResetID]`. Item switches therefore recreate the native
editor even when the body seed is equal, while an explicit same-item reset can
still recreate it through `bodyEditorResetID`.

The focused quality check requires that combined identity boundary, covers
equal-body note switches and same-item reset generations, and uses live AppKit
assertions for fresh `NSTextView` identity, cleared marked text, reset
selection, and no inherited undo capability.

## GREEN Evidence

Complete desktop quality command:

```bash
env SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
XDG_CACHE_HOME=/tmp/daily-todos-v1242-final-fix-quality-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-v1242-final-fix-quality-cache/clang \
SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-v1242-final-fix-quality-cache/swift \
./scripts/run_quality_checks.sh /tmp/DailyTodosV1242FinalFixChecks
```

Result: exit 0.

```text
DailyTodosChecks passed
```

## Build Evidence

```bash
env SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
XDG_CACHE_HOME=/tmp/daily-todos-v1242-final-fix-build-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-v1242-final-fix-build-cache/clang \
SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-v1242-final-fix-build-cache/swift \
swift build --disable-sandbox \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  --scratch-path /tmp/DailyTodosV1242FinalFixBuild
```

Result: exit 0, `Build complete! (59.45s)`. The only output besides build
progress was the known SwiftPM user-cache read-only warning.

## Review

`git diff --check` passed. Release metadata and publishing paths are untouched.

Changed paths:

- `Sources/DailyTodos/HandbookDetailPanel.swift`
- `scripts/quality_checks.swift`
- `.superpowers/sdd/final-review-fix-report.md`

Commit: `fix: isolate handbook editor across notes`

## Concerns

None. No release metadata was changed and no publishing action was performed.
