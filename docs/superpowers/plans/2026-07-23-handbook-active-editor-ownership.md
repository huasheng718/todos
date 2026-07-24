# Handbook Active Editor Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep handbook autosave active while preventing same-note model publication from mutating the active native editor, marked text, selection, caret, or focus.

**Architecture:** Add a pure ownership policy and a focused AppKit reconciler. `HandbookPastingTextEditor` will consult both before changing native text storage: same-note active sessions preserve the existing `NSTextView`, while inactive or note-switch updates may synchronize external text. The existing store publication, explicit outside-click exit, and outline-refresh contracts remain unchanged.

**Tech Stack:** Swift 6, SwiftUI `NSViewRepresentable`, AppKit `NSTextView`, executable quality checks, Swift Package Manager, macOS 15.4 SDK compatibility path, GitHub CLI.

## Global Constraints

- Work only in `.loop/workspaces/0FF641E7-3BB5-4E9E-A1E8-D6AEE364925C/daily-todos`.
- Body and title autosave remains debounced at exactly 650 ms.
- The active same-note editor is the authoritative body source until explicit editor exit.
- Same-note store publication must not replace text, document attributes, marked text, selection, insertion point, native view identity, or focus.
- Autosave remains persistence-only and must not refresh the outline.
- Only an explicit click outside the registered editor region ends the session and refreshes the outline.
- A note switch may discard the old note's marked state and create the new note's editor from its stored body.
- Do not add a silent persistence API, draft architecture, or third-party dependency.
- Preserve current image-paste, focus recovery, outside-click classification, stale outline cancellation, and item-ownership behavior.
- Use `/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk` and isolated caches under `/tmp`; the default macOS 26.5 SDK is incompatible with the installed Swift compiler.
- Run the complete quality executable with desktop permission because its existing pasteboard check fails inside the restricted sandbox.
- Release only after real packaged-app Chinese input verification.
- Release as `v1.2.42`, build `71`.

## File Structure

- Create `Sources/DailyTodos/HandbookEditorContentPolicy.swift`: pure decision types for same-note native editor ownership.
- Create `Sources/DailyTodos/HandbookNativeTextViewReconciler.swift`: AppKit-only initialization and allowed external text synchronization.
- Modify `Sources/DailyTodos/HandbookEditorSessionController.swift`: expose logical ownership without requiring the window to remain key.
- Modify `Sources/DailyTodos/HandbookPastingTextEditor.swift`: remove unconditional live text-view mutation and route updates through the policy/reconciler.
- Modify `scripts/run_quality_checks.sh`: compile the two focused source files into the executable check target.
- Modify `scripts/quality_checks.swift`: add pure policy, live AppKit marked-text, and integration wiring regression checks.
- Modify through `scripts/ship_release.sh`: update `Info.plist` and `releases/latest.json` in the release commit.

---

### Task 1: Define Native Editor Ownership Policy

**Files:**
- Create: `Sources/DailyTodos/HandbookEditorContentPolicy.swift`
- Modify: `Sources/DailyTodos/HandbookEditorSessionController.swift:57-66`
- Modify: `scripts/run_quality_checks.sh:23-27`
- Modify: `scripts/quality_checks.swift:26-34,608-642`

**Interfaces:**
- Produces: `HandbookEditorContentDecision` with `.preserveEditor` and `.synchronizeExternalText`.
- Produces: `HandbookEditorContentPolicy.decision(representedItemID:incomingItemID:isSessionOwner:isFirstResponder:hasMarkedText:) -> HandbookEditorContentDecision`.
- Produces: `HandbookEditorSessionController.ownsActiveEditor(itemID:) -> Bool`.
- Consumes: existing session item ID and exit state. Ownership covers the whole
  editor session, including title focus and editor controls.

- [ ] **Step 1: Add failing executable policy checks**

Add `try checkHandbookEditorContentPolicy()` immediately after
`try checkHandbookEditorFocusPolicy()` in `DailyTodosChecks.main`, then add:

