# Handbook Outline Refresh After Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent handbook outline refreshes from invalidating the active body editor by publishing outline changes only after a save boundary or initial item load.

**Architecture:** Give the outline its own observable state in `HandbookOutlineViews.swift`, so the body editor never subscribes to outline notifications. Keep body metrics on the existing 100 ms input path, and move heading extraction to an item-aware refresh function invoked after persistence or initial draft synchronization.

**Tech Stack:** Swift 6, SwiftUI, AppKit `NSTextView`, Swift Concurrency, the existing source-backed DailyTodos quality-check executable.

## Global Constraints

- Work only in the isolated `.loop/workspaces/<run-id>/daily-todos` checkout.
- Continuous body input must not extract or publish outline entries.
- The existing 650 ms autosave is a save boundary and must refresh the outline after `onUpdate` returns.
- Leaving the editor uses the existing forced save and must refresh the outline after `onUpdate` returns.
- Initial load or item selection must immediately schedule an outline refresh from stored text.
- Body metrics may continue updating during input.
- Do not add dependencies or change the persistence callback contract.
- Use the Command Line Tools Swift 6.3.3 environment with caches and SwiftPM scratch output under `/tmp`; do not select the installed Xcode 13.4.1 toolchain.

## File Structure

- Modify `Sources/DailyTodos/HandbookOutlineViews.swift`: own `HandbookOutlineState` next to outline extraction and rendering.
- Modify `Sources/DailyTodos/HandbookBodyEditorSection.swift`: remove outline publication from editor state and document the narrower invalidation boundary.
- Modify `Sources/DailyTodos/HandbookDetailPanel.swift`: own the separate outline state and route refreshes through load/save boundaries.
- Modify `scripts/quality_checks.swift`: add the regression guard and invoke it from the quality-check entry point.

---

### Task 1: Isolate Outline Publication and Refresh It at Persistence Boundaries

**Files:**
- Modify: `scripts/quality_checks.swift:17-55,1908-1925`
- Modify: `Sources/DailyTodos/HandbookOutlineViews.swift:1-25`
- Modify: `Sources/DailyTodos/HandbookBodyEditorSection.swift:30-57`
- Modify: `Sources/DailyTodos/HandbookDetailPanel.swift:9-20,97-121,186-305,316-326`

**Interfaces:**
- Consumes: `MarkdownOutlineEntry.extract(from: String) -> [MarkdownOutlineEntry]`, the existing synchronous `onUpdate` callback, and `HandbookEditorBridge.currentText: String`.
- Produces: `@MainActor final class HandbookOutlineState: ObservableObject` with `@Published var entries: [MarkdownOutlineEntry]` and `var refreshTask: Task<Void, Never>?`.
- Produces: `private func refreshOutline(for text: String, itemID: UUID)` in `HandbookDetailPanel`.
- Produces: `HandbookOutlineContainer(outlineState: HandbookOutlineState)` that is the only detail-panel child subscribing to outline entries.

- [ ] **Step 1: Add the failing regression guard**

Add `try checkHandbookOutlineRefreshIsolation()` immediately after `checkHandbookEditorSyncPolicy()` in `DailyTodosChecks.main`.

Add this function after `checkHandbookDetailReconcilesSameItemUpdates()`:

