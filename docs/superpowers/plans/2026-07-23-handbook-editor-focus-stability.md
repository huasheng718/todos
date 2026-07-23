# Handbook Editor Focus Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep handbook title and body autosave active without losing the active input cursor, and synchronize the outline only after an explicit click outside the editor region.

**Architecture:** Put focus decisions in a pure Swift policy, and put AppKit mouse classification plus editor-region geometry in a focused session controller. `HandbookDetailPanel` owns the session lifecycle: autosave remains persistence-only, while a type-safe outside-click notification performs one ordered save, outline refresh, and focus exit.

**Tech Stack:** Swift 6, SwiftUI `FocusState`, AppKit `NSTextView` and local event monitoring, Swift Concurrency, source-backed DailyTodos quality checks, Swift Package Manager, GitHub CLI.

## Global Constraints

- Work only in `.loop/workspaces/0FF641E7-3BB5-4E9E-A1E8-D6AEE364925C/daily-todos`.
- Body and title autosave remains debounced at exactly 650 ms.
- Autosave must not clear `canvasFocus`, change first responder, move selection, or refresh the outline.
- The editor region is title, body, toolbar, inline attachment preview, and attachment strip.
- A click inside the editor region keeps the editing session active; title and body may transfer input between each other.
- A click on the outline, handbook list, sidebar, or another module orders persistence before outline refresh and focus clearing.
- A system-generated `textDidEndEditing` must preserve `.body`, the selected ranges, and the current item session.
- Window deactivation suspends physical first responder but does not end the logical editing session.
- Preserve initial outline loading, selected-item ownership checks, and cooperative cancellation in `refreshOutline`.
- Do not add dependencies or change the synchronous `onUpdate` callback contract.
- Use `/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk` with all caches and build output under `/tmp`.
- Release as `v1.2.41`, build `70`, only after the focused checks, complete quality suite, and Swift build pass.

## File Structure

- Create `Sources/DailyTodos/HandbookEditorFocusPolicy.swift`: pure focus event and decision types, including the shared `HandbookCanvasFocus` enum.
- Create `Sources/DailyTodos/HandbookEditorSessionController.swift`: editor-region tracking, window-local mouse classification, session state, and outside-click notification.
- Modify `Sources/DailyTodos/HandbookPastingTextEditor.swift`: consult the policy instead of clearing focus unconditionally, and restore body selection and first responder for non-exit events.
- Modify `Sources/DailyTodos/HandbookBodyEditorSection.swift`: pass item/session identity to the AppKit editor and register the body region.
- Modify `Sources/DailyTodos/HandbookEditableCanvas.swift`: register title and inline attachment regions.
- Modify `Sources/DailyTodos/HandbookDetailPanel.swift`: own the session, register toolbar/attachment regions, and make explicit outside click the only outline-refreshing exit path.
- Modify `scripts/quality_checks.swift`: executable policy tests and source-level integration guards.
- Modify `scripts/run_quality_checks.sh`: compile the pure focus policy into the quality-check executable.
- Modify through `scripts/ship_release.sh`: `Info.plist` and `releases/latest.json` in the release commit.

---

### Task 1: Define and Test the Pure Focus Policy

**Files:**
- Create: `Sources/DailyTodos/HandbookEditorFocusPolicy.swift`
- Modify: `Sources/DailyTodos/HandbookDetailPanel.swift:358-361`
- Modify: `scripts/quality_checks.swift:26-36,568-585`
- Modify: `scripts/run_quality_checks.sh:17-20`

**Interfaces:**
- Produces: `HandbookCanvasFocus` with `.title` and `.body`.
- Produces: `HandbookEditorFocusEvent` with `.input(HandbookCanvasFocus)`, `.editorControl`, `.outside`, and `.system`.
- Produces: `HandbookEditorFocusDecision` with `.transfer(HandbookCanvasFocus)`, `.preserve(HandbookCanvasFocus)`, and `.exit`.
- Produces: `HandbookEditorFocusPolicy.decision(current:event:) -> HandbookEditorFocusDecision`.
- Consumes: no UI or AppKit state; this file must remain compilable by the lightweight quality-check executable.