```swift
func checkHandbookEditorContentPolicy() throws {
    let itemID = UUID()
    let anotherItemID = UUID()

    try expect(
        HandbookEditorContentPolicy.decision(
            representedItemID: itemID,
            incomingItemID: itemID,
            isSessionOwner: true,
            isFirstResponder: false,
            hasMarkedText: false
        ) == .preserveEditor,
        "同一手记编辑会话必须保留活动原生编辑器"
    )
    try expect(
        HandbookEditorContentPolicy.decision(
            representedItemID: itemID,
            incomingItemID: itemID,
            isSessionOwner: false,
            isFirstResponder: true,
            hasMarkedText: false
        ) == .preserveEditor,
        "仍为 first responder 的正文不能接受模型回写"
    )
    try expect(
        HandbookEditorContentPolicy.decision(
            representedItemID: itemID,
            incomingItemID: itemID,
            isSessionOwner: false,
            isFirstResponder: false,
            hasMarkedText: true
        ) == .preserveEditor,
        "输入法 marked text 存在时不能改写原生文本存储"
    )
    try expect(
        HandbookEditorContentPolicy.decision(
            representedItemID: itemID,
            incomingItemID: itemID,
            isSessionOwner: false,
            isFirstResponder: false,
            hasMarkedText: false
        ) == .synchronizeExternalText,
        "同一手记退出编辑后应允许模型同步"
    )
    try expect(
        HandbookEditorContentPolicy.decision(
            representedItemID: itemID,
            incomingItemID: anotherItemID,
            isSessionOwner: true,
            isFirstResponder: true,
            hasMarkedText: true
        ) == .synchronizeExternalText,
        "切换手记时必须加载新手记正文"
    )
}
```

- [ ] **Step 2: Run the quality compilation and verify RED**

Run in a desktop-permitted shell:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
XDG_CACHE_HOME=/tmp/daily-todos-content-policy-red-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-content-policy-red-cache/clang \
SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-content-policy-red-cache/swift \
./scripts/run_quality_checks.sh /tmp/DailyTodosContentPolicyRedChecks
```

Expected: compilation fails because `HandbookEditorContentPolicy` and
`HandbookEditorContentDecision` do not exist.

- [ ] **Step 3: Add the minimal pure ownership policy**

Create `Sources/DailyTodos/HandbookEditorContentPolicy.swift`:

```swift
import Foundation

enum HandbookEditorContentDecision: Equatable {
    case preserveEditor
    case synchronizeExternalText
}

