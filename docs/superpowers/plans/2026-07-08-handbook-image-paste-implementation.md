# Handbook Image Paste Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users paste clipboard images into an existing handbook note, save the image as a durable local attachment, and append a Markdown image reference to the note body.

**Architecture:** Add a small non-view helper for local attachment storage and Markdown insertion. Wire `HandbookDetailPanel` to handle `Command-V` only when the handbook body is focused, using AppKit pasteboard image reads and existing autosave paths.

**Tech Stack:** Swift 6, SwiftUI, AppKit, SQLite via existing `TodoStore`, current `scripts/run_quality_checks.sh` harness.

## Global Constraints

- Work only in the isolated worktree under `.loop/workspaces/daily-todos-handbook-paste-images/daily-todos`.
- Do not change the `handbook_items` SQLite schema.
- Do not introduce new package dependencies.
- Do not implement rich text inline image editing, OCR, or quick-capture image paste.
- Keep the paste behavior scoped to the handbook detail body focus state.
- Preserve existing handbook autosave behavior and manual attachment picking.

---

### Task 1: Add Testable Attachment Storage And Markdown Helpers

**Files:**
- Create: `Sources/DailyTodos/HandbookAttachmentStorage.swift`
- Modify: `scripts/run_quality_checks.sh`
- Modify: `scripts/quality_checks.swift`

**Interfaces:**
- Produces: `struct HandbookAttachmentStorage`
- Produces: `static func defaultRoot() -> URL`
- Produces: `static func markdownImageLine(for attachment: HandbookAttachment) -> String`
- Produces: `static func appendingMarkdownImage(to body: String, attachment: HandbookAttachment) -> String`
- Produces: `@MainActor func savePastedImage(_ image: NSImage, noteID: UUID, now: Date) throws -> HandbookAttachment`

- [ ] **Step 1: Write the failing tests**

Add `try checkHandbookAttachmentStorage()` to `DailyTodosChecks.main()` before `checkTodoStore()`.

Add `import AppKit` near the top of `scripts/quality_checks.swift` because the test creates an `NSImage`.

Add this test function to `scripts/quality_checks.swift`:

```swift
@MainActor
func checkHandbookAttachmentStorage() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("DailyTodosAttachmentChecks-\(UUID().uuidString)", isDirectory: true)
    let storage = HandbookAttachmentStorage(rootDirectory: root)
    let noteID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    let image = NSImage(size: NSSize(width: 8, height: 8))
    image.lockFocus()
    NSColor.systemTeal.setFill()
    NSRect(x: 0, y: 0, width: 8, height: 8).fill()
    image.unlockFocus()

    let attachment = try storage.savePastedImage(
        image,
        noteID: noteID,
        now: Date(timeIntervalSince1970: 1_777_777_777)
    )

    try expect(attachment.kind == .image, "粘贴图片应保存为 image 附件")
    try expect(attachment.name.hasSuffix(".png"), "粘贴图片应规范化保存为 PNG")
    try expect(attachment.path.contains(noteID.uuidString), "粘贴图片应按手记 ID 分目录保存")
    try expect(FileManager.default.fileExists(atPath: attachment.path), "粘贴图片应写入磁盘")
    try expect(
        HandbookAttachmentStorage.markdownImageLine(for: attachment).contains("![\(attachment.name)](file://"),
        "图片附件应生成 Markdown 图片引用"
    )
    try expect(
        HandbookAttachmentStorage.appendingMarkdownImage(to: "", attachment: attachment)
            == HandbookAttachmentStorage.markdownImageLine(for: attachment),
        "空正文粘贴图片时只插入图片引用"
    )
    try expect(
        HandbookAttachmentStorage.appendingMarkdownImage(to: "会议结论", attachment: attachment)
            == "会议结论\n\n\(HandbookAttachmentStorage.markdownImageLine(for: attachment))",
        "已有正文粘贴图片时应以空行追加图片引用"
    )
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `scripts/run_quality_checks.sh`

Expected: FAIL because `HandbookAttachmentStorage` is not defined or not compiled.

- [ ] **Step 3: Write minimal implementation**

Create `Sources/DailyTodos/HandbookAttachmentStorage.swift` with:

```swift
import AppKit
import Foundation

struct HandbookAttachmentStorage {
    let rootDirectory: URL

    init(rootDirectory: URL = Self.defaultRoot()) {
        self.rootDirectory = rootDirectory
    }

    static func defaultRoot() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return baseURL
            .appendingPathComponent("DailyTodos", isDirectory: true)
            .appendingPathComponent("HandbookAttachments", isDirectory: true)
    }

    @MainActor
    func savePastedImage(_ image: NSImage, noteID: UUID, now: Date = Date()) throws -> HandbookAttachment {
        guard let data = Self.pngData(from: image) else {
            throw HandbookAttachmentStorageError.unreadableImage
        }

        let noteDirectory = rootDirectory.appendingPathComponent(noteID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: noteDirectory, withIntermediateDirectories: true)

        let timestamp = Int(now.timeIntervalSince1970)
        let suffix = UUID().uuidString.prefix(8).lowercased()
        let filename = "pasted-\(timestamp)-\(suffix).png"
        let url = noteDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)

        return HandbookAttachment(kind: .image, name: filename, path: url.path)
    }

    static func markdownImageLine(for attachment: HandbookAttachment) -> String {
        let url = URL(fileURLWithPath: attachment.path).absoluteString
        return "![\(attachment.name)](\(url))"
    }

    static func appendingMarkdownImage(to body: String, attachment: HandbookAttachment) -> String {
        let line = markdownImageLine(for: attachment)
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return line }
        return "\(body.trimmingCharacters(in: .newlines))\n\n\(line)"
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}