- [ ] **Step 1: Add failing executable policy checks**

Add `try checkHandbookEditorFocusPolicy()` immediately after the existing
`checkHandbookEditorSyncPolicy()` call in `scripts/quality_checks.swift`, then add:

```swift
func checkHandbookEditorFocusPolicy() throws {
    try expect(
        HandbookEditorFocusPolicy.decision(current: .body, event: .system) == .preserve(.body),
        "系统性正文结束编辑必须保留正文焦点"
    )
    try expect(
        HandbookEditorFocusPolicy.decision(current: .body, event: .editorControl) == .preserve(.body),
        "工具栏或附件交互必须保留正文焦点"
    )
    try expect(
        HandbookEditorFocusPolicy.decision(current: .body, event: .input(.title)) == .transfer(.title),
        "正文点击标题时应转移输入目标但保留编辑会话"
    )
    try expect(
        HandbookEditorFocusPolicy.decision(current: .title, event: .input(.body)) == .transfer(.body),
        "标题点击正文时应转移输入目标但保留编辑会话"
    )
    try expect(
        HandbookEditorFocusPolicy.decision(current: .body, event: .outside) == .exit,
        "只有编辑区外点击才能退出编辑会话"
    )
}
```

- [ ] **Step 2: Run the quality check and verify RED**

Run:

```bash
env \
  SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  XDG_CACHE_HOME=/tmp/daily-todos-focus-policy-red-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-focus-policy-red-cache/clang \
  SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-focus-policy-red-cache/swift \
  ./scripts/run_quality_checks.sh /tmp/DailyTodosFocusPolicyRedChecks
```

Expected: compilation fails because `HandbookEditorFocusPolicy`,
`HandbookEditorFocusEvent`, and `HandbookEditorFocusDecision` do not exist.

- [ ] **Step 3: Add the minimal pure policy implementation**

Create `Sources/DailyTodos/HandbookEditorFocusPolicy.swift`:

```swift
enum HandbookCanvasFocus: Hashable {
    case title
    case body
}

enum HandbookEditorFocusEvent: Equatable {
    case input(HandbookCanvasFocus)
    case editorControl
    case outside
    case system
}

enum HandbookEditorFocusDecision: Equatable {
    case transfer(HandbookCanvasFocus)
    case preserve(HandbookCanvasFocus)
    case exit
}

enum HandbookEditorFocusPolicy {
    static func decision(
        current: HandbookCanvasFocus,
        event: HandbookEditorFocusEvent
    ) -> HandbookEditorFocusDecision {
        switch event {
        case let .input(target):
            return .transfer(target)
        case .editorControl, .system:
            return .preserve(current)
        case .outside:
            return .exit
        }
    }
}
```

Delete the old `HandbookCanvasFocus` declaration from the bottom of
`HandbookDetailPanel.swift`. Add the new file to `scripts/run_quality_checks.sh`
immediately after `HandbookEditorSyncPolicy.swift`:

```bash
  Sources/DailyTodos/HandbookEditorSyncPolicy.swift \
  Sources/DailyTodos/HandbookEditorFocusPolicy.swift \
  Sources/DailyTodos/HandbookAttachmentStorage.swift \
```

- [ ] **Step 4: Run the quality check and verify GREEN**

Run the Step 2 command with cache/output names changed from `red` to `green`.

Expected: exit 0 with final output `DailyTodosChecks passed`.

- [ ] **Step 5: Review and commit the policy**

Run:

```bash
git diff --check
git diff -- Sources/DailyTodos/HandbookEditorFocusPolicy.swift Sources/DailyTodos/HandbookDetailPanel.swift scripts/quality_checks.swift scripts/run_quality_checks.sh
```

Commit:

```bash
git add Sources/DailyTodos/HandbookEditorFocusPolicy.swift Sources/DailyTodos/HandbookDetailPanel.swift scripts/quality_checks.swift scripts/run_quality_checks.sh
git commit -m "test: define handbook editor focus policy"
```