enum HandbookEditorContentPolicy {
    static func decision(
        representedItemID: UUID,
        incomingItemID: UUID,
        isSessionOwner: Bool,
        isFirstResponder: Bool,
        hasMarkedText: Bool
    ) -> HandbookEditorContentDecision {
        guard representedItemID == incomingItemID else {
            return .synchronizeExternalText
        }
        if isSessionOwner || isFirstResponder || hasMarkedText {
            return .preserveEditor
        }
        return .synchronizeExternalText
    }
}
```

Add `Sources/DailyTodos/HandbookEditorContentPolicy.swift` to
`scripts/run_quality_checks.sh` immediately after
`HandbookEditorFocusPolicy.swift` only after the file exists.

- [ ] **Step 4: Expose logical editor ownership**

Add this method beside `shouldRestore(itemID:focus:)` in
`HandbookEditorSessionController`:

```swift
func ownsActiveEditor(itemID: UUID) -> Bool {
    self.itemID == itemID
        && !isExitPending
}
```

Do not check `preferredFocus` or `window?.isKeyWindow`: moving from body to title
and window deactivation both retain logical ownership until explicit exit.

- [ ] **Step 5: Run policy checks and verify GREEN**

Run Step 2 with cache/output names changed from `red` to `green`.

Expected: exit 0 and `DailyTodosChecks passed`.

- [ ] **Step 6: Review and commit the policy**

Run:

```bash
git diff --check
git diff -- Sources/DailyTodos/HandbookEditorContentPolicy.swift Sources/DailyTodos/HandbookEditorSessionController.swift scripts/run_quality_checks.sh scripts/quality_checks.swift
```

Commit:

```bash
git add Sources/DailyTodos/HandbookEditorContentPolicy.swift Sources/DailyTodos/HandbookEditorSessionController.swift scripts/run_quality_checks.sh scripts/quality_checks.swift
git commit -m "test: define handbook editor content ownership"
```

Expected: one commit containing the pure policy, logical session query, and
executable policy checks, without changing `NSTextView` behavior yet.

---

### Task 2: Protect Marked Text in an AppKit Reconciler

**Files:**
- Create: `Sources/DailyTodos/HandbookNativeTextViewReconciler.swift`
- Modify: `scripts/run_quality_checks.sh:24-29`
- Modify: `scripts/quality_checks.swift:27-36,642-700`

**Interfaces:**
- Consumes: `HandbookEditorContentDecision` from Task 1.
- Produces: `HandbookNativeTextViewReconciler.initialize(_:text:)`.
- Produces: `HandbookNativeTextViewReconciler.reconcile(_:externalText:decision:)`.
- Guarantees: `.preserveEditor` performs no mutation on the native text view;
  `.synchronizeExternalText` replaces and styles external text only when it differs.

- [ ] **Step 1: Add the failing live AppKit check**

Add `try checkHandbookNativeTextViewReconciler()` immediately after the pure
content-policy check, then add:

```swift
@MainActor
func checkHandbookNativeTextViewReconciler() throws {
    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 180))
    textView.isRichText = false
    textView.string = "已有"
    textView.setSelectedRange(NSRange(location: 2, length: 0))
    textView.setMarkedText(
        NSAttributedString(string: "zhong"),
        selectedRange: NSRange(location: 5, length: 0),
        replacementRange: NSRange(location: 2, length: 0)
    )

    let originalIdentity = ObjectIdentifier(textView)
    let originalString = textView.string
    let originalMarkedRange = textView.markedRange()
    let originalSelections = textView.selectedRanges.map(\.rangeValue)
    let originalStorage = NSAttributedString(attributedString: textView.attributedString())

    HandbookNativeTextViewReconciler.reconcile(
        textView,
        externalText: "服务端回写",
        decision: .preserveEditor
    )

    try expect(ObjectIdentifier(textView) == originalIdentity, "模型回写不能替换活动 NSTextView 实例")
    try expect(textView.string == originalString, "模型回写不能替换活动正文")
    try expect(textView.markedRange() == originalMarkedRange, "模型回写不能改变输入法 marked range")
    try expect(textView.selectedRanges.map(\.rangeValue) == originalSelections, "模型回写不能改变活动选区")
    try expect(textView.attributedString().isEqual(to: originalStorage), "模型回写不能改写活动文本存储属性")

    textView.unmarkText()
    HandbookNativeTextViewReconciler.reconcile(
        textView,
        externalText: "离开后同步",
        decision: .synchronizeExternalText
    )

    try expect(textView.string == "离开后同步", "退出编辑后应同步外部正文")
    let font = textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
    try expect(font?.pointSize == 15.5, "外部正文同步后应恢复正文样式")
}
```

- [ ] **Step 2: Run the AppKit check and verify RED**

Run:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
XDG_CACHE_HOME=/tmp/daily-todos-native-reconciler-red-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-native-reconciler-red-cache/clang \
SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-native-reconciler-red-cache/swift \
./scripts/run_quality_checks.sh /tmp/DailyTodosNativeReconcilerRedChecks
```

Expected: compilation fails because `HandbookNativeTextViewReconciler` does not
exist. If the restricted sandbox instead fails the pre-existing pasteboard check,
rerun with desktop permission and retain that distinction in the evidence.

- [ ] **Step 3: Implement the minimal AppKit reconciler**

Create `Sources/DailyTodos/HandbookNativeTextViewReconciler.swift`:

```swift
import AppKit

@MainActor
enum HandbookNativeTextViewReconciler {
    static func initialize(_ textView: NSTextView, text: String) {
        let attributes = editorAttributes()
        textView.font = attributes[.font] as? NSFont
        textView.textColor = attributes[.foregroundColor] as? NSColor
        textView.insertionPointColor = NSColor.controlAccentColor
        textView.typingAttributes = attributes
        textView.string = text
        applyDocumentAttributes(attributes, to: textView)
    }

    static func reconcile(
        _ textView: NSTextView,
        externalText: String,
        decision: HandbookEditorContentDecision
    ) {
        guard decision == .synchronizeExternalText,
              textView.string != externalText
        else { return }

        let textLength = (externalText as NSString).length
        let selections = clampedSelectionRanges(textView.selectedRanges, textLength: textLength)
        let attributes = editorAttributes()

        textView.string = externalText
        textView.insertionPointColor = NSColor.controlAccentColor
        textView.typingAttributes = attributes
        applyDocumentAttributes(attributes, to: textView)
        if !selections.isEmpty {
            textView.selectedRanges = selections
        }
    }

    private static func editorAttributes() -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        return [
            .font: NSFont.systemFont(ofSize: 15.5, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    private static func applyDocumentAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        to textView: NSTextView
    ) {
        let length = (textView.string as NSString).length
        guard length > 0 else { return }
        textView.textStorage?.setAttributes(
            attributes,
            range: NSRange(location: 0, length: length)
        )
    }

    private static func clampedSelectionRanges(
        _ ranges: [NSValue],
        textLength: Int
    ) -> [NSValue] {
        ranges.compactMap { value in
            let range = value.rangeValue
            guard range.location <= textLength else { return nil }
            return NSValue(
                range: NSRange(
                    location: range.location,
                    length: min(range.length, textLength - range.location)
                )
            )
        }
    }
}
```

Add `Sources/DailyTodos/HandbookNativeTextViewReconciler.swift` to
`scripts/run_quality_checks.sh` after `HandbookEditorContentPolicy.swift` only
after the file exists.

- [ ] **Step 4: Run the AppKit check and verify GREEN**

Run Step 2 with cache/output names changed from `red` to `green`, with desktop
permission.

Expected: exit 0 and `DailyTodosChecks passed`; the marked range, selection, text,
and attributed storage assertions all pass.

- [ ] **Step 5: Review and commit the reconciler**

Run:

```bash
git diff --check
git diff -- Sources/DailyTodos/HandbookNativeTextViewReconciler.swift scripts/run_quality_checks.sh scripts/quality_checks.swift
```

Commit:

```bash
git add Sources/DailyTodos/HandbookNativeTextViewReconciler.swift scripts/run_quality_checks.sh scripts/quality_checks.swift
git commit -m "test: protect handbook marked text reconciliation"
```

---

### Task 3: Integrate Ownership Into the SwiftUI Bridge

**Files:**
- Modify: `Sources/DailyTodos/HandbookPastingTextEditor.swift:4-150`
- Modify: `scripts/quality_checks.swift:608-680,1969-2077`

**Interfaces:**
- Consumes: `HandbookEditorContentPolicy.decision(...)` from Task 1.
- Consumes: `HandbookEditorSessionController.ownsActiveEditor(itemID:)` from Task 1.
- Consumes: `HandbookNativeTextViewReconciler.initialize(_:text:)` and `reconcile(_:externalText:decision:)` from Task 2.
- Extends: `HandbookPastingTextEditor.Coordinator` with `representedItemID: UUID`.

- [ ] **Step 1: Add a failing integration guard**

Extend `checkHandbookEditorFocusIntegration()` with a source slice for
`updateNSView`:

```swift
guard let updateStart = editorSource.range(of: "func updateNSView")?.lowerBound,
      let dismantleStart = editorSource.range(
        of: "static func dismantleNSView",
        range: updateStart..<editorSource.endIndex
      )?.lowerBound
else {
    throw CheckFailure.failed("无法定位 HandbookPastingTextEditor.updateNSView")
}
let updateSource = String(editorSource[updateStart..<dismantleStart])

try expect(
    updateSource.contains("HandbookEditorContentPolicy.decision")
        && updateSource.contains("editorSession.ownsActiveEditor")
        && updateSource.contains("HandbookNativeTextViewReconciler.reconcile")
        && !updateSource.contains("textView.string =")
        && !updateSource.contains("textStorage?.setAttributes")
        && !updateSource.contains("applyEditorAttributes"),
    "活动 updateNSView 必须通过所有权策略，不能直接改写正文、全文属性或选区"
)
try expect(
    editorSource.contains("representedItemID")
        && editorSource.contains("HandbookNativeTextViewReconciler.initialize"),
    "原生编辑器必须记录其手记身份并只在创建时无条件初始化"
)
```

- [ ] **Step 2: Run the integration guard and verify RED**

