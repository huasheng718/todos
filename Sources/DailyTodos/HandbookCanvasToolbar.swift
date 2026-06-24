import SwiftUI

struct HandbookCanvasToolbar: View {
    let accentColor: Color
    let isDirty: Bool
    let canCopyAll: Bool
    let canCopyTitle: Bool
    let onDelete: () -> Void
    let onCopyAll: () -> Void
    let onCopyTitle: () -> Void
    let onSave: () -> Void
    @State private var copiedMessage: String?
    @State private var copyFeedbackToken = UUID()

    var body: some View {
        HStack(spacing: 9) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
                    .font(.system(size: 12, weight: .bold))
                    .frame(height: 30)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.tactilePlain)
            .foregroundStyle(TodoPriority.high.displayColor)
            .interactionHitArea()
            .help("删除手记")

            Text("直接编辑，离开输入框或点击保存后写入")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(-1)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Label(isDirty ? "未保存" : "已保存", systemImage: isDirty ? "circle.dotted" : "checkmark.circle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isDirty ? AppTheme.accentWarm : AppTheme.mutedInk)
                    .lineLimit(1)

                if let copiedMessage {
                    Label(copiedMessage, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accentColor)
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
            .frame(minWidth: 110, alignment: .trailing)

            HStack(spacing: 5) {
                HandbookToolbarCopyButton(
                    title: "复制全文",
                    systemImage: "doc.on.doc",
                    isPrimary: true,
                    isEnabled: canCopyAll
                ) {
                    performCopy(message: "已复制", action: onCopyAll)
                }
                .help("复制标题和正文")

                HandbookToolbarCopyButton(
                    title: "标题",
                    systemImage: "textformat",
                    isPrimary: false,
                    isEnabled: canCopyTitle
                ) {
                    performCopy(message: "标题已复制", action: onCopyTitle)
                }
                .help("仅复制标题")
            }
            .fixedSize(horizontal: true, vertical: false)

            Button(action: onSave) {
                Label("保存", systemImage: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 64, height: 30)
            }
            .buttonStyle(.tactilePlain)
            .foregroundStyle(.white)
            .background(isDirty ? accentColor : AppTheme.adaptiveBlack(0.28), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isDirty ? AppTheme.adaptiveWhite(0.34) : AppTheme.adaptiveBlack(0.05))
            )
            .disabled(!isDirty)
            .interactionHitArea()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(AppTheme.panel.opacity(0.96))
        .animation(AppMotion.quick, value: copiedMessage)
    }

    private func performCopy(message: String, action: () -> Void) {
        action()
        let token = UUID()
        copyFeedbackToken = token
        withAnimation(AppMotion.quick) {
            copiedMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            guard copyFeedbackToken == token else { return }
            withAnimation(AppMotion.quick) {
                copiedMessage = nil
            }
        }
    }
}

struct HandbookToolbarCopyButton: View {
    let title: String
    let systemImage: String
    let isPrimary: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .bold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, isPrimary ? 10 : 8)
                .frame(height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isPrimary ? AppTheme.accent : AppTheme.mutedInk)
        .background(buttonBackground, in: Capsule())
        .overlay(
            Capsule()
                .stroke(isPrimary ? AppTheme.accent.opacity(0.22) : AppTheme.hairline.opacity(isHovered ? 0.92 : 0.64))
        )
        .interactionHitArea(34)
        .opacity(isEnabled ? 1 : 0.42)
        .disabled(!isEnabled)
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
    }

    private var buttonBackground: Color {
        guard isEnabled else {
            return AppTheme.adaptiveBlack(0.18)
        }
        if isPrimary {
            return isHovered ? AppTheme.accentSoft.opacity(0.95) : AppTheme.accentSoft.opacity(0.72)
        }
        return isHovered ? AppTheme.adaptiveWhite(0.82) : AppTheme.adaptiveWhite(0.54)
    }
}
