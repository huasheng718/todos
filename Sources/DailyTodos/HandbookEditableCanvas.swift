import SwiftUI

struct HandbookEditableCanvas: View {
    @Binding var category: HandbookCategory
    @Binding var folder: String
    @Binding var title: String
    @Binding var bodyText: String
    @Binding var attachments: [HandbookAttachment]
    var focusedField: FocusState<HandbookCanvasFocus?>.Binding
    let lengthKind: HandbookLengthKind
    let characterCount: Int
    let editorHeight: CGFloat
    let isBodyEmpty: Bool
    let formattedDate: String
    let attachmentCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("手记标题", text: $title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1...3)
                .focused(focusedField, equals: .title)

            HandbookDetailMetaBar(
                category: $category,
                folder: $folder,
                lengthKind: lengthKind,
                characterCount: characterCount,
                formattedDate: formattedDate,
                attachmentCount: attachmentCount
            )

            HandbookEditorToolbar(
                bodyText: $bodyText,
                attachments: $attachments,
                focusedField: focusedField
            )
            .padding(.top, 2)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $bodyText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(AppTheme.ink)
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, -4)
                    .frame(minHeight: editorHeight, maxHeight: editorHeight)
                    .focused(focusedField, equals: .body)

                if isBodyEmpty {
                    Text("从这里开始写手记，支持 Markdown。")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.mutedInk)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HandbookEditorToolbar: View {
    @Binding var bodyText: String
    @Binding var attachments: [HandbookAttachment]
    var focusedField: FocusState<HandbookCanvasFocus?>.Binding

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                styleMenu
                toolbarDivider

                HandbookEditorToolButton(title: "B", help: "加粗") {
                    wrap(prefix: "**", suffix: "**", sample: "重点")
                }
                HandbookEditorToolButton(systemImage: "italic", help: "斜体") {
                    wrap(prefix: "*", suffix: "*", sample: "强调")
                }
                HandbookEditorToolButton(systemImage: "strikethrough", help: "删除线") {
                    wrap(prefix: "~~", suffix: "~~", sample: "删除")
                }

                toolbarDivider

                HandbookEditorToolButton(systemImage: "list.bullet", help: "项目符号列表") {
                    appendLine("- ")
                }
                HandbookEditorToolButton(systemImage: "list.number", help: "编号列表") {
                    appendLine("1. ")
                }
                HandbookEditorToolButton(systemImage: "increase.indent", help: "增加缩进") {
                    appendLine("    ")
                }
                HandbookEditorToolButton(systemImage: "decrease.indent", help: "减少缩进") {
                    removeLeadingIndent()
                }

                toolbarDivider

                HandbookEditorToolButton(systemImage: "link", help: "插入链接") {
                    appendLine("[标题](https://)")
                }
                HandbookEditorToolButton(systemImage: "line.3.horizontal", help: "插入分割线") {
                    appendLine("---")
                }
                HandbookEditorToolButton(systemImage: "curlybraces.square", help: "代码块") {
                    wrap(prefix: "```\n", suffix: "\n```", sample: "code")
                }
                HandbookEditorToolButton(systemImage: "eraser", help: "清理常见 Markdown 标记") {
                    clearMarkdownMarkers()
                }

                toolbarDivider

                Button {
                    let picked = HandbookAttachmentPicker.pick()
                    guard !picked.isEmpty else { return }
                    attachments.append(contentsOf: picked)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 12, weight: .bold))
                        Text(attachments.isEmpty ? "附件" : "\(attachments.count)")
                            .font(.system(size: 12, weight: .bold))
                            .monospacedDigit()
                    }
                    .frame(height: 28)
                    .padding(.horizontal, 9)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.accent)
                .background(AppTheme.accentSoft.opacity(0.62), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.accent.opacity(0.18))
                )
                .help("添加附件")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.adaptiveWhite(0.72), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(AppTheme.border.opacity(0.76))
        )
    }

    private var styleMenu: some View {
        Menu {
            Button("正文") {
                focusBody()
            }
            Button("一级标题") {
                appendLine("# ")
            }
            Button("二级标题") {
                appendLine("## ")
            }
            Button("三级标题") {
                appendLine("### ")
            }
            Button("引用") {
                appendLine("> ")
            }
        } label: {
            HStack(spacing: 5) {
                Text("正文")
                    .font(.system(size: 12, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(AppTheme.ink.opacity(0.86))
            .frame(height: 28)
            .padding(.horizontal, 8)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("段落样式")
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(AppTheme.hairline.opacity(0.74))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 1)
    }

    private func appendLine(_ value: String) {
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        bodyText = trimmed.isEmpty ? value : "\(bodyText)\n\(value)"
        focusBody()
    }

    private func wrap(prefix: String, suffix: String, sample: String) {
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let snippet = "\(prefix)\(sample)\(suffix)"
        bodyText = trimmed.isEmpty ? snippet : "\(bodyText)\n\(snippet)"
        focusBody()
    }

    private func removeLeadingIndent() {
        let lines = bodyText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let value = String(line)
                if value.hasPrefix("    ") {
                    return String(value.dropFirst(4))
                }
                if value.hasPrefix("\t") {
                    return String(value.dropFirst())
                }
                return value
            }
        bodyText = lines.joined(separator: "\n")
        focusBody()
    }

    private func clearMarkdownMarkers() {
        var cleaned = bodyText
        for marker in ["**", "~~", "`"] {
            cleaned = cleaned.replacingOccurrences(of: marker, with: "")
        }
        cleaned = cleaned
            .replacingOccurrences(of: #"(?m)^\s{0,3}#{1,6}\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s{0,3}>\s?"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*[-*+]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^\s*\d+\.\s+"#, with: "", options: .regularExpression)
        bodyText = cleaned
        focusBody()
    }

    private func focusBody() {
        focusedField.wrappedValue = .body
    }
}

struct HandbookEditorToolButton: View {
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
                        .font(.system(size: 13, weight: .bold))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(AppTheme.ink.opacity(0.78))
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.tactilePlain)
        .help(help)
    }
}