Run:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
XDG_CACHE_HOME=/tmp/daily-todos-editor-integration-red-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-editor-integration-red-cache/clang \
SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-editor-integration-red-cache/swift \
./scripts/run_quality_checks.sh /tmp/DailyTodosEditorIntegrationRedChecks
```

Expected: `DailyTodosChecks failed` with the new ownership integration message,
because `updateNSView` still directly configures and applies attributes.

- [ ] **Step 3: Give the coordinator native note identity**

Change coordinator construction and initialization:

```swift
func makeCoordinator() -> Coordinator {
    Coordinator(parent: self, representedItemID: itemID)
}
```

In `Coordinator`:

```swift
var parent: HandbookPastingTextEditor
var representedItemID: UUID
weak var textView: NSTextView?

init(parent: HandbookPastingTextEditor, representedItemID: UUID) {
    self.parent = parent
    self.representedItemID = representedItemID
}
```

Keep the existing selection recovery, window observer, and paste callback code.

- [ ] **Step 4: Route native initialization and updates through the new boundary**

In `makeNSView`, replace `configure`, direct string assignment, and
`applyEditorAttributes` with:

```swift
context.coordinator.textView = textView
HandbookNativeTextViewReconciler.initialize(textView, text: text)
return scrollView
```

In `updateNSView`, keep coordinator parent assignment, window observation, and
paste callback refresh, then use:

```swift
let decision = HandbookEditorContentPolicy.decision(
    representedItemID: context.coordinator.representedItemID,
    incomingItemID: itemID,
    isSessionOwner: editorSession.ownsActiveEditor(itemID: itemID),
    isFirstResponder: textView.window?.firstResponder === textView,
    hasMarkedText: textView.hasMarkedText()
)
HandbookNativeTextViewReconciler.reconcile(
    textView,
    externalText: text,
    decision: decision
)
if decision == .synchronizeExternalText {
    context.coordinator.representedItemID = itemID
}
```

Retain the existing conditional first-responder recovery after reconciliation.
Delete the now-unused `configure`, `applyEditorAttributes`, and
`clampedSelectionRanges` helpers from `HandbookPastingTextEditor`; those mutations
belong only to the reconciler.

- [ ] **Step 5: Run focused checks and verify GREEN**

Run Step 2 with cache/output names changed from `red` to `green`, with desktop
permission.

Expected: exit 0 and `DailyTodosChecks passed`.

- [ ] **Step 6: Build the complete application**

Run:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
XDG_CACHE_HOME=/tmp/daily-todos-editor-build-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-editor-build-cache/clang \
SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-editor-build-cache/swift \
swift build \
  --disable-sandbox \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  --scratch-path /tmp/DailyTodosEditorBuild
```

Expected: `Build complete!` with exit 0.

- [ ] **Step 7: Review and commit the integration**

Run:

```bash
git diff --check
git diff -- Sources/DailyTodos/HandbookPastingTextEditor.swift scripts/quality_checks.swift
git status --short
```

Confirm no release metadata changed, then commit:

```bash
git add Sources/DailyTodos/HandbookPastingTextEditor.swift scripts/quality_checks.swift
git commit -m "fix: preserve active handbook editor state"
```

---

### Task 4: Verify Packaged Chinese Input Behavior

**Files:**
- Verify only; no source changes expected.

**Interfaces:**
- Consumes: the completed Tasks 1-3 implementation.
- Produces: current evidence for focused checks, full checks, build, packaging,
  native editor identity, and real Chinese input behavior.

- [ ] **Step 1: Run the complete quality suite in the desktop session**

Run:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
XDG_CACHE_HOME=/tmp/daily-todos-v1242-quality-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-v1242-quality-cache/clang \
SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-v1242-quality-cache/swift \
./scripts/run_quality_checks.sh /tmp/DailyTodosV1242Checks
```

Expected: `DailyTodosChecks passed`. A pasteboard failure inside the restricted
sandbox is not a code result; rerun with desktop permission.

- [ ] **Step 2: Repeat the clean full build**

Run the Task 3 Step 6 build with cache and scratch names changed to
`daily-todos-v1242-build-cache` and `/tmp/DailyTodosV1242Build`.

Expected: `Build complete!` with exit 0.

- [ ] **Step 3: Package the application without changing release metadata**

Run:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
XDG_CACHE_HOME=/tmp/daily-todos-v1242-package-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-v1242-package-cache/clang \
SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-v1242-package-cache/swift \
./scripts/package_app.sh
```

