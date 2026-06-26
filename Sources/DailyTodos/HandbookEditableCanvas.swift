import SwiftUI

struct HandbookEditableCanvas: View {
    @Binding var category: HandbookCategory
    @Binding var folder: String
    @Binding var title: String
    @Binding var bodyText: String
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

struct HandbookDetailMetaBar: View {
    @Binding var category: HandbookCategory
    @Binding var folder: String
    let lengthKind: HandbookLengthKind
    let characterCount: Int
    let formattedDate: String
    let attachmentCount: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                editableTags
                HandbookMetaDot()
                passiveMeta
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 7) {
                editableTags
                passiveMeta
            }
        }
    }

    private var editableTags: some View {
        HStack(spacing: 7) {
            HandbookCategoryInlineTag(category: $category)
            HandbookFolderInlineTag(folder: $folder)
        }
    }

    private var passiveMeta: some View {
        HStack(spacing: 8) {
            HandbookMetaText(icon: lengthKind.icon, text: lengthKind.title)
            HandbookMetaDot()
            HandbookMetaText(icon: "character.cursor.ibeam", text: "\(characterCount) 字")
            HandbookMetaDot()
            HandbookMetaText(icon: "calendar", text: formattedDate)
            if attachmentCount > 0 {
                HandbookMetaDot()
                HandbookMetaText(icon: "paperclip", text: "\(attachmentCount) 个附件")
            }
        }
    }
}

struct HandbookCategoryInlineTag: View {
    @Binding var category: HandbookCategory

    var body: some View {
        Menu {
            Picker("分类", selection: $category) {
                ForEach(HandbookCategory.allCases) { option in
                    Label(option.title, systemImage: option.icon).tag(option)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .bold))

                Text(category.title)
                    .font(.system(size: 12, weight: .bold))

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(category.accentColor.opacity(0.72))
            }
            .foregroundStyle(category.accentColor)
            .padding(.horizontal, 9)
            .frame(height: 25)
            .background(category.softColor, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(category.accentColor.opacity(0.24))
            )
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .fixedSize()
        .help("点击修改分类")
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

struct HandbookMetaText: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(AppTheme.mutedInk)
            .lineLimit(1)
    }
}

struct HandbookMetaDot: View {
    var body: some View {
        Circle()
            .fill(AppTheme.hairline)
            .frame(width: 4, height: 4)
    }
}
