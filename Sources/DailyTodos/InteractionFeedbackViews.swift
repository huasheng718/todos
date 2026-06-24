import SwiftUI

enum TodoUndoAction {
    case restoreDeleted(TodoItem)
    case revertTodo(TodoItem, generatedTodos: [TodoItem])
}

struct TodoActionFeedback: Identifiable {
    let id = UUID()
    let message: String
    let systemImage: String
    let undoAction: TodoUndoAction?
}

struct TodoFeedbackBanner: View {
    let feedback: TodoActionFeedback
    let onUndo: (TodoUndoAction) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: feedback.systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24, height: 24)
                .background(AppTheme.accentSoft, in: Circle())

            Text(feedback.message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let undoAction = feedback.undoAction {
                Button {
                    onUndo(undoAction)
                } label: {
                    Text("撤销")
                        .font(.system(size: 12, weight: .bold))
                        .frame(height: 30)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.accent)
                .background(AppTheme.accentSoft, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.accent.opacity(0.20), lineWidth: 1)
                )
                .interactionHitArea()
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .interactionHitArea()
            }
            .buttonStyle(.tactilePlain)
            .foregroundStyle(AppTheme.mutedInk)
            .help("关闭")
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 7)
        .frame(width: 360)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: AppTheme.rowShadow.opacity(0.95), radius: 16, x: 0, y: 8)
    }
}