Expected: exit 0 and the final output line is an existing `.app` directory.
Record the exact app path and verify its `DailyTodos` binary exists.

- [ ] **Step 4: Run the packaged app and verify the real workflow**

Open the packaged `.app`, select a handbook note, and type Chinese continuously
through at least three 650 ms autosave cycles. Include pauses while marked pinyin
text is visible.

Verify all of the following before release:

- the insertion point remains visible;
- Chinese marked text and candidate selection are not committed or cancelled by
  autosave;
- the selected range does not jump;
- the body remains the keyboard input target;
- the outline does not refresh while typing;
- clicking the title transfers focus without losing the draft;
- clicking the outline or list saves once, refreshes the outline once, and releases
  body focus;
- reopening the note shows the exact saved text.

Expected: the user confirms the previously reproducible interruption no longer
occurs. If it occurs, stop release work, capture lifecycle evidence, and return to
systematic debugging rather than adding another focus workaround.

- [ ] **Step 5: Confirm the feature branch is clean and review-ready**

Run:

```bash
git status --short --branch
git log --oneline origin/main..HEAD
```

Expected: clean worktree with the design, plan, policy, reconciler, and integration
commits only.

---

### Task 5: Review and Ship v1.2.42

**Files:**
- Modify through release script: `Info.plist:21-24`
- Modify through release script: `releases/latest.json`
- Generate: `build/AntOrder-1.2.42.pkg`
- Generate: `build/AntOrder-1.2.42.dmg`

**Interfaces:**
- Consumes: clean verified feature branch and packaged-app user confirmation.
- Produces: release commit, `v1.2.42` tag, branch push, GitHub Release artifacts,
  merged pull request, and updated `origin/main`.

- [ ] **Step 1: Run final code review**

Review `origin/main..HEAD` for behavior regressions, missing tests, unintended
store changes, and violations of the confirmed editor-exit contract. Resolve all
P0/P1 findings and rerun Task 4 checks before release.

- [ ] **Step 2: Verify release inputs**

Run:

```bash
git status --short
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Info.plist
git tag --list v1.2.42
```

Expected: clean worktree, current version `1.2.41`, current build `70`, and no
existing `v1.2.42` tag.

- [ ] **Step 3: Dry-run the release contract**

Run:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
XDG_CACHE_HOME=/tmp/daily-todos-v1242-release-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-v1242-release-cache/clang \
SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-v1242-release-cache/swift \
./scripts/ship_release.sh \
  --version 1.2.42 \
  --build 71 \
  --notes "蚁序 1.2.42：修复手记自动保存回写活动编辑器导致中文输入中断的问题，编辑期间保持光标、选区与输入法组合态，离开编辑器后再同步文字目录。" \
  --dry-run
```

Expected: `Dry run only. No files changed.`

- [ ] **Step 4: Publish and merge the release**

Run the Step 3 command without `--dry-run` and with:

```bash
  --publish \
  --merge-pr
```

Expected:

- quality/build/package commands succeed;
- `Info.plist` becomes `1.2.42` build `71`;
- `releases/latest.json` references the `v1.2.42` package URL;
- release commit `release: ship 1.2.42` is created;
- tag `v1.2.42` and the feature branch are pushed;
- GitHub Release contains both PKG and DMG artifacts;
- the pull request is created and merged into `main`.

- [ ] **Step 5: Verify remote release state and artifacts**

Run:

```bash
gh release view v1.2.42 --json tagName,name,isDraft,isPrerelease,url,assets
gh pr view --json number,state,mergeCommit,url
git fetch origin main --tags
git merge-base --is-ancestor v1.2.42 origin/main
shasum -a 256 build/AntOrder-1.2.42.pkg build/AntOrder-1.2.42.dmg
```

Expected: published non-draft release, merged PR, tag reachable from
`origin/main`, and readable SHA-256 hashes for both local artifacts.

- [ ] **Step 6: Report release result**

Report the exact verification commands and results, PR URL, release URL, artifact
paths and hashes, merged commit, and any signing limitation. Do not claim GUI input
verification unless Task 4 Step 4 was completed in the packaged app.
