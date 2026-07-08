# 手记粘贴图片设计

## 背景

蚁序手记已经支持长文本、Markdown 工具栏和 `HandbookAttachment` 元数据。当前附件只能通过工具栏手动选择文件，正文 `TextEditor` 不能直接处理剪贴板图片。部门经理在会议、调研和业务规则沉淀中经常需要粘贴截图，现有流程需要先另存图片再手动添加附件，打断收集节奏。

本次目标是在手记详情编辑态中支持直接粘贴图片，并保持现有手记 autosave、SQLite 持久化和附件模型稳定。

## 目标

- 当手记正文编辑区获得焦点时，用户可以使用 `Command-V` 粘贴剪贴板中的图片。
- 粘贴后的图片保存到应用私有附件目录，而不是引用剪贴板临时数据。
- 手记正文追加一条 Markdown 图片引用，方便导出、搜索和后续同步理解。
- 手记附件列表同步增加一条 `kind == .image` 的 `HandbookAttachment`，并通过现有 SQLite `attachments_json` 持久化。
- 手记详情中能看到附件区，粘贴成功后用户可以打开或移除图片附件。

## 非目标

- 不实现富文本内联图片编辑器。
- 不改变 `handbook_items` 表结构。
- 不支持从网页 HTML 中抓取远程图片。
- 不处理手记快速收集栏中的图片粘贴。快速收集没有稳定 note id，避免创建孤儿附件。
- 不自动 OCR 图片内容。

## 用户体验

用户在手记详情中选择正文区域并粘贴截图：

1. 应用读取剪贴板中的 PNG、JPEG、TIFF 或通用 image 数据。
2. 图片保存为 `~/Library/Application Support/DailyTodos/HandbookAttachments/<note-id>/<timestamp>-<short-id>.png`。
3. 正文末尾追加 `![图片名](file://...)`，如果正文非空则前后补换行。
4. 工具栏附件计数更新，详情底部显示附件区。
5. 点击附件打开系统 Preview，移除附件只移除引用元数据，不删除磁盘文件。

如果剪贴板没有图片，系统保持现有文本粘贴行为。如果读取或保存失败，显示简短错误提示，正文和附件列表不变。

## 架构

### 图片存储

新增轻量存储工具，例如 `HandbookAttachmentStorage`：

- `defaultRoot()` 复用 `TodoStore` 的应用支持目录规则，根目录为 `DailyTodos/HandbookAttachments`。
- `savePastedImage(_ image: NSImage, noteID: UUID, now: Date = Date()) throws -> HandbookAttachment` 将图片转为 PNG 数据并写入 note 专属目录。
- 文件名使用时间戳和短 UUID，避免覆盖。
- 返回的 `HandbookAttachment` 使用 `kind: .image`、`name` 为文件名、`path` 为本地绝对路径。

### 粘贴处理

在 `HandbookDetailPanel` 中把当前 `item.id` 传给编辑画布或附加 paste command：

- 当 `canvasFocus == .body` 时处理图片粘贴。
- 优先读取 `NSPasteboard.general` 中的 `NSImage` 或常见图片数据类型。
- 成功后更新本地 `bodyText` 和 `attachments`。
- 依靠现有 `.onChange(of: attachments)` 和 `handleBodyTextChange` 触发保存。

正文插入策略保持简单：追加到正文末尾，而不是计算 `TextEditor` 光标位置。SwiftUI `TextEditor` 当前没有稳定的光标 API，追加策略可预测，也不会破坏现有 autosave。

### 附件展示

将现有 `HandbookAttachmentStrip` 接入 `HandbookDetailPanel` 的滚动内容：

- 仅在 `attachments` 非空时展示。
- 编辑态允许删除附件元数据。
- 保持现有 chip 形态，不新增大缩略图，避免压低正文阅读密度。

## 数据流

```text
Command-V
  -> HandbookDetailPanel paste handler
  -> HandbookAttachmentStorage writes PNG file
  -> bodyText append markdown image line
  -> attachments append image metadata
  -> TodoStore.updateHandbookItem
  -> SQLite attachments_json + body persist
```

## 错误处理

- 剪贴板无图片：不拦截，让系统继续走普通文本粘贴。
- 图片无法编码为 PNG：提示“无法读取剪贴板图片”。
- 文件写入失败：提示“保存图片失败”，保留正文和附件原状。
- 重复粘贴同一图片：生成新文件和新附件，符合用户显式操作。

## 测试

先补失败测试，再实现：

1. `HandbookAttachmentStorage` 单元检查：给定 `NSImage` 和临时根目录，能写入 PNG 并返回 `kind == .image` 的附件。
2. Markdown 插入 helper 检查：空正文、已有正文、末尾已有换行时都生成稳定文本。
3. 现有质量门 `scripts/run_quality_checks.sh` 必须继续通过。
4. `swift build` 必须通过，确认 SwiftUI/AppKit API 可编译。

手动验证：

- 运行应用，打开手记详情，在正文粘贴一张截图。
- 确认正文出现图片引用，附件计数增加。
- 重启应用，确认正文引用和附件仍在。
- 点击附件能打开图片。
