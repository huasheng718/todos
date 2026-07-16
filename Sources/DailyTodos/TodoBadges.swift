import SwiftUI

struct PriorityBadge: View {
    let priority: TodoPriority

    var body: some View {
        Text(priority.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(priorityColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(priorityColor.opacity(0.10), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(priorityColor.opacity(0.58), lineWidth: 1)
            )
    }

    private var priorityColor: Color {
        priority.taskDisplayColor
    }
}

struct ProgressBadge: View {
    let progress: TodoProgress

    var body: some View {
        Text(progress.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(progress.displayColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(progress.displayColor.opacity(0.10), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(progress.displayColor.opacity(0.50), lineWidth: 1)
            )
    }
}

struct PriorityOutlineTag: View {
    let priority: TodoPriority
    var isCompact = false

    var body: some View {
        Text(priority.label)
            .font(.system(size: isCompact ? 10 : 11, weight: .bold))
            .foregroundStyle(priorityColor)
            .frame(minWidth: isCompact ? 22 : 0)
            .padding(.horizontal, isCompact ? 4 : 6)
            .padding(.vertical, isCompact ? 1 : 2)
            .background(priorityColor.opacity(isCompact ? 0.08 : 0.12), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(priorityColor.opacity(isCompact ? 0.82 : 0.62), lineWidth: 1)
            )
    }

    private var priorityColor: Color {
        priority.taskDisplayColor
    }
}

struct ProgressMenuTag: View {
    let progress: TodoProgress
    let onSelect: (TodoProgress) -> Void

    var body: some View {
        Menu {
            ForEach(TodoProgress.allCases) { option in
                Button(option.label) {
                    onSelect(option)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(progress.shortLabel)
                    .font(.system(size: 11, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .imageScale(.small)
            }
            .foregroundStyle(progress.displayColor)
            .frame(minWidth: 58, minHeight: 28)
            .background(progress.displayColor.opacity(0.08), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(progress.displayColor.opacity(0.18), lineWidth: 1)
            )
            .contentShape(Capsule())
            .interactionHitArea()
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("切换推进状态")
    }
}

extension TodoProgress {
    var previewIcon: String {
        switch self {
        case .pending: "circle"
        case .inProgress: "bolt.fill"
        case .waiting: "person.2.fill"
        case .done: "checkmark.circle.fill"
        }
    }

    var boardTitle: String {
        switch self {
        case .pending: "待处理"
        case .inProgress: "推进中"
        case .waiting: "等待反馈"
        case .done: "已完成"
        }
    }

    var boardIcon: String {
        switch self {
        case .pending: "circle"
        case .inProgress: "bolt.fill"
        case .waiting: "person.2.fill"
        case .done: "checkmark.circle.fill"
        }
    }

    var displayColor: Color {
        switch self {
        case .pending: return AppTheme.workspaceTokens.textSecondary
        case .inProgress: return AppTheme.workspaceTokens.accent
        case .waiting: return AppTheme.workspaceTokens.warning
        case .done: return AppTheme.workspaceTokens.success
        }
    }
}

extension TodoPriority {
    var issueIcon: String {
        switch self {
        case .high: "exclamationmark.circle.fill"
        case .medium: "flag"
        case .low: "arrow.down.circle"
        }
    }

    var displayColor: Color {
        switch self {
        case .low: return AppTheme.workspaceTokens.success
        case .medium: return AppTheme.workspaceTokens.accent
        case .high: return AppTheme.workspaceTokens.danger
        }
    }

    var taskDisplayColor: Color {
        switch self {
        case .low: return AppTheme.workspaceTokens.textSecondary
        case .medium: return AppTheme.workspaceTokens.accent
        case .high: return AppTheme.workspaceTokens.warning
        }
    }
}