Expected: one commit containing the pure policy and its executable checks, with no
behavioral UI integration yet.

---

### Task 2: Integrate Explicit Editor Sessions and Focus Recovery

**Files:**
- Create: `Sources/DailyTodos/HandbookEditorSessionController.swift`
- Modify: `Sources/DailyTodos/HandbookPastingTextEditor.swift:4-129`
- Modify: `Sources/DailyTodos/HandbookBodyEditorSection.swift:48-115`
- Modify: `Sources/DailyTodos/HandbookEditableCanvas.swift:4-31`
- Modify: `Sources/DailyTodos/HandbookDetailPanel.swift:9-164,250-287`
- Modify: `scripts/quality_checks.swift:1927-2016`

**Interfaces:**
- Consumes: Task 1's `HandbookEditorFocusPolicy` and `HandbookCanvasFocus`.
- Produces: `HandbookEditorRegionRole` with `.title`, `.body`, and `.control`.
- Produces: `HandbookEditorSessionController.begin(itemID:focus:)`, `finish(itemID:)`, `cancel()`, `focusEventForCurrentTurn()`, and `shouldRestore(itemID:focus:)`.
- Produces: `View.handbookEditorRegion(_:session:)` for window-coordinate region registration.
- Produces: `Notification.Name.handbookEditorDidRequestExit`, posted synchronously with `userInfo["itemID"]` before the original outside mouse event continues.

- [ ] **Step 1: Add a failing integration guard**

Update `checkHandbookOutlineRefreshIsolation()` so the old body-blur assertion is
replaced with the explicit-exit expectation:

```swift
try expect(
    detailSource.contains("private func endEditingSession(for item: HandbookItem)")
        && detailSource.contains("submitEdit(for: item, force: true, outlineRefreshPolicy: .refreshOutline)")
        && !detailSource.contains("if oldValue == .body && newValue != .body"),
    "文字目录只能在显式编辑会话退出时同步"
)
```

Add a new `checkHandbookEditorFocusIntegration()` call next to the policy check and
define:

```swift
func checkHandbookEditorFocusIntegration() throws {
    let sessionSource = try sourceFile("Sources/DailyTodos/HandbookEditorSessionController.swift")
    let detailSource = try sourceFile("Sources/DailyTodos/HandbookDetailPanel.swift")
    let editorSource = try sourceFile("Sources/DailyTodos/HandbookPastingTextEditor.swift")
    let bodySource = try sourceFile("Sources/DailyTodos/HandbookBodyEditorSection.swift")
    let canvasSource = try sourceFile("Sources/DailyTodos/HandbookEditableCanvas.swift")

    try expect(
        sessionSource.contains("NSEvent.addLocalMonitorForEvents")
            && sessionSource.contains("NotificationCenter.default.post")
            && sessionSource.contains("focusEvent == .outside")
            && sessionSource.contains("DispatchQueue.main.async"),
        "编辑会话必须在当前事件轮次分类外部点击，并及时清除过期点击意图"
    )
    try expect(
        !editorSource.contains("parent.focusedField.wrappedValue = nil")
            && editorSource.contains("HandbookEditorFocusPolicy.decision")
            && editorSource.contains("restoreBodyFocus"),
        "NSTextView 结束编辑必须通过策略恢复焦点，不能无条件清空"
    )
    try expect(
        detailSource.contains("handbookEditorDidRequestExit")
            && detailSource.contains("endEditingSession(for: item)")
            && detailSource.contains("editorSession.finish(itemID: item.id)")
            && detailSource.contains("canvasFocus = nil"),
        "外部点击必须由详情面板按保存、目录同步、会话结束和清焦点顺序处理"
    )
    try expect(
        bodySource.contains("handbookEditorRegion(.body, session: editorSession)")
            && canvasSource.contains("handbookEditorRegion(.title, session: editorSession)")
            && detailSource.components(separatedBy: "handbookEditorRegion(.control, session: editorSession)").count >= 3,
        "标题、正文、工具栏和附件区必须注册为编辑会话内部区域"
    )
}
```

