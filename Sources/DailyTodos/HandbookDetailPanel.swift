import SwiftUI
import AppKit

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
    @State private var bodyMetricsTask: Task<Void, Never>?
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
        .onChange(of: item) { _, newValue in
            syncDraft(with: newValue)
            isDirty = false
        }
        .onAppear {
            syncDraft(with: item)
        }
    }

    private func canvasPanel(for item: HandbookItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HandbookCanvasToolbar(
                accentColor: category.accentColor,
                isDirty: isDirty,
                canCopyAll: !copyAllText(for: item).isEmpty,
                canCopyTitle: !(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && item.displayTitle.isEmpty),
                onDelete: { onDelete(item) },
                onCopyAll: { copyToPasteboard(copyAllText(for: item)) },
                onCopyTitle: { copyToPasteboard(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.displayTitle : title) },
                onSave: { submitEdit(for: item) }
            )

            Divider()
                .overlay(AppTheme.hairline.opacity(0.56))

            ScrollView {
                HandbookEditableCanvas(
                    category: $category,
                    folder: $folder,
                    title: $title,
                    bodyText: $bodyText,
                    focusedField: $canvasFocus,
                    lengthKind: bodyMetrics.lengthKind,
                    characterCount: bodyMetrics.characterCount,
                    editorHeight: bodyMetrics.editorHeight,
                    isBodyEmpty: bodyMetrics.isEmpty,
                    formattedDate: item.updatedAt.formatted(.dateTime.year().month().day().hour().minute()),
                    attachmentCount: attachments.count
                )
                .padding(.bottom, 16)

                if !outline.isEmpty {
                    HandbookOutlineStrip(entries: outline)
                        .padding(.bottom, 16)
                }

                HandbookAttachmentStrip(attachments: $attachments, isEditing: true)
                    .padding(.top, 8)
                    .onChange(of: attachments) { _, _ in
                        isDirty = computeIsDirty(comparedTo: item)
                        submitEdit(for: item)
                    }
            }
            .onChange(of: category) { _, _ in
                isDirty = computeIsDirty(comparedTo: item)
                submitEdit(for: item)
            }
            .onChange(of: folder) { _, _ in
                isDirty = computeIsDirty(comparedTo: item)
                submitEdit(for: item)
            }
            .onChange(of: canvasFocus) { oldValue, newValue in
                if oldValue != nil && newValue == nil {
                    submitEdit(for: item)
                }
            }
            .onChange(of: title) { _, _ in
                isDirty = computeIsDirty(comparedTo: item)
            }
            .onChange(of: bodyText) { _, _ in
                isDirty = computeIsDirty(comparedTo: item)
            }
            .onChange(of: bodyText) { _, newValue in
                scheduleBodyMetricsUpdate(for: newValue)
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

    private func submitEdit(for item: HandbookItem) {
        guard canSubmit else { return }
        onUpdate(item, category, folder, title, bodyText, attachments)
        isDirty = false
    }

    private func syncDraft(with item: HandbookItem?) {
        guard let item else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            category = item.category
            folder = item.folder
            title = item.title
            bodyText = item.body
            attachments = item.attachments
            outline = []
            bodyMetrics = .empty
        }
        scheduleBodyMetricsUpdate(for: item.body)
    }

    private func scheduleBodyMetricsUpdate(for text: String) {
        bodyMetricsTask?.cancel()
        bodyMetricsTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }

            let metrics = await Task.detached(priority: .userInitiated) {
                HandbookBodyMetrics(text: text)
            }.value

            let newOutline: [MarkdownOutlineEntry]
            if text.contains("#") {
                newOutline = await Task.detached(priority: .userInitiated) {
                    MarkdownOutlineEntry.extract(from: text.trimmingCharacters(in: .whitespacesAndNewlines))
                }.value
            } else {
                newOutline = []
            }

            await MainActor.run {
                bodyMetrics = metrics
                outline = newOutline
            }
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func copyAllText(for item: HandbookItem) -> String {
        let titleText = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? item.displayTitle
            : title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)

        if titleText.isEmpty {
            return body
        }
        if body.isEmpty {
            return titleText
        }
        return "\(titleText)\n\n\(body)"
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
