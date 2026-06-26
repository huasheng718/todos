import SwiftUI

struct HandbookDetailPanel: View {
    let item: HandbookItem?
    let onUpdate: (HandbookItem, HandbookCategory, String, String, String, [HandbookAttachment]) -> Void
    let onDelete: (HandbookItem) -> Void

    @State private var category: HandbookCategory = .businessRule
    @State private var folder = ""
    @State private var title = ""
    @State private var bodyText = ""
    @State private var attachments: [HandbookAttachment] = []
    @State private var outline: [MarkdownOutlineEntry] = []
    @State private var bodyMetrics = HandbookBodyMetrics.empty
    @State private var outlineUpdateToken = UUID()
    @State private var isDirty = false
    @State private var isSyncingDraft = false
    @State private var bodyMetricsTask: Task<Void, Never>?
    @State private var autoSaveTask: Task<Void, Never>?
    @FocusState private var canvasFocus: HandbookCanvasFocus?

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
                    isDirty = computeIsDirty(comparedTo: newValue)
                } else {
                    isDirty = false
                }
                return
            }
            if let oldValue {
                submitEdit(for: oldValue, force: true)
            }
            syncDraft(with: newValue)
            isDirty = false
        }
        .onAppear {
            syncDraft(with: item)
        }
    }

    private func canvasPanel(for item: HandbookItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                HandbookEditableCanvas(
                    category: $category,
                    folder: $folder,
                    title: $title,
                    bodyText: $bodyText,
                    attachments: $attachments,
                    focusedField: $canvasFocus,
                    lengthKind: bodyMetrics.lengthKind,
                    characterCount: bodyMetrics.characterCount,
                    editorHeight: bodyMetrics.editorHeight,
                    isBodyEmpty: bodyMetrics.isEmpty,
                    formattedDate: item.createdAt.formatted(.dateTime.year().month().day().hour().minute()),
                    attachmentCount: attachments.count
                )
                .padding(.bottom, 16)

                if !outline.isEmpty {
                    HandbookOutlineStrip(entries: outline)
                        .padding(.bottom, 16)
                }

                if !attachments.isEmpty {
                    HandbookAttachmentStrip(attachments: $attachments, isEditing: true)
                        .padding(.top, 8)
                }
            }
            .onChange(of: attachments) { _, _ in
                guard !isSyncingDraft else { return }
                isDirty = computeIsDirty(comparedTo: item)
                submitEdit(for: item, force: true)
            }
            .onChange(of: category) { _, _ in
                guard !isSyncingDraft else { return }
                isDirty = computeIsDirty(comparedTo: item)
                submitEdit(for: item, force: true)
            }
            .onChange(of: folder) { _, _ in
                guard !isSyncingDraft else { return }
                isDirty = computeIsDirty(comparedTo: item)
                submitEdit(for: item, force: true)
            }
            .onChange(of: canvasFocus) { oldValue, newValue in
                if oldValue != nil && newValue == nil {
                    submitEdit(for: item, force: true)
                }
            }
            .onChange(of: title) { _, _ in
                guard !isSyncingDraft else { return }
                isDirty = computeIsDirty(comparedTo: item)
                scheduleAutoSave(for: item)
            }
            .onChange(of: bodyText) { _, newValue in
                handleBodyTextChange(newValue, for: item)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, 34)
            .padding(.top, 22)
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
                .foregroundStyle(AppTheme.ink)

            Text("左侧列表用于扫描，右侧用于完整阅读和编辑。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(34)
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitEdit(for item: HandbookItem, force: Bool = false) {
        autoSaveTask?.cancel()
        guard canSubmit else { return }
        guard force || computeIsDirty(comparedTo: item) else { return }
        onUpdate(item, category, folder, title, bodyText, attachments)
        isDirty = false
    }

    private func syncDraft(with item: HandbookItem?) {
        guard let item else { return }
        autoSaveTask?.cancel()
        isSyncingDraft = true
        PerformanceMonitor.event("HandbookDetail.syncDraft", detail: "\(item.id.uuidString) chars=\(item.body.count)")
        PerformanceMonitor.measure("HandbookDetail.syncDraft.apply") {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if category != item.category { category = item.category }
                if folder != item.folder { folder = item.folder }
                if title != item.title { title = item.title }
                if bodyText != item.body { bodyText = item.body }
                if attachments != item.attachments { attachments = item.attachments }
            }
        }
        scheduleBodyMetricsUpdate(for: item.body)
        Task { @MainActor in
            isSyncingDraft = false
        }
    }

    private func handleBodyTextChange(_ newValue: String, for item: HandbookItem) {
        guard !isSyncingDraft else { return }
        scheduleBodyMetricsUpdate(for: newValue)
        isDirty = computeIsDirty(comparedTo: item)
        scheduleAutoSave(for: item)
    }

    private func scheduleAutoSave(for item: HandbookItem) {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                submitEdit(for: item)
            }
        }
    }

    private func scheduleBodyMetricsUpdate(for text: String) {
        bodyMetricsTask?.cancel()
        bodyMetricsTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }

            let metrics = await Task.detached(priority: .userInitiated) {
                PerformanceMonitor.measure("HandbookDetail.metrics.body") {
                    HandbookBodyMetrics(text: text)
                }
            }.value

            let newOutline: [MarkdownOutlineEntry]
            if text.contains("#") {
                newOutline = await Task.detached(priority: .userInitiated) {
                    PerformanceMonitor.measure("HandbookDetail.metrics.outline") {
                        MarkdownOutlineEntry.extract(from: text.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }.value
            } else {
                newOutline = []
            }

            await MainActor.run {
                if bodyMetrics != metrics {
                    bodyMetrics = metrics
                }
                if outline != newOutline {
                    outline = newOutline
                }
            }
        }
    }

    private func computeIsDirty(comparedTo item: HandbookItem) -> Bool {
        category != item.category
            || folder.trimmingCharacters(in: .whitespacesAndNewlines) != item.trimmedFolder
            || title.trimmingCharacters(in: .whitespacesAndNewlines) != item.trimmedTitle
            || bodyText.trimmingCharacters(in: .whitespacesAndNewlines) != item.trimmedBody
            || attachments != item.attachments
    }
}

enum HandbookCanvasFocus: Hashable {
    case title
    case body
}