- [ ] **Step 2: Run the quality check and verify RED**

Run:

```bash
env \
  SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  XDG_CACHE_HOME=/tmp/daily-todos-focus-integration-red-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-focus-integration-red-cache/clang \
  SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-focus-integration-red-cache/swift \
  ./scripts/run_quality_checks.sh /tmp/DailyTodosFocusIntegrationRedChecks
```

Expected: FAIL because `HandbookEditorSessionController.swift` is absent and the
current coordinator still contains `parent.focusedField.wrappedValue = nil`.

- [ ] **Step 3: Create the AppKit session controller and region tracker**

Create `Sources/DailyTodos/HandbookEditorSessionController.swift` with these
elements:

```swift
import AppKit
import SwiftUI

enum HandbookEditorRegionRole: Hashable {
    case title
    case body
    case control
}

extension Notification.Name {
    static let handbookEditorDidRequestExit = Notification.Name("HandbookEditorDidRequestExit")
}

@MainActor
final class HandbookEditorSessionController {
    private struct Region {
        let role: HandbookEditorRegionRole
        let frame: NSRect
    }

    private(set) var itemID: UUID?
    private(set) var preferredFocus: HandbookCanvasFocus?
    private(set) var isExitPending = false

    private weak var window: NSWindow?
    private var regions: [UUID: Region] = [:]
    private var monitor: Any?
    private var currentFocusEvent: HandbookEditorFocusEvent = .system
    private var eventGeneration = 0

    func begin(itemID: UUID, focus: HandbookCanvasFocus) {
        self.itemID = itemID
        preferredFocus = focus
        isExitPending = false
        installMonitorIfNeeded()
    }

    func finish(itemID: UUID) {
        guard self.itemID == itemID else { return }
        self.itemID = nil
        preferredFocus = nil
        isExitPending = false
        currentFocusEvent = .system
        removeMonitor()
    }

    func cancel() {
        itemID = nil
        preferredFocus = nil
        isExitPending = false
        currentFocusEvent = .system
        regions.removeAll()
        window = nil
        removeMonitor()
    }

    func focusEventForCurrentTurn() -> HandbookEditorFocusEvent {
        currentFocusEvent
    }

    func shouldRestore(itemID: UUID, focus: HandbookCanvasFocus) -> Bool {
        self.itemID == itemID
            && preferredFocus == focus
            && !isExitPending
            && (window?.isKeyWindow ?? false)
    }

    fileprivate func register(
        id: UUID,
        role: HandbookEditorRegionRole,
        frame: NSRect,
        window newWindow: NSWindow
    ) {
        if window !== newWindow {
            removeMonitor()
            regions.removeAll()
            window = newWindow
        }
        regions[id] = Region(role: role, frame: frame)
        installMonitorIfNeeded()
    }

    fileprivate func unregister(id: UUID) {
        regions[id] = nil
    }

    private var hasValidGeometry: Bool {
        let roles = Set(regions.values.map(\.role))
        return roles.contains(.title) && roles.contains(.body) && roles.contains(.control)
    }

    private func installMonitorIfNeeded() {
        guard monitor == nil, itemID != nil, window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleMouseDown(event)
            }
            return event
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let itemID else { return }
        let focusEvent = classify(event)
        rememberForCurrentTurn(focusEvent)
        guard focusEvent == .outside, !isExitPending else { return }

        isExitPending = true
        NotificationCenter.default.post(
            name: .handbookEditorDidRequestExit,
            object: self,
            userInfo: ["itemID": itemID]
        )
    }

    private func classify(_ event: NSEvent) -> HandbookEditorFocusEvent {
        guard let window, hasValidGeometry else { return .system }
        guard event.window === window else { return .outside }

        let location = event.locationInWindow
        let matchingRoles = regions.values.compactMap { region in
            region.frame.contains(location) ? region.role : nil
        }
        if matchingRoles.contains(.title) { return .input(.title) }
        if matchingRoles.contains(.body) { return .input(.body) }
        if matchingRoles.contains(.control) { return .editorControl }
        return .outside
    }

    private func rememberForCurrentTurn(_ event: HandbookEditorFocusEvent) {
        eventGeneration += 1
        let generation = eventGeneration
        currentFocusEvent = event
        DispatchQueue.main.async { [weak self] in
            guard let self, self.eventGeneration == generation, !self.isExitPending else { return }
            self.currentFocusEvent = .system
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

private struct HandbookEditorRegionModifier: ViewModifier {
    let role: HandbookEditorRegionRole
    let session: HandbookEditorSessionController
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content.background {
            HandbookEditorRegionReader(id: id, role: role, session: session)
        }
    }
}

private struct HandbookEditorRegionReader: NSViewRepresentable {
    let id: UUID
    let role: HandbookEditorRegionRole
    let session: HandbookEditorSessionController

    func makeNSView(context: Context) -> HandbookEditorRegionTrackingView {
        HandbookEditorRegionTrackingView(id: id, role: role, session: session)
    }

    func updateNSView(_ view: HandbookEditorRegionTrackingView, context: Context) {
        view.configure(id: id, role: role, session: session)
        view.publishFrame()
    }

    static func dismantleNSView(_ view: HandbookEditorRegionTrackingView, coordinator: Void) {
        view.unregister()
    }
}

@MainActor
private final class HandbookEditorRegionTrackingView: NSView {
    private var id: UUID
    private var role: HandbookEditorRegionRole
    private var session: HandbookEditorSessionController

    init(id: UUID, role: HandbookEditorRegionRole, session: HandbookEditorSessionController) {
        self.id = id
        self.role = role
        self.session = session
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(id: UUID, role: HandbookEditorRegionRole, session: HandbookEditorSessionController) {
        if self.id != id || self.session !== session {
            self.session.unregister(id: self.id)
        }
        self.id = id
        self.role = role
        self.session = session
    }

    override func layout() {
        super.layout()
        publishFrame()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        publishFrame()
    }

    func publishFrame() {
        guard let window else { return }
        session.register(id: id, role: role, frame: convert(bounds, to: nil), window: window)
    }

    func unregister() {
        session.unregister(id: id)
    }
}

extension View {
    func handbookEditorRegion(
        _ role: HandbookEditorRegionRole,
        session: HandbookEditorSessionController
    ) -> some View {
        modifier(HandbookEditorRegionModifier(role: role, session: session))
    }
}
```

