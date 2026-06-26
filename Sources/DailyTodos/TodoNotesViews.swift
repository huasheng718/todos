import SwiftUI

struct NotesReadOnlyRow: View {
    @EnvironmentObject private var aiSettings: AISettingsStore

    let title: String
    let notes: String
    let isDone: Bool

    @State private var summary: String?
    @State private var summaryError: String?
    @State private var summaryTrace: AITrace?
    @State private var showsSummaryTrace = false
    @State private var isSummarizing = false

    init(title: String = "", notes: String, isDone: Bool = false) {
        self.title = title
        self.notes = notes
        self.isDone = isDone
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Label("备注", systemImage: "text.alignleft")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .labelStyle(.titleAndIcon)
                .padding(.top, 8)
                .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                Text(displayText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.mutedInk)
                    .strikethrough(isDone, color: AppTheme.mutedInk)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let summary, !summary.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.top, 2)
                        Text(summary)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .transition(AppMotion.inlineTransition)
                }

                if let summaryError {
                    Text("摘要失败：\(summaryError)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TodoPriority.high.displayColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let summaryTrace {
                    AITraceDisclosure(trace: summaryTrace, isExpanded: $showsSummaryTrace)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.adaptiveWhite(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.border)
            )

            VStack(spacing: 6) {
                if aiSettings.canUseAI {
                    Button(action: summarizeNotes) {
                        Label(isSummarizing ? "摘要中" : "摘要", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .frame(width: 74, height: 28)
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(AppTheme.accent)
                    .background(AppTheme.accentSoft, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.accent.opacity(0.18))
                    )
                    .interactionHitArea()
                    .disabled(isSummarizing)
                    .accessibilityLabel("生成备注摘要")
                    .accessibilityValue(isSummarizing ? "正在生成" : "可用")

                    if isSummarizing {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
            }
            .frame(width: todoActionColumnWidth, alignment: .topTrailing)
        }
        .animation(AppMotion.revealAware, value: summary)
        .animation(AppMotion.revealAware, value: summaryError)
        .animation(AppMotion.revealAware, value: isSummarizing)
    }

    private var displayText: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func summarizeNotes() {
        guard aiSettings.canUseAI, !isSummarizing else { return }
        isSummarizing = true
        summaryError = nil
        summaryTrace = nil
        let configuration = aiSettings.configuration
        let apiKey = aiSettings.apiKey
        let sourceTitle = title
        let sourceNotes = displayText
        Task {
            do {
                let result = try await AIClient.shared.summarizeNotes(
                    title: sourceTitle,
                    notes: sourceNotes,
                    configuration: configuration,
                    apiKey: apiKey
                )
                await MainActor.run {
                    summary = result.content
                    summaryTrace = result.trace
                    isSummarizing = false
                }
            } catch {
                await MainActor.run {
                    summaryError = error.localizedDescription
                    isSummarizing = false
                }
            }
        }
    }
}

struct NotesRowLabelEditor: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let labelWidth: CGFloat
    let reservesActionColumn: Bool

    init(
        _ label: String,
        placeholder: String,
        text: Binding<String>,
        labelWidth: CGFloat = 58,
        reservesActionColumn: Bool = false
    ) {
        self.label = label
        self.placeholder = placeholder
        _text = text
        self.labelWidth = labelWidth
        self.reservesActionColumn = reservesActionColumn
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if labelWidth > 0 {
                Label(label, systemImage: "text.alignleft")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .labelStyle(.titleAndIcon)
                    .padding(.top, 8)
                    .frame(width: labelWidth, alignment: .leading)
            }

            InlineNotesEditor(placeholder, text: $text)
                .frame(maxWidth: .infinity, alignment: .leading)

            if reservesActionColumn {
                Color.clear
                    .frame(width: todoActionColumnWidth)
            }
        }
    }
}

struct InlineNotesEditor: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 13, weight: .medium))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(minHeight: editorHeight, maxHeight: editorHeight)

            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.mutedInk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
        }
        .background(AppTheme.adaptiveWhite(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border)
        )
        .accessibilityLabel("备注")
    }

    private var editorHeight: CGFloat {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return 46
        }

        let estimatedLines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { partialResult, line in
                partialResult + max(1, (line.count + 53) / 54)
            }
        return min(220, max(74, CGFloat(estimatedLines) * 20 + 26))
    }
}
