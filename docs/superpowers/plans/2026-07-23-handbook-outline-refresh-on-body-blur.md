# Handbook Outline Refresh on Body Blur Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep handbook autosave active while synchronizing the Markdown outline only after the body editor loses focus.

**Architecture:** Preserve the existing isolated `HandbookOutlineState` and item-aware cancellation checks. Add an explicit outline refresh policy to the shared save function, default every save path to persistence-only, and opt in to outline refresh solely from a body-specific focus transition.

**Tech Stack:** Swift 6, SwiftUI `FocusState`, AppKit `NSTextView`, Swift Concurrency, source-backed DailyTodos quality checks, Swift Package Manager, GitHub CLI.

## Global Constraints

- Work only in `.loop/workspaces/16122E2F-B82C-4E11-89CD-1F8BC0BD0014/daily-todos`.
- Body autosave remains debounced at exactly 650 ms and must not extract or publish outline entries.
- A body-to-title or body-to-no-focus transition must persist the latest body and refresh the outline once.
- Title, attachment, category, folder, pasted-image, item-switch, and legacy-cleanup saves must not request outline refresh.
- Initial item load and item selection must continue to refresh the outline from stored body text.
- Preserve the selected-item ID guard and cooperative cancellation in `refreshOutline`.
- Do not add dependencies or change the synchronous `onUpdate` callback contract.
- Use `/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk` with module caches and build scratch output under `/tmp`.
- Release as `v1.2.40`, build `69`, after all quality checks and the Swift build pass.

## File Structure

- Modify `scripts/quality_checks.swift`: strengthen the existing outline regression guard so it distinguishes autosave from body blur.
- Modify `Sources/DailyTodos/HandbookDetailPanel.swift`: define the explicit refresh policy, default saves to persistence-only, and refresh only on body blur or initial draft synchronization.
- Create release artifacts through `scripts/ship_release.sh`; the script updates `Info.plist` and `releases/latest.json` in a separate release commit.

---

### Task 1: Gate Outline Refresh Behind Body Blur

**Files:**
- Modify: `scripts/quality_checks.swift:1927-1990`
- Modify: `Sources/DailyTodos/HandbookDetailPanel.swift:143-150,186-196`

**Interfaces:**
- Consumes: `HandbookCanvasFocus.body`, `HandbookEditorBridge.currentText`, `refreshOutline(for:itemID:)`, and the existing synchronous `onUpdate` callback.
- Produces: `private enum HandbookOutlineRefreshPolicy` with `.preserveOutline` and `.refreshOutline`.
- Produces: `submitEdit(for:force:outlineRefreshPolicy:)`, whose policy defaults to `.preserveOutline`.

- [ ] **Step 1: Replace the old save-boundary assertion with a failing body-blur regression guard**

In `checkHandbookOutlineRefreshIsolation()`, replace the expectation that requires every `submitEdit` to refresh the outline with:

```swift
let refreshPolicyCall = "outlineRefreshPolicy: .refreshOutline"
try expect(
    submitSource.contains("outlineRefreshPolicy: HandbookOutlineRefreshPolicy = .preserveOutline")
        && submitSource.contains("if outlineRefreshPolicy == .refreshOutline")
        && submitSource.contains("refreshOutline(for: savedBody, itemID: item.id)"),
    "保存接口应默认只持久化，并通过显式策略决定是否刷新文字目录"
)
try expect(
    detailSource.contains("if oldValue == .body && newValue != .body")
        && detailSource.contains("submitEdit(for: item, force: true, outlineRefreshPolicy: .refreshOutline)")
        && detailSource.components(separatedBy: refreshPolicyCall).count == 2,
    "只有正文编辑器失焦时才能显式请求刷新文字目录"
)

guard let autoSaveStart = detailSource.range(of: "private func scheduleAutoSave")?.lowerBound,
      let metricsStartAfterAutoSave = detailSource.range(
        of: "private func scheduleBodyMetricsUpdate",
        range: autoSaveStart..<detailSource.endIndex
      )?.lowerBound
else {
    throw CheckFailure.failed("无法定位手记自动保存函数")
}
let autoSaveSource = String(detailSource[autoSaveStart..<metricsStartAfterAutoSave])
try expect(
    autoSaveSource.contains("submitEdit(for: item)")
        && !autoSaveSource.contains(refreshPolicyCall),
    "650ms 自动保存只能持久化正文，不能刷新文字目录"
)
try expect(
    detailSource.contains("refreshOutline(for: cleanedStoredBody, itemID: item.id)"),
    "载入或切换手记时仍应从已存正文初始化文字目录"
)
```

Keep the existing assertions for isolated state, editor non-observation, metrics separation, selected-item ownership, and cancellation.

- [ ] **Step 2: Run the quality check and verify RED**

Run:

```bash
env \
  SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  XDG_CACHE_HOME=/tmp/daily-todos-outline-blur-red-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-outline-blur-red-cache/clang \
  SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-outline-blur-red-cache/swift \
  ./scripts/run_quality_checks.sh /tmp/DailyTodosOutlineBlurRedChecks
```

Expected: FAIL with `保存接口应默认只持久化，并通过显式策略决定是否刷新文字目录` because `submitEdit` still refreshes unconditionally.

- [ ] **Step 3: Add the explicit save policy and body-specific focus transition**

Add this file-private enum immediately before `HandbookDetailPanel`:

```swift
private enum HandbookOutlineRefreshPolicy {
    case preserveOutline
    case refreshOutline
}
```

Replace the focus handler with:

```swift
.onChange(of: canvasFocus) { oldValue, newValue in
    guard !isSyncingDraft else { return }
    if oldValue == .body && newValue != .body {
        submitEdit(for: item, force: true, outlineRefreshPolicy: .refreshOutline)
    }
}
```

Replace `submitEdit` with:

```swift
private func submitEdit(
    for item: HandbookItem,
    force: Bool = false,
    outlineRefreshPolicy: HandbookOutlineRefreshPolicy = .preserveOutline
) {
    editorState.autoSave?.cancel()
    guard canSubmit else { return }
    guard force || computeIsDirty(comparedTo: item) else { return }
    let savedBody = bodyBridge.currentText
    onUpdate(item, category, folder, title, savedBody, attachments)
    if outlineRefreshPolicy == .refreshOutline {
        refreshOutline(for: savedBody, itemID: item.id)
    }
    editorState.isDirty = false
}
```

Do not add the policy argument to any other `submitEdit` call. Existing autosave, metadata, paste, cleanup, and item-switch call sites must use the persistence-only default.

- [ ] **Step 4: Run the quality check and verify GREEN**

Run:

```bash
env \
  SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  XDG_CACHE_HOME=/tmp/daily-todos-outline-blur-green-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-outline-blur-green-cache/clang \
  SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-outline-blur-green-cache/swift \
  ./scripts/run_quality_checks.sh /tmp/DailyTodosOutlineBlurGreenChecks
```

Expected: PASS and final output `DailyTodosChecks passed`.

- [ ] **Step 5: Review the focused diff and commit the fix**

Run:

```bash
git diff --check
git diff -- Sources/DailyTodos/HandbookDetailPanel.swift scripts/quality_checks.swift
```

Confirm the diff contains exactly one `outlineRefreshPolicy: .refreshOutline` call and retains both `withTaskCancellationHandler` and `self.item?.id == itemID`.

Commit:

```bash
git add Sources/DailyTodos/HandbookDetailPanel.swift scripts/quality_checks.swift
git commit -m "fix: refresh handbook outline on body blur"
```

Expected: one feature commit containing only the production fix and its regression guard.

---

### Task 2: Verify and Release v1.2.40

**Files:**
- Verify: `Sources/DailyTodos/HandbookDetailPanel.swift`
- Verify: `scripts/quality_checks.swift`
- Modify through release script: `Info.plist`
- Modify through release script: `releases/latest.json`
- Produce: `build/AntOrder-1.2.40.pkg`
- Produce: `build/AntOrder-1.2.40.dmg`

**Interfaces:**
- Consumes: the committed Task 1 implementation and `scripts/ship_release.sh`.
- Produces: feature and release commits, tag `v1.2.40`, GitHub Release assets, a merged pull request, and updated `origin/main`.

- [ ] **Step 1: Run the complete quality suite from a clean feature tree**

Run:

```bash
env \
  SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  XDG_CACHE_HOME=/tmp/daily-todos-v1240-quality-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-v1240-quality-cache/clang \
  SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-v1240-quality-cache/swift \
  ./scripts/run_quality_checks.sh /tmp/DailyTodosV1240Checks
```

Expected: exit 0 with `DailyTodosChecks passed`. If macOS pasteboard access is denied by the outer sandbox, rerun this exact command with approved macOS access; do not weaken or skip the check.

- [ ] **Step 2: Run the Swift debug build**

Run:

```bash
env \
  SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  XDG_CACHE_HOME=/tmp/daily-todos-v1240-build-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-v1240-build-cache/clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/tmp/daily-todos-v1240-build-cache/swiftpm \
  swift build \
    --disable-sandbox \
    --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
    --scratch-path /tmp/daily-todos-v1240-build
```

Expected: exit 0 with `Build complete!`.

- [ ] **Step 3: Verify branch readiness and release inputs**

Run:

```bash
git status --short --branch
git log --oneline origin/main..HEAD
./scripts/ship_release.sh \
  --version 1.2.40 \
  --build 69 \
  --notes "修复手记正文编辑期间刷新文字目录导致输入中断的问题；文字目录仅在离开正文编辑器后同步。" \
  --dry-run
```

Expected: clean tree, the design and feature commits listed above `origin/main`, and `Dry run only. No files changed.`

- [ ] **Step 4: Publish, package, create the release, and merge the PR**

Run:

```bash
env \
  SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  XDG_CACHE_HOME=/tmp/daily-todos-v1240-release-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-v1240-release-cache/clang \
  SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-v1240-release-cache/swift \
  ./scripts/ship_release.sh \
    --version 1.2.40 \
    --build 69 \
    --notes "修复手记正文编辑期间刷新文字目录导致输入中断的问题；文字目录仅在离开正文编辑器后同步。" \
    --publish \
    --merge-pr
```

Expected:

- release commit `release: ship 1.2.40`;
- tag `v1.2.40` pushed;
- `build/AntOrder-1.2.40.pkg` and `build/AntOrder-1.2.40.dmg` uploaded;
- GitHub Release `蚁序 1.2.40` created;
- pull request created and merged into `main`;
- remote feature branch removed by the release script.

- [ ] **Step 5: Read back the published state**

Run:

```bash
git fetch origin --prune
git log -3 --oneline --decorate origin/main
gh release view v1.2.40 --json name,tagName,url,assets
gh pr list --state merged --head codex/daily-todos-outline-on-body-blur --json number,title,url,mergedAt
shasum -a 256 build/AntOrder-1.2.40.pkg build/AntOrder-1.2.40.dmg
```

Expected: `origin/main` contains the merged release branch, the release reports tag `v1.2.40` with both assets, the PR is merged, and SHA-256 hashes are printed for both local artifacts.