- [ ] **Step 4: Route `NSTextView` end-editing through the policy**

Place `itemID` and `editorSession` between the text binding and focus binding in
`HandbookPastingTextEditor`:

```swift
@Binding var text: String
let itemID: UUID
let editorSession: HandbookEditorSessionController
var focusedField: FocusState<HandbookCanvasFocus?>.Binding
let onPasteImage: (NSImage) -> Void
```

In `updateNSView`, call `context.coordinator.observeWindow(textView.window)` after
updating `parent`. Replace the coordinator's begin/end methods and add recovery:

```swift
func textDidBeginEditing(_ notification: Notification) {
    observeWindow(textView?.window)
    parent.editorSession.begin(itemID: parent.itemID, focus: .body)
    parent.focusedField.wrappedValue = .body
}

func textDidEndEditing(_ notification: Notification) {
    if let textView = notification.object as? NSTextView {
        lastSelectionRanges = textView.selectedRanges
    }
    let event = parent.editorSession.focusEventForCurrentTurn()
    switch HandbookEditorFocusPolicy.decision(current: .body, event: event) {
    case let .transfer(target):
        parent.focusedField.wrappedValue = target
    case .preserve:
        restoreBodyFocus()
    case .exit:
        break
    }
}

private var lastSelectionRanges: [NSValue] = []
private var observedWindow: NSWindow?
private var didBecomeKeyObserver: NSObjectProtocol?

func observeWindow(_ window: NSWindow?) {
    guard observedWindow !== window else { return }
    if let didBecomeKeyObserver {
        NotificationCenter.default.removeObserver(didBecomeKeyObserver)
    }
    observedWindow = window
    guard let window else {
        didBecomeKeyObserver = nil
        return
    }
    didBecomeKeyObserver = NotificationCenter.default.addObserver(
        forName: NSWindow.didBecomeKeyNotification,
        object: window,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor in
            self?.restoreBodyFocus()
        }
    }
}

private func restoreBodyFocus() {
    let itemID = parent.itemID
    Task { @MainActor [weak self, weak textView] in
        await Task.yield()
        guard let self,
              self.parent.editorSession.shouldRestore(itemID: itemID, focus: .body),
              let textView,
              let window = textView.window
        else { return }
        self.parent.focusedField.wrappedValue = .body
        window.makeFirstResponder(textView)
        let ranges = self.parent.clampedSelectionRanges(
            self.lastSelectionRanges,
            textLength: (textView.string as NSString).length
        )
        if !ranges.isEmpty {
            textView.selectedRanges = ranges
        }
    }
}

deinit {
    if let didBecomeKeyObserver {
        NotificationCenter.default.removeObserver(didBecomeKeyObserver)
    }
}
```