enum HandbookAttachmentStorageError: LocalizedError {
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "无法读取剪贴板图片"
        }
    }
}
```

Add `Sources/DailyTodos/HandbookAttachmentStorage.swift` to the `swiftc` file list in `scripts/run_quality_checks.sh`.

- [ ] **Step 4: Run test to verify it passes**

Run: `scripts/run_quality_checks.sh`

Expected: PASS with `DailyTodosChecks passed`.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/DailyTodos/HandbookAttachmentStorage.swift scripts/run_quality_checks.sh scripts/quality_checks.swift
git commit -m "feat: 添加手记图片附件存储"
```

---

### Task 2: Wire Handbook Detail Paste Handling

**Files:**
- Modify: `Sources/DailyTodos/HandbookDetailPanel.swift`
- Modify: `Sources/DailyTodos/HandbookAttachmentViews.swift`

**Interfaces:**
- Consumes: `HandbookAttachmentStorage.savePastedImage(_:noteID:now:)`
- Consumes: `HandbookAttachmentStorage.appendingMarkdownImage(to:attachment:)`
- Produces: focused body paste handling from `HandbookDetailPanel`

- [ ] **Step 1: Write the failing structural test**

Add `try checkHandbookDetailHandlesImagePaste()` to `DailyTodosChecks.main()` near `checkHandbookDetailReconcilesSameItemUpdates()`.

Add this test function to `scripts/quality_checks.swift`:

```swift
func checkHandbookDetailHandlesImagePaste() throws {
    let sourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../Sources/DailyTodos/HandbookDetailPanel.swift")
        .standardizedFileURL
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    try expect(
        source.contains(".onPasteCommand(of: [.image])"),
        "手记详情应在正文焦点内接管图片粘贴命令"
    )
    try expect(
        source.contains("canvasFocus == .body"),
        "图片粘贴必须限制在手记正文焦点中"
    )
    try expect(
        source.contains("HandbookAttachmentStorage.appendingMarkdownImage"),
        "图片粘贴应同步写入正文 Markdown 图片引用"
    )
    try expect(
        source.contains("HandbookAttachmentStrip(attachments: $attachments, isEditing: true)"),
        "手记详情应显示可编辑附件区"
    )
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `scripts/run_quality_checks.sh`

Expected: FAIL with the message that handbook detail does not handle image paste.

- [ ] **Step 3: Write minimal implementation**

In `HandbookDetailPanel`, add:

```swift
@State private var pasteErrorMessage: String?
private let attachmentStorage = HandbookAttachmentStorage()
```

Attach to the `ScrollView` or containing panel:

```swift
.onPasteCommand(of: [.image]) { providers in
    handleImagePaste(providers, for: item)
}
```

Add a small error message below the canvas only when needed:

```swift
if let pasteErrorMessage {
    Text(pasteErrorMessage)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(AppTheme.risk)
        .frame(maxWidth: 880, alignment: .leading)
        .padding(.bottom, 10)
}
```

Show attachments below the outline:

```swift
if !attachments.isEmpty {
    HandbookAttachmentStrip(attachments: $attachments, isEditing: true)
        .frame(maxWidth: 880, alignment: .leading)
        .padding(.bottom, 16)
}
```

Add paste helpers:

```swift
private func handleImagePaste(_ providers: [NSItemProvider], for item: HandbookItem) {
    guard canvasFocus == .body else { return }
    guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSImage.self) }) else { return }

    provider.loadObject(ofClass: NSImage.self) { object, error in
        Task { @MainActor in
            if let error {
                pasteErrorMessage = "保存图片失败：\(error.localizedDescription)"
                return
            }
            guard let image = object as? NSImage else {
                pasteErrorMessage = "无法读取剪贴板图片"
                return
            }
            do {
                let attachment = try attachmentStorage.savePastedImage(image, noteID: item.id)
                attachments.append(attachment)
                bodyText = HandbookAttachmentStorage.appendingMarkdownImage(to: bodyText, attachment: attachment)
                pasteErrorMessage = nil
                canvasFocus = .body
            } catch {
                pasteErrorMessage = "保存图片失败：\(error.localizedDescription)"
            }
        }
    }
}
```

Make `HandbookAttachmentStrip.open(_:)` ignore missing files by returning early if the path is empty or missing.

- [ ] **Step 4: Run test to verify it passes**

Run: `scripts/run_quality_checks.sh`

Expected: PASS with `DailyTodosChecks passed`.

- [ ] **Step 5: Commit**

Run:

```bash
git add Sources/DailyTodos/HandbookDetailPanel.swift Sources/DailyTodos/HandbookAttachmentViews.swift scripts/quality_checks.swift
git commit -m "feat: 支持手记正文粘贴图片"
```

---

### Task 3: Build And Final Verification

**Files:**
- Verify only unless compiler requires scoped fixes.

**Interfaces:**
- Consumes all work from Tasks 1 and 2.
- Produces a buildable, quality-checked feature.

- [ ] **Step 1: Run quality checks**

Run: `scripts/run_quality_checks.sh`

Expected: PASS with `DailyTodosChecks passed`.

- [ ] **Step 2: Run Swift build**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 3: Inspect git diff**

Run: `git diff --stat HEAD~2..HEAD`

Expected: only storage helper, handbook detail/attachment UI, quality checks, and plan/spec docs changed.

- [ ] **Step 4: Document manual QA gap if not run**

If the desktop app is not launched in this session, final response must say manual paste-in-app verification was not run.