```swift
func checkHandbookOutlineRefreshIsolation() throws {
    let outlineSource = try sourceFile("Sources/DailyTodos/HandbookOutlineViews.swift")
    let editorSource = try sourceFile("Sources/DailyTodos/HandbookBodyEditorSection.swift")
    let detailSource = try sourceFile("Sources/DailyTodos/HandbookDetailPanel.swift")

    try expect(
        outlineSource.contains("final class HandbookOutlineState: ObservableObject")
            && outlineSource.contains("@Published var entries: [MarkdownOutlineEntry] = []")
            && !editorSource.contains("@Published var outline:"),
        "文字目录应使用独立 ObservableObject，不能继续通过 HandbookEditorState 发布"
    )

    guard let bodyEditorStart = editorSource.range(of: "struct HandbookBodyEditorSection")?.lowerBound else {
        throw CheckFailure.failed("无法定位 HandbookBodyEditorSection")
    }
    let bodyEditorSource = String(editorSource[bodyEditorStart...])
    try expect(
        !bodyEditorSource.contains("HandbookOutlineState"),
        "正文编辑器不能订阅文字目录状态，目录发布不得使 NSTextView 输入路径失效"
    )

    guard let metricsStart = detailSource.range(of: "private func scheduleBodyMetricsUpdate")?.lowerBound,
          let outlineRefreshStart = detailSource.range(of: "private func refreshOutline", range: metricsStart..<detailSource.endIndex)?.lowerBound,
          let dirtyStart = detailSource.range(of: "private func computeIsDirty", range: outlineRefreshStart..<detailSource.endIndex)?.lowerBound,
          let submitStart = detailSource.range(of: "private func submitEdit")?.lowerBound,
          let syncStart = detailSource.range(of: "private func syncDraft", range: submitStart..<detailSource.endIndex)?.lowerBound
    else {
        throw CheckFailure.failed("无法定位手记正文指标或保存同步函数")
    }

    let metricsSource = String(detailSource[metricsStart..<outlineRefreshStart])
    let outlineRefreshSource = String(detailSource[outlineRefreshStart..<dirtyStart])
    let submitSource = String(detailSource[submitStart..<syncStart])
    try expect(
        !metricsSource.contains("MarkdownOutlineEntry.extract")
            && !metricsSource.contains("outlineState"),
        "正文逐字指标更新不能解析或发布文字目录"
    )
    try expect(
        submitSource.contains("let savedBody = bodyBridge.currentText")
            && submitSource.contains("refreshOutline(for: savedBody, itemID: item.id)")
            && detailSource.contains("refreshOutline(for: cleanedStoredBody, itemID: item.id)"),
        "文字目录应只在保存完成或载入已存草稿后刷新"
    )
    try expect(
        outlineRefreshSource.contains("guard !Task.isCancelled, self.item?.id == itemID else { return }"),
        "异步目录结果发布前应确认任务未取消且手记仍被选中"
    )
    try expect(
        detailSource.contains("HandbookOutlineContainer(outlineState: outlineState)"),
        "文字目录容器应只观察独立的 outlineState"
    )
}
```

- [ ] **Step 2: Run the guard and verify RED**

Run:

```bash
XDG_CACHE_HOME=/tmp/daily-todos-outline-red-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-outline-red-cache/clang \
SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-outline-red-cache/swift \
./scripts/run_quality_checks.sh /tmp/DailyTodosOutlineRedChecks
```

Expected: FAIL with `文字目录应使用独立 ObservableObject，不能继续通过 HandbookEditorState 发布`.

- [ ] **Step 3: Add the isolated outline state**

Insert this in `HandbookOutlineViews.swift` after `MarkdownOutlineEntry`:

```swift
@MainActor
final class HandbookOutlineState: ObservableObject {
    @Published var entries: [MarkdownOutlineEntry] = []
    var refreshTask: Task<Void, Never>?
}
```

In `HandbookBodyEditorSection.swift`, remove:

```swift
@Published var outline: [MarkdownOutlineEntry] = []
```

Update the state comment so it says `HandbookEditorState` contains dirty state, body metrics, and debounce tasks, while outline publication lives in `HandbookOutlineState`. Update the `HandbookBodyEditorSection` comment so body changes report body metrics, dirty state, and autosave; do not claim that per-keystroke changes update the outline.

- [ ] **Step 4: Wire the outline state into the detail panel**

Replace the unused `outlineUpdateToken` state with:

```swift
@State private var outlineState = HandbookOutlineState()
```

Change the outline container call to:

```swift
HandbookOutlineContainer(outlineState: outlineState)
```

Replace the container at the bottom of `HandbookDetailPanel.swift` with:

```swift
struct HandbookOutlineContainer: View {
    @ObservedObject var outlineState: HandbookOutlineState

    var body: some View {
        if !outlineState.entries.isEmpty {
            HandbookOutlineStrip(entries: outlineState.entries)
                .frame(maxWidth: 880, alignment: .leading)
                .padding(.bottom, 16)
        }
    }
}
```