The existing `updateNSView` first-responder restoration remains as an additional
same-focus safeguard. It must continue to preserve clamped selected ranges when the
bound string changes.

- [ ] **Step 5: Pass session identity and register internal regions**

Add these properties and initializer parameters to `HandbookBodyEditorSection`:

```swift
let itemID: UUID
let editorSession: HandbookEditorSessionController
```

Replace its initializer signature and add the two assignments while retaining the
existing assignments:

```swift
init(
    seed: String,
    itemID: UUID,
    hasImageAttachments: Bool,
    focusedField: FocusState<HandbookCanvasFocus?>.Binding,
    editorSession: HandbookEditorSessionController,
    bridge: HandbookEditorBridge,
    editorState: HandbookEditorState,
    onPasteImage: @escaping (NSImage) -> Void,
    onChange: @escaping (String) -> Void
) {
    self.itemID = itemID
    self.hasImageAttachments = hasImageAttachments
    self.focusedField = focusedField
    self.editorSession = editorSession
    self.bridge = bridge
    self.editorState = editorState
    self.onPasteImage = onPasteImage
    self.onChange = onChange
    _text = State(initialValue: seed)
}
```

Replace the body editor construction with:

```swift
HandbookPastingTextEditor(
    text: $text,
    itemID: itemID,
    editorSession: editorSession,
    focusedField: focusedField,
    onPasteImage: onPasteImage
)
```

Mark the existing `ZStack` after its closing brace and before `.onAppear`:

```swift
.handbookEditorRegion(.body, session: editorSession)
```

Add `let editorSession: HandbookEditorSessionController` immediately after
`formattedDate` in `HandbookEditableCanvas`. Mark the title `TextField` with:

```swift
.handbookEditorRegion(.title, session: editorSession)
```

Mark `HandbookInlineImagePreviewList` with:

```swift
.handbookEditorRegion(.control, session: editorSession)
```

Update the two detail-panel constructions exactly as follows, preserving their
other arguments:

```swift
HandbookEditableCanvas(
    category: $category,
    folder: $folder,
    title: $title,
    attachments: $attachments,
    focusedField: $canvasFocus,
    editorState: editorState,
    formattedDate: item.createdAt.formatted(.dateTime.year().month().day().hour().minute()),
    editorSession: editorSession
)

HandbookBodyEditorSection(
    seed: seededBody,
    itemID: item.id,
    hasImageAttachments: attachments.contains { $0.kind == .image },
    focusedField: $canvasFocus,
    editorSession: editorSession,
    bridge: bodyBridge,
    editorState: editorState,
    onPasteImage: { image in
        handlePastedImage(image, for: item)
    },
    onChange: { handleBodyTextChange($0, for: item) }
)
```

- [ ] **Step 6: Make the detail panel own explicit exit ordering**

Add this state next to `editorState`:

```swift
@State private var editorSession = HandbookEditorSessionController()
```

