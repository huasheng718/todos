import AppKit
import SwiftUI

private enum HandbookOutlineRefreshPolicy {
    case preserveOutline
    case refreshOutline
}

struct HandbookDetailPanel: View {
    let item: HandbookItem?
    let onUpdate: (HandbookItem, HandbookCategory, String, String, String, [HandbookAttachment]) -> Void
    let onDelete: (HandbookItem) -> Void

    @State private var category: HandbookCategory = .businessRule
    @State private var folder = ""
    @State private var title = ""
    @State private var attachments: [HandbookAttachment] = []
    @State private var outlineState = HandbookOutlineState()
    @State private var isSyncingDraft = false
    @State private var bodyBridge = HandbookEditorBridge()
    @State private var seededBody = ""
    @State private var bodyEditorResetID = UUID()
    @State private var editorState = HandbookEditorState()
    @State private var editorSession = HandbookEditorSessionController()
    @State private var pasteErrorMessage: String?
    @FocusState private var canvasFocus: HandbookCanvasFocus?

    private let attachmentStorage = HandbookAttachmentStorage()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let item {
                canvasPanel(for: item)
                    .transition(AppMotion.inlineTransition)
            } else {
                detailPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.workSurface)
        .onChange(of: item) { oldValue, newValue in
            if oldValue?.id == newValue?.id {
                if let newValue {
                    syncDraft(
                        with: newValue,
                        preservesLocalTextEdits: HandbookEditorSyncPolicy.preservesLocalTextEditsForSameItemUpdate(
                            isDirty: editorState.isDirty,
                            isEditorFocused: canvasFocus != nil
                        )
                    )
                } else {
                    editorState.isDirty = false
                }
                return
            }
            if let oldValue {
                editorSession.finish(itemID: oldValue.id)
                submitEdit(for: oldValue, force: true)
            }
            syncDraft(with: newValue)
            if let newValue {
                focusBodyAfterItemSelection(newValue.id)
            }
            editorState.isDirty = false
        }
        .onAppear {
            syncDraft(with: item)
        }
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
    }

    private func canvasPanel(for item: HandbookItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Spacer(minLength: 0)

                HandbookEditorToolbar(
                    bridge: bodyBridge,
                    attachments: $attachments,
                    focusedField: $canvasFocus
                )
                .handbookEditorRegion(.control, session: editorSession)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .frame(height: 52)
            .background(AppTheme.workSurface)

            Divider()
                .overlay(AppTheme.hairline.opacity(0.60))

            ScrollView {
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
                .frame(maxWidth: 880, alignment: .leading)
                .padding(.bottom, 16)

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
                .id(bodyEditorResetID)
                .frame(maxWidth: 880, alignment: .leading)
                .padding(.bottom, 16)

                if let pasteErrorMessage {
                    Text(pasteErrorMessage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.workspaceTokens.danger)
                        .frame(maxWidth: 880, alignment: .leading)
                        .padding(.bottom, 10)
                }

                HandbookOutlineContainer(outlineState: outlineState, itemID: item.id)

                if !attachments.isEmpty {
                    HandbookAttachmentStrip(attachments: $attachments, isEditing: true)
                        .handbookEditorRegion(.control, session: editorSession)
                        .frame(maxWidth: 880, alignment: .leading)
                        .padding(.bottom, 16)
                }
            }
            .onChange(of: attachments) { _, _ in
                guard !isSyncingDraft else { return }
                editorState.isDirty = computeIsDirty(comparedTo: item)
                submitEdit(for: item, force: true)
            }
            .onChange(of: category) { _, _ in
                guard !isSyncingDraft else { return }
                editorState.isDirty = computeIsDirty(comparedTo: item)
                submitEdit(for: item, force: true)
            }
            .onChange(of: folder) { _, _ in
                guard !isSyncingDraft else { return }
                editorState.isDirty = computeIsDirty(comparedTo: item)
                submitEdit(for: item, force: true)
            }
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
            .onChange(of: title) { _, _ in
                guard !isSyncingDraft else { return }
                editorState.isDirty = computeIsDirty(comparedTo: item)
                scheduleAutoSave(for: item)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, 38)
            .padding(.top, 26)
            .padding(.bottom, 28)
        }
    }

    private var detailPlaceholder: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: "book.closed")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 38, height: 38)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("选择一条手记阅读")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.workspaceTokens.textPrimary)

            Text("左侧列表用于扫描，右侧用于完整阅读和编辑。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.workspaceTokens.textSecondary)
        }
        .padding(34)
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !bodyBridge.currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !attachments.isEmpty
    }

    private func endEditingSession(for item: HandbookItem) {
        guard editorSession.itemID == item.id, editorSession.isExitPending else { return }
        submitEdit(for: item, force: true, outlineRefreshPolicy: .refreshOutline)
        editorSession.finish(itemID: item.id)
        canvasFocus = nil
    }

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

    private func syncDraft(with item: HandbookItem?, preservesLocalTextEdits: Bool = false) {
        guard let item else { return }
        let cleanedStoredBody = HandbookAttachmentStorage.removingLegacyPastedImageLinks(
            from: item.body,
            attachments: item.attachments
        )
        let shouldPersistLegacyImageCleanup = !preservesLocalTextEdits && cleanedStoredBody != item.body
        if !preservesLocalTextEdits {
            editorState.autoSave?.cancel()
        }
        isSyncingDraft = true
        PerformanceMonitor.event("HandbookDetail.syncDraft", detail: "\(item.id.uuidString) chars=\(item.body.count)")
        PerformanceMonitor.measure("HandbookDetail.syncDraft.apply") {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if category != item.category { category = item.category }
                if folder != item.folder { folder = item.folder }
                if !preservesLocalTextEdits, title != item.title { title = item.title }
                if attachments != item.attachments { attachments = item.attachments }
                pasteErrorMessage = nil
            }
        }
        if !preservesLocalTextEdits, seededBody != cleanedStoredBody {
            seededBody = cleanedStoredBody
            bodyEditorResetID = UUID()
        }
        if !preservesLocalTextEdits {
            refreshOutline(for: cleanedStoredBody, itemID: item.id)
        }
        scheduleBodyMetricsUpdate(for: preservesLocalTextEdits ? bodyBridge.currentText : cleanedStoredBody)
        editorState.isDirty = preservesLocalTextEdits
            ? computeIsDirty(comparedTo: item)
            : shouldPersistLegacyImageCleanup
        Task { @MainActor in
            guard self.item?.id == item.id else { return }
            isSyncingDraft = false
            if shouldPersistLegacyImageCleanup {
                submitEdit(for: item, force: true)
            }
        }
    }

    private func focusBodyAfterItemSelection(_ selectedItemID: UUID) {
        Task { @MainActor in
            await Task.yield()
            guard item?.id == selectedItemID, canvasFocus != .title else { return }
            canvasFocus = .body
        }
    }

    private func handleBodyTextChange(_ newValue: String, for item: HandbookItem) {
        guard !isSyncingDraft else { return }
        scheduleBodyMetricsUpdate(for: newValue)
        editorState.isDirty = computeIsDirty(comparedTo: item)
        scheduleAutoSave(for: item)
    }

    private func handlePastedImage(_ image: NSImage, for item: HandbookItem) {
        guard canvasFocus != .title else { return }
        do {
            let attachment = try attachmentStorage.savePastedImage(image, noteID: item.id)
            attachments.append(attachment)
            pasteErrorMessage = nil
            canvasFocus = .body
            submitEdit(for: item, force: true)
        } catch {
            pasteErrorMessage = "保存图片失败：\(error.localizedDescription)"
        }
    }

    private func scheduleAutoSave(for item: HandbookItem) {
        editorState.autoSave?.cancel()
        editorState.autoSave = Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                submitEdit(for: item)
            }
        }
    }

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

    private func refreshOutline(for text: String, itemID: UUID) {
        outlineState.refreshTask?.cancel()
        outlineState.refreshTask = Task {
            let newEntries: [MarkdownOutlineEntry]
            if text.contains("#") {
                let extractionTask = Task.detached(priority: .userInitiated) {
                    PerformanceMonitor.measure("HandbookDetail.metrics.outline") {
                        MarkdownOutlineEntry.extract(from: text.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                newEntries = await withTaskCancellationHandler(
                    operation: { await extractionTask.value },
                    onCancel: { extractionTask.cancel() }
                )
            } else {
                newEntries = []
            }

            guard !Task.isCancelled, self.item?.id == itemID else { return }
            if outlineState.entries != newEntries {
                outlineState.entries = newEntries
            }
            if outlineState.itemID != itemID {
                outlineState.itemID = itemID
            }
        }
    }

    private func computeIsDirty(comparedTo item: HandbookItem) -> Bool {
        category != item.category
            || folder.trimmingCharacters(in: .whitespacesAndNewlines) != item.trimmedFolder
            || title.trimmingCharacters(in: .whitespacesAndNewlines) != item.trimmedTitle
            || bodyBridge.currentText.trimmingCharacters(in: .whitespacesAndNewlines) != item.trimmedBody
            || attachments != item.attachments
    }
}

struct HandbookOutlineContainer: View {
    @ObservedObject var outlineState: HandbookOutlineState
    let itemID: UUID

    var body: some View {
        if outlineState.itemID == itemID, !outlineState.entries.isEmpty {
            HandbookOutlineStrip(entries: outlineState.entries)
                .frame(maxWidth: 880, alignment: .leading)
                .padding(.bottom, 16)
        }
    }
}