struct HandbookDetailMetaBar: View {
    @Binding var category: HandbookCategory
    @Binding var folder: String
    let lengthKind: HandbookLengthKind
    let characterCount: Int
    let formattedDate: String
    let attachmentCount: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 7) {
                HandbookCategoryInlineTag(category: category)
                HandbookFolderInlineTag(folder: $folder)
                passiveMetaCards
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    HandbookCategoryInlineTag(category: category)
                    HandbookFolderInlineTag(folder: $folder)
                }
                passiveMetaCards
            }
        }
    }

    private var passiveMetaCards: some View {
        HStack(spacing: 7) {
            HandbookMetaCard(icon: lengthKind.icon, text: lengthKind.title)
            HandbookMetaCard(icon: "character.cursor.ibeam", text: "\(characterCount) 字")
            HandbookMetaCard(icon: "calendar", text: formattedDate)
            if attachmentCount > 0 {
                HandbookMetaCard(icon: "paperclip", text: "\(attachmentCount) 个附件")
            }
        }
    }
}

struct HandbookCategoryInlineTag: View {
    let category: HandbookCategory

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: category.icon)
                .font(.system(size: 11, weight: .bold))

            Text(category.title)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(category.accentColor)
        .padding(.horizontal, 9)
        .frame(height: 25)
        .background(category.softColor, in: Capsule())
        .overlay(
            Capsule()
                .stroke(category.accentColor.opacity(0.24))
        )
        .fixedSize()
        .help("拖拽左侧手记可修改分类")
    }
}

struct HandbookFolderInlineTag: View {
    @Binding var folder: String

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isDraftFocused: Bool

    var body: some View {
        Button {
            draft = trimmedFolder
            withAnimation(AppMotion.quick) {
                isEditing = true
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: trimmedFolder.isEmpty ? "folder.badge.plus" : "folder")
                    .font(.system(size: 11, weight: .bold))

                Text(trimmedFolder.isEmpty ? "未归档" : trimmedFolder)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .frame(maxWidth: 160, alignment: .leading)

                Image(systemName: "pencil")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(AppTheme.mutedInk.opacity(0.78))
            }
            .foregroundStyle(trimmedFolder.isEmpty ? AppTheme.mutedInk : AppTheme.ink.opacity(0.84))
            .padding(.horizontal, 9)
            .frame(height: 25)
            .background(AppTheme.adaptiveWhite(0.70), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.border.opacity(trimmedFolder.isEmpty ? 0.62 : 0.90))
            )
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .help("点击修改二级目录")
        .popover(isPresented: $isEditing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("二级目录")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                TextField("例如：审批流", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(AppTheme.adaptiveWhite(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.border)
                    )
                    .focused($isDraftFocused)
                    .onSubmit(commit)

                HStack(spacing: 8) {
                    Button("清空") {
                        draft = ""
                        commit()
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(AppTheme.mutedInk)

                    Spacer(minLength: 0)

                    Button("取消") {
                        isEditing = false
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(AppTheme.mutedInk)

                    Button("完成") {
                        commit()
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .background(AppTheme.accent, in: Capsule())
                }
                .font(.system(size: 12, weight: .bold))
            }
            .padding(12)
            .frame(width: 256)
            .background(AppTheme.panel.opacity(0.98))
            .onAppear {
                draft = trimmedFolder
                isDraftFocused = true
            }
        }
    }

    private var trimmedFolder: String {
        folder.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commit() {
        folder = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(AppMotion.quick) {
            isEditing = false
        }
    }
}

struct HandbookMetaCard: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(AppTheme.ink.opacity(0.76))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 25)
            .background(AppTheme.adaptiveWhite(0.64), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(AppTheme.border.opacity(0.72))
            )
            .fixedSize(horizontal: true, vertical: false)
    }
}