Pass `editorSession` to `HandbookEditableCanvas` and pass both `item.id` and
`editorSession` to `HandbookBodyEditorSection`. Mark the toolbar and bottom
attachment strip:

```swift
.handbookEditorRegion(.control, session: editorSession)
```

Attach this receiver to the root panel after `.onAppear`:

```swift
.onReceive(NotificationCenter.default.publisher(for: .handbookEditorDidRequestExit)) { notification in
    guard let source = notification.object as? HandbookEditorSessionController,
          source === editorSession,
          let requestedItemID = notification.userInfo?["itemID"] as? UUID,
          requestedItemID == item?.id,
          let item
    else { return }
    endEditingSession(for: item)
}
.onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
    guard let item,
          let preferredFocus = editorSession.preferredFocus,
          editorSession.shouldRestore(itemID: item.id, focus: preferredFocus)
    else { return }
    canvasFocus = preferredFocus
}
.onDisappear {
    editorSession.cancel()
}
```

Replace the body-blur focus handler with session lifecycle handling:

```swift
.onChange(of: canvasFocus) { oldValue, newValue in
    guard !isSyncingDraft else { return }
    if let newValue {
        editorSession.begin(itemID: item.id, focus: newValue)
    } else if let oldValue,
              editorSession.shouldRestore(itemID: item.id, focus: oldValue) {
        Task { @MainActor in
            await Task.yield()
            guard self.item?.id == item.id,
                  editorSession.shouldRestore(itemID: item.id, focus: oldValue)
            else { return }
            canvasFocus = oldValue
        }
    }
}
```

Add the explicit exit method immediately before `submitEdit`:

```swift
private func endEditingSession(for item: HandbookItem) {
    guard editorSession.itemID == item.id, editorSession.isExitPending else { return }
    submitEdit(for: item, force: true, outlineRefreshPolicy: .refreshOutline)
    editorSession.finish(itemID: item.id)
    canvasFocus = nil
}
```

When selection changes to a different item, call
`editorSession.finish(itemID: oldValue.id)` before the existing persistence call.
This is a lifecycle cleanup, not an outline refresh; explicit outside click already
saved the latest snapshot, and the subsequent persistence-only call remains safe.

- [ ] **Step 7: Run focused checks and resolve compile-only API mismatches**

Run the Step 2 quality command with `red` changed to `green`, then run:

```bash
env \
  SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  XDG_CACHE_HOME=/tmp/daily-todos-focus-compile-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-focus-compile-cache/clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/tmp/daily-todos-focus-compile-cache/swiftpm \
  swift build \
    --disable-sandbox \
    --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
    --scratch-path /tmp/daily-todos-focus-compile-build
```

Expected: quality output `DailyTodosChecks passed` and Swift output
`Build complete!`. Limit any compatibility edits to actor annotations, AppKit
observer cleanup, or exact `NSViewRepresentable` signatures; do not weaken policy
or source guards.

- [ ] **Step 8: Review ordering and commit the integration**

Run:

```bash
git diff --check
git diff -- Sources/DailyTodos/HandbookEditorSessionController.swift Sources/DailyTodos/HandbookPastingTextEditor.swift Sources/DailyTodos/HandbookBodyEditorSection.swift Sources/DailyTodos/HandbookEditableCanvas.swift Sources/DailyTodos/HandbookDetailPanel.swift scripts/quality_checks.swift
```

Confirm:

- there is no `parent.focusedField.wrappedValue = nil` in the coordinator;
- autosave still calls `submitEdit(for: item)` without refresh policy;
- `.refreshOutline` is requested only by `endEditingSession`;
- the outside notification is posted before the original event returns;
- recovery checks both item ID and session state;
- `refreshOutline` still checks cancellation and selected item ID.

Commit:

```bash
git add Sources/DailyTodos/HandbookEditorSessionController.swift Sources/DailyTodos/HandbookPastingTextEditor.swift Sources/DailyTodos/HandbookBodyEditorSection.swift Sources/DailyTodos/HandbookEditableCanvas.swift Sources/DailyTodos/HandbookDetailPanel.swift scripts/quality_checks.swift
git commit -m "fix: preserve handbook editor focus during autosave"
```

