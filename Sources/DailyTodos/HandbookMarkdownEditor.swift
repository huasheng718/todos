import SwiftUI

struct HandbookBodyEditor: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat

    init(_ placeholder: String, text: Binding<String>, minHeight: CGFloat, maxHeight: CGFloat) {
        self.placeholder = placeholder
        _text = text
        self.minHeight = minHeight
        self.maxHeight = maxHeight
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 13, weight: .medium))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(minHeight: editorHeight, maxHeight: editorHeight)

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.workspaceTokens.textMuted)
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
    }

    private var editorHeight: CGFloat {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return minHeight
        }

        let estimatedLines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { partialResult, line in
                partialResult + max(1, (line.count + 58) / 59)
            }
        return min(maxHeight, max(minHeight, CGFloat(estimatedLines) * 20 + 28))
    }
}

struct HandbookFolderEditor: View {
    @Binding var folder: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "folder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.workspaceTokens.textMuted)
                .frame(width: 14)

            TextField("二级目录", text: $folder)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 9)
        .frame(height: 31)
        .background(AppTheme.adaptiveWhite(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border)
        )
    }
}

struct MarkdownHandbookEditor: View {
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat

    @State private var showsPreview = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                MarkdownToolbarButton(title: "H2", help: "二级标题") {
                    apply(prefix: "## ")
                }
                MarkdownToolbarButton(title: "B", help: "加粗") {
                    wrap(prefix: "**", suffix: "**", sample: "重点")
                }
                MarkdownToolbarButton(systemImage: "list.bullet", help: "列表") {
                    apply(prefix: "- ")
                }
                MarkdownToolbarButton(systemImage: "quote.opening", help: "引用") {
                    apply(prefix: "> ")
                }
                MarkdownToolbarButton(systemImage: "curlybraces", help: "代码块") {
                    wrap(prefix: "```\n", suffix: "\n```", sample: "code")
                }
                MarkdownToolbarButton(systemImage: "link", help: "链接") {
                    appendSnippet("[标题](https://)")
                }

                Spacer()

                Button {
                    withAnimation(AppMotion.reveal) {
                        showsPreview.toggle()
                    }
                } label: {
                    Label(showsPreview ? "编辑" : "预览", systemImage: showsPreview ? "pencil" : "eye")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 66, height: 28)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.accent)
                .background(AppTheme.accentSoft.opacity(0.64), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.accent.opacity(0.18))
                )
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(AppTheme.adaptiveWhite(0.72))

            Divider()
                .overlay(AppTheme.hairline.opacity(0.62))

            if showsPreview {
                ScrollView {
                    MarkdownPreview(text: text.isEmpty ? "在左侧编辑 Markdown 后，这里预览正文。" : text)
                        .padding(12)
                }
                .frame(minHeight: editorHeight, maxHeight: editorHeight)
                .transition(AppMotion.inlineTransition)
            } else {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .frame(minHeight: editorHeight, maxHeight: editorHeight)

                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("支持 Markdown：## 标题、- 列表、> 引用、**重点**、链接和代码块")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.workspaceTokens.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 13)
                            .allowsHitTesting(false)
                    }
                }
                .transition(AppMotion.inlineTransition)
            }
        }
        .background(AppTheme.adaptiveWhite(0.94), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(AppTheme.border)
        )
        .animation(AppMotion.reveal, value: showsPreview)
    }

    private var editorHeight: CGFloat {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return minHeight
        }

        let estimatedLines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { partialResult, line in
                partialResult + max(1, (line.count + 54) / 55)
            }
        return min(maxHeight, max(minHeight, CGFloat(estimatedLines) * 20 + 44))
    }

    private func apply(prefix: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            text = prefix
        } else {
            text += "\n\(prefix)"
        }
    }

    private func wrap(prefix: String, suffix: String, sample: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let snippet = "\(prefix)\(sample)\(suffix)"
        text = trimmed.isEmpty ? snippet : "\(text)\n\(snippet)"
    }

    private func appendSnippet(_ snippet: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = trimmed.isEmpty ? snippet : "\(text)\n\(snippet)"
    }
}

struct MarkdownToolbarButton: View {
    var title: String?
    var systemImage: String?
    let help: String
    let action: () -> Void

    init(title: String, help: String, action: @escaping () -> Void) {
        self.title = title
        self.help = help
        self.action = action
    }

    init(systemImage: String, help: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let title {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .frame(width: 28, height: 26)
        }
        .buttonStyle(.tactilePlain)
        .foregroundStyle(AppTheme.workspaceTokens.textSecondary)
        .help(help)
    }
}

struct MarkdownPreview: View {
    let text: String

    var body: some View {
        Text(markdown)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
            .lineSpacing(5)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var markdown: AttributedString {
        (try? AttributedString(markdown: text))
            ?? AttributedString(text)
    }
}