- [ ] **Step 5: Move outline extraction out of the input path**

Change `submitEdit` to capture exactly the text passed to persistence and refresh only after the callback returns:

```swift
private func submitEdit(for item: HandbookItem, force: Bool = false) {
    editorState.autoSave?.cancel()
    guard canSubmit else { return }
    guard force || computeIsDirty(comparedTo: item) else { return }
    let savedBody = bodyBridge.currentText
    onUpdate(item, category, folder, title, savedBody, attachments)
    refreshOutline(for: savedBody, itemID: item.id)
    editorState.isDirty = false
}
```

In `syncDraft`, refresh from stored text only when local text is being replaced:

```swift
if !preservesLocalTextEdits {
    refreshOutline(for: cleanedStoredBody, itemID: item.id)
}
scheduleBodyMetricsUpdate(for: preservesLocalTextEdits ? bodyBridge.currentText : cleanedStoredBody)
```

Reduce `scheduleBodyMetricsUpdate` to body metrics only:

```swift
private func scheduleBodyMetricsUpdate(for text: String) {
    editorState.bodyMetricsTask?.cancel()
    editorState.bodyMetricsTask = Task {
        try? await Task.sleep(for: .milliseconds(100))
        guard !Task.isCancelled else { return }

        let metrics = await Task.detached(priority: .userInitiated) {
            PerformanceMonitor.measure("HandbookDetail.metrics.body") {
                HandbookBodyMetrics(text: text)
            }
        }.value

        guard !Task.isCancelled else { return }
        if editorState.bodyMetrics != metrics {
            editorState.bodyMetrics = metrics
        }
    }
}
```

Add the item-aware outline refresh before `computeIsDirty`:

```swift
private func refreshOutline(for text: String, itemID: UUID) {
    outlineState.refreshTask?.cancel()
    outlineState.refreshTask = Task {
        let newEntries: [MarkdownOutlineEntry]
        if text.contains("#") {
            newEntries = await Task.detached(priority: .userInitiated) {
                PerformanceMonitor.measure("HandbookDetail.metrics.outline") {
                    MarkdownOutlineEntry.extract(from: text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }.value
        } else {
            newEntries = []
        }

        guard !Task.isCancelled, self.item?.id == itemID else { return }
        if outlineState.entries != newEntries {
            outlineState.entries = newEntries
        }
    }
}
```

- [ ] **Step 6: Run the focused guard and verify GREEN**

Run:

```bash
XDG_CACHE_HOME=/tmp/daily-todos-outline-green-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-outline-green-cache/clang \
SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-outline-green-cache/swift \
./scripts/run_quality_checks.sh /tmp/DailyTodosOutlineGreenChecks
```

Expected: exit 0 and `DailyTodosChecks passed` when the compiler output is not suppressed.

- [ ] **Step 7: Run the full Swift build in an isolated scratch directory**

Run:

```bash
XDG_CACHE_HOME=/tmp/daily-todos-outline-build-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-outline-build-cache/clang \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/daily-todos-outline-build-cache/swiftpm \
swift build --disable-sandbox --scratch-path /tmp/daily-todos-outline-swift-build
```

Expected: exit 0 with `Build complete!` and an arm64 executable at `/tmp/daily-todos-outline-swift-build/arm64-apple-macosx/debug/DailyTodos`.

- [ ] **Step 8: Review the diff and commit the fix**

Run:

```bash
git diff --check
git diff -- Sources/DailyTodos/HandbookOutlineViews.swift Sources/DailyTodos/HandbookBodyEditorSection.swift Sources/DailyTodos/HandbookDetailPanel.swift scripts/quality_checks.swift
git status --short
```

Expected: only the four planned files are modified, with no whitespace errors.

Commit:

```bash
git add Sources/DailyTodos/HandbookOutlineViews.swift Sources/DailyTodos/HandbookBodyEditorSection.swift Sources/DailyTodos/HandbookDetailPanel.swift scripts/quality_checks.swift
git commit -m "fix: refresh handbook outline after save"
```