Expected: one integration commit containing the production behavior and its source
regression guard.

---

### Task 3: Verify and Release v1.2.41

**Files:**
- Verify: all Task 1 and Task 2 source files.
- Modify through release script: `Info.plist`.
- Modify through release script: `releases/latest.json`.
- Produce: `build/AntOrder-1.2.41.pkg`.
- Produce: `build/AntOrder-1.2.41.dmg`.

**Interfaces:**
- Consumes: committed Tasks 1 and 2 plus `scripts/ship_release.sh`.
- Produces: feature and release commits, tag `v1.2.41`, GitHub Release assets, a merged pull request, and updated `origin/main`.

- [ ] **Step 1: Run the complete quality suite from a clean tree**

Run:

```bash
env \
  SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  XDG_CACHE_HOME=/tmp/daily-todos-v1241-quality-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-v1241-quality-cache/clang \
  SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-v1241-quality-cache/swift \
  ./scripts/run_quality_checks.sh /tmp/DailyTodosV1241Checks
```

Expected: exit 0 with `DailyTodosChecks passed`. If the outer sandbox denies the
named-pasteboard AppKit check, rerun this exact command with approved desktop access;
do not remove or bypass the check.

- [ ] **Step 2: Run the compatible-SDK Swift build**

Run:

```bash
env \
  SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  XDG_CACHE_HOME=/tmp/daily-todos-v1241-build-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-v1241-build-cache/clang \
  SWIFTPM_MODULECACHE_OVERRIDE=/tmp/daily-todos-v1241-build-cache/swiftpm \
  swift build \
    --disable-sandbox \
    --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
    --scratch-path /tmp/daily-todos-v1241-build
```

Expected: exit 0 with `Build complete!`.

- [ ] **Step 3: Verify release inputs with a dry run**

Run:

```bash
git status --short --branch
git log --oneline origin/main..HEAD
./scripts/ship_release.sh \
  --version 1.2.41 \
  --build 70 \
  --notes "修复手记自动保存和界面回写导致输入光标失焦的问题；仅在用户点击编辑区外时退出编辑并同步文字目录。" \
  --dry-run
```

Expected: clean tree; design, plan, policy, and integration commits above
`origin/main`; `Preparing 蚁序 1.2.41 (build 70)`; and
`Dry run only. No files changed.`.

- [ ] **Step 4: Publish, package, create the release, and merge the PR**

Run:

```bash
env \
  SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  XDG_CACHE_HOME=/tmp/daily-todos-v1241-release-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-v1241-release-cache/clang \
  SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-v1241-release-cache/swift \
  ./scripts/ship_release.sh \
    --version 1.2.41 \
    --build 70 \
    --notes "修复手记自动保存和界面回写导致输入光标失焦的问题；仅在用户点击编辑区外时退出编辑并同步文字目录。" \
    --publish \
    --merge-pr
```

Expected:

- release commit `release: ship 1.2.41`;
- tag `v1.2.41` pushed;
- `build/AntOrder-1.2.41.pkg` and `build/AntOrder-1.2.41.dmg` uploaded;
- GitHub Release `蚁序 1.2.41` created;
- pull request created and merged into `main`;
- remote feature branch removed by the release script.

- [ ] **Step 5: Read back the published state**

Run:

```bash
git fetch origin --prune
git log -3 --oneline --decorate origin/main
gh release view v1.2.41 --json name,tagName,url,assets
gh pr list --state merged --head codex/daily-todos-editor-focus-stability --json number,title,url,mergedAt
shasum -a 256 build/AntOrder-1.2.41.pkg build/AntOrder-1.2.41.dmg
hdiutil verify build/AntOrder-1.2.41.dmg
```

Expected: `origin/main` contains the merged release branch; release `v1.2.41`
contains both assets; the PR is merged; local hashes are printed; and `hdiutil`
reports the DMG is valid. If verification reports `resource temporarily
unavailable`, inspect mounted images, detach only the matching DailyTodos image, and
rerun verification.
