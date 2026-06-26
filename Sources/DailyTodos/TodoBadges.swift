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
        priority.displayColor
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
        priority.displayColor
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
        .accessibilityLabel("推进状态")
        .accessibilityValue(progress.boardTitle)
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
        if AppTheme.isDark {
            switch self {
            case .pending: return Color(red: 0.660, green: 0.730, blue: 0.800)
            case .inProgress: return AppTheme.accent
            case .waiting: return Color(red: 0.760, green: 0.660, blue: 1.000)
            case .done: return AppTheme.success
            }
        }

        switch AppSkin.current {
        case .ocean:
            switch self {
            case .pending: return Color(red: 0.38, green: 0.45, blue: 0.56)
            case .inProgress: return AppTheme.accent
            case .waiting: return Color(red: 0.48, green: 0.44, blue: 0.96)
            case .done: return Color(red: 0.12, green: 0.62, blue: 0.42)
            }
        case .aurora:
            switch self {
            case .pending: return Color(red: 0.47, green: 0.43, blue: 0.56)
            case .inProgress: return Color(red: 0.35, green: 0.34, blue: 0.92)
            case .waiting: return Color(red: 0.93, green: 0.36, blue: 0.73)
            case .done: return Color(red: 0.18, green: 0.64, blue: 0.52)
            }
        case .board:
            switch self {
            case .pending: return Color(red: 0.25, green: 0.25, blue: 0.28)
            case .inProgress: return Color(red: 0.24, green: 0.42, blue: 0.78)
            case .waiting: return Color(red: 0.82, green: 0.34, blue: 0.72)
            case .done: return Color(red: 0.14, green: 0.58, blue: 0.34)
            }
        case .leafcutter:
            switch self {
            case .pending: return Color(red: 0.48, green: 0.36, blue: 0.24)
            case .inProgress: return AppTheme.accent
            case .waiting: return Color(red: 0.86, green: 0.44, blue: 0.16)
            case .done: return Color(red: 0.28, green: 0.62, blue: 0.24)
            }
        }
    }
}

extension TodoPriority {
    var displayColor: Color {
        if AppTheme.isDark {
            switch self {
            case .low: return Color(red: 0.420, green: 0.840, blue: 0.590)
            case .medium: return AppTheme.accent
            case .high: return Color(red: 1.000, green: 0.390, blue: 0.430)
            }
        }

        switch AppSkin.current {
        case .ocean:
            switch self {
            case .low: return Color(red: 0.13, green: 0.67, blue: 0.52)
            case .medium: return AppTheme.accent
            case .high: return Color(red: 0.93, green: 0.18, blue: 0.24)
            }
        case .aurora:
            switch self {
            case .low: return Color(red: 0.16, green: 0.68, blue: 0.55)
            case .medium: return Color(red: 0.37, green: 0.34, blue: 0.92)
            case .high: return Color(red: 0.95, green: 0.30, blue: 0.55)
            }
        case .board:
            switch self {
            case .low: return Color(red: 0.15, green: 0.60, blue: 0.34)
            case .medium: return Color(red: 0.24, green: 0.42, blue: 0.78)
            case .high: return Color(red: 0.88, green: 0.28, blue: 0.30)
            }
        case .leafcutter:
            switch self {
            case .low: return Color(red: 0.32, green: 0.64, blue: 0.22)
            case .medium: return Color(red: 0.78, green: 0.42, blue: 0.16)
            case .high: return Color(red: 0.86, green: 0.16, blue: 0.10)
            }
        }
    }
}
