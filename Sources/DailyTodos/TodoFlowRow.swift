import SwiftUI

enum TodoFlowRowEditStyle: Equatable {
    case full
    case compact
}

struct TodoFlowRow: View, @MainActor Equatable {
    let todo: TodoItem
    let onToggle: () -> Void
    let onProgressChange: (TodoProgress) -> Void
    let onUpdate: (TodoDraft) -> Void
    let onDelete: () -> Void
    var editStyle: TodoFlowRowEditStyle = .full
    var isHighlighted = false

    @State private var isEditing = false
    @State private var isHovered = false

    static func == (lhs: TodoFlowRow, rhs: TodoFlowRow) -> Bool {
        lhs.todo == rhs.todo
            && lhs.editStyle == rhs.editStyle
            && lhs.isHighlighted == rhs.isHighlighted
    }

    var body: some View {
        if isEditing {
            switch editStyle {
            case .full:
                EditableTodoRow(
                    todo: todo,
                    onToggle: onToggle,
                    onUpdate: onUpdate,
                    onDelete: onDelete,
                    startsEditing: true,
                    onExitEditing: {
                        isEditing = false
                    }
                )
                .id("\(todo.id)-editing")
                .transition(AppMotion.inlineTransition)

            case .compact:
                TodoBoardEditCard(
                    todo: todo,
                    onUpdate: onUpdate,
                    onDelete: onDelete,
                    onExitEditing: {
                        isEditing = false
                    }
                )
                .id("\(todo.id)-compact-editing")
                .transition(AppMotion.inlineTransition)
            }
        } else {
            HStack(alignment: hasNotes ? .top : .center, spacing: 10) {
                TodoIssueStatusMarker(todo: todo, isHighlighted: isHovered || isHighlighted)
                    .padding(.top, hasNotes ? 2 : 0)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        PriorityOutlineTag(priority: todo.priority, isCompact: true)
                            .fixedSize()

                        Text(titleText)
                            .font(.system(size: 13.5, weight: todo.isDone ? .regular : .semibold))
                            .foregroundStyle(todo.isDone ? AppTheme.mutedInk : AppTheme.ink)
                            .strikethrough(todo.isDone, color: AppTheme.mutedInk)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if todo.isWeekly {
                            Image(systemName: "repeat")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.mutedInk)
                                .help("每周固定")
                        }
                    }

                    if hasNotes {
                        Text(todo.trimmedNotes)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.mutedInk)
                            .strikethrough(todo.isDone, color: AppTheme.mutedInk)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, hasNotes ? 2 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 14) {
                    TodoIssueProgressText(progress: todo.progress)
                        .frame(width: 46, alignment: .leading)

                    Text(followUpText)
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(dateColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(width: 84, alignment: .leading)
                }
                .padding(.top, hasNotes ? 0 : 0)
                .fixedSize()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, hasNotes ? 9 : 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(rowBackground)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(issueRailColor)
                            .frame(width: 3)
                            .opacity(sideRailOpacity)
                            .padding(.vertical, 7)
                    }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(rowStroke)
            )
            .opacity(rowOpacity)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contextMenu {
                TodoContextMenuContent(
                    todo: todo,
                    onEdit: startEditing,
                    onToggle: onToggle,
                    onProgressChange: onProgressChange,
                    onUpdate: onUpdate,
                    onDelete: onDelete
                )
            }
            .onHover { hovered in
                withAnimation(AppMotion.hover) {
                    isHovered = hovered
                }
            }
            .animation(AppMotion.status, value: todo.progress)
            .animation(AppMotion.complete, value: todo.isDone)
            .animation(AppMotion.hover, value: isHovered)
            .animation(AppMotion.reveal, value: isHighlighted)
            .transition(AppMotion.inlineTransition)
        }
    }

    private var titleText: String {
        todo.trimmedTitle.isEmpty ? "未命名待办" : todo.trimmedTitle
    }

    private var hasNotes: Bool {
        !todo.trimmedNotes.isEmpty
    }

    private var followUpText: String {
        let calendar = Calendar.current
        let timeText = timeSuffix(for: todo.date, calendar: calendar)
        if calendar.isDateInToday(todo.date) { return "今天\(timeText)" }
        if calendar.isDateInTomorrow(todo.date) { return "明天\(timeText)" }
        if calendar.isDateInYesterday(todo.date) { return "昨天\(timeText)" }
        let month = calendar.component(.month, from: todo.date)
        let day = calendar.component(.day, from: todo.date)
        let year = calendar.component(.year, from: todo.date)
        let currentYear = calendar.component(.year, from: Date())
        if year == currentYear {
            return "\(month)/\(day)\(timeText)"
        }
        return "\(year % 100)/\(month)/\(day)\(timeText)"
    }

    private var isOverdue: Bool {
        let calendar = Calendar.current
        return todo.progress != .done
            && todo.progress != .waiting
            && calendar.startOfDay(for: todo.date) < calendar.startOfDay(for: Date())
    }

    private var dateColor: Color {
        isOverdue ? TodoPriority.high.displayColor : AppTheme.mutedInk
    }

    private var rowBackground: Color {
        if isHighlighted {
            return AppTheme.accentSoft.opacity(0.96)
        }
        if isHovered {
            return AppTheme.adaptiveBlack(AppTheme.isDark ? 0.22 : 0.045)
        }
        if isOverdue {
            return TodoPriority.high.displayColor.opacity(AppTheme.isDark ? 0.16 : 0.075)
        }
        return Color.clear
    }

    private var rowStroke: Color {
        if isOverdue {
            return TodoPriority.high.displayColor.opacity(AppTheme.isDark ? 0.30 : 0.16)
        }
        if isHighlighted {
            return AppTheme.accent.opacity(0.30)
        }
        if isHovered {
            return AppTheme.hairline.opacity(0.76)
        }
        return Color.clear
    }

    private var issueRailColor: Color {
        if isOverdue {
            return TodoPriority.high.displayColor
        }
        return todo.priority.displayColor
    }

    private var sideRailOpacity: Double {
        if todo.isDone {
            return isHighlighted ? 0.42 : 0.18
        }
        if isHighlighted {
            return 0.95
        }
        if isOverdue || isHovered {
            return 0.82
        }
        return todo.priority == .high ? 0.64 : 0.0
    }

    private var rowOpacity: Double {
        if !todo.isDone {
            return 1
        }
        return isHighlighted ? 0.88 : 0.72
    }

    private func startEditing() {
        withAnimation(AppMotion.reveal) {
            isEditing = true
        }
    }
}

struct TodoIssueStatusMarker: View {
    let todo: TodoItem
    let isHighlighted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .overlay(
                    Circle()
                        .stroke(strokeColor, lineWidth: 1.4)
                )
                .frame(width: 21, height: 21)

            if todo.isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(TodoProgress.done.displayColor)
            }
        }
        .frame(width: 26, height: 28)
        .accessibilityLabel(todo.isDone ? "已完成" : "未完成")
    }

    private var fillColor: Color {
        if todo.isDone {
            return TodoProgress.done.displayColor.opacity(AppTheme.isDark ? 0.20 : 0.12)
        }
        if isHighlighted {
            return AppTheme.panel.opacity(0.82)
        }
        return Color.clear
    }

    private var strokeColor: Color {
        if todo.isDone {
            return TodoProgress.done.displayColor.opacity(0.34)
        }
        return AppTheme.mutedInk.opacity(isHighlighted ? 0.48 : 0.34)
    }
}

struct TodoIssueProgressText: View {
    let progress: TodoProgress

    var body: some View {
        Text(progress.shortLabel)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(progress.displayColor)
            .lineLimit(1)
            .accessibilityLabel(progress.label)
    }
}

struct TodoBoardEditCard: View {
    let todo: TodoItem
    let onUpdate: (TodoDraft) -> Void
    let onDelete: () -> Void
    let onExitEditing: () -> Void

    @State private var title: String
    @State private var notes: String
    @State private var priority: TodoPriority
    @State private var progress: TodoProgress
    @State private var date: Date
    @State private var isWeekly: Bool

    init(
        todo: TodoItem,
        onUpdate: @escaping (TodoDraft) -> Void,
        onDelete: @escaping () -> Void,
        onExitEditing: @escaping () -> Void
    ) {
        self.todo = todo
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onExitEditing = onExitEditing
        _title = State(initialValue: todo.title)
        _notes = State(initialValue: todo.notes)
        _priority = State(initialValue: todo.priority)
        _progress = State(initialValue: todo.progress)
        _date = State(initialValue: todo.date)
        _isWeekly = State(initialValue: todo.isWeekly)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("编辑事项")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)

                Spacer()

                Button(action: cancelEdit) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .interactionHitArea()
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .help("取消编辑")
            }

            InlineTextField("待办", text: $title, isEmphasized: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ProgressPicker(progress: $progress)
                    .frame(maxWidth: .infinity, alignment: .leading)

                PriorityPicker(priority: $priority)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(isOn: $isWeekly) {
                Label("每周固定", systemImage: "repeat")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .toggleStyle(.checkbox)
            .help("完成后自动生成下周同一天")

            NotesRowLabelEditor(
                "备注",
                placeholder: "添加备注",
                text: $notes,
                labelWidth: 44,
                reservesActionColumn: false
            )

            HStack(spacing: 8) {
                Button(role: .destructive, action: deleteAndExit) {
                    Label("删除", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                        .frame(height: 30)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .interactionHitArea()

                Spacer()

                Button(action: submitEdit) {
                    Label("提交", systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .frame(width: 72, height: 30)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(.white)
                .background(canSubmit ? AppTheme.accent : AppTheme.adaptiveBlack(0.28), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(canSubmit ? AppTheme.adaptiveWhite(0.34) : AppTheme.adaptiveBlack(0.05))
                )
                .interactionHitArea()
                .disabled(!canSubmit)
                .help("提交修改")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.rowTint(priority: priority, isOverdue: isOverdue), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.24))
        )
        .shadow(color: AppTheme.rowShadow, radius: 8, x: 0, y: 4)
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isOverdue: Bool {
        let calendar = Calendar.current
        return progress != .done
            && progress != .waiting
            && calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
    }

    private func submitEdit() {
        guard canSubmit else { return }
        let draft = TodoDraft(
            title: title,
            notes: notes,
            priority: priority,
            progress: progress,
            date: date,
            isWeekly: isWeekly
        )
        if draft != TodoDraft(
            title: todo.title,
            notes: todo.notes,
            priority: todo.priority,
            progress: todo.progress,
            date: todo.date,
            isWeekly: todo.isWeekly
        ) {
            onUpdate(draft)
        }
        withAnimation(AppMotion.quick) {
            onExitEditing()
        }
    }

    private func cancelEdit() {
        withAnimation(AppMotion.quick) {
            onExitEditing()
        }
    }

    private func deleteAndExit() {
        onDelete()
        withAnimation(AppMotion.quick) {
            onExitEditing()
        }
    }
}

struct EmptyTodoHint: View {
    let isAllScope: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.accentSoft.opacity(0.95),
                                AppTheme.accentWarm.opacity(0.11)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.accent.opacity(0.16), lineWidth: 1)
                    )
                Image(systemName: "leaf.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .rotationEffect(.degrees(-18))
                    .offset(x: -3, y: -2)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(AppTheme.accentWarm)
                    .offset(x: 13, y: 12)
            }
            .frame(width: 54, height: 54)

            Text(isAllScope ? "还没有任何待办" : "这一天还没有待办")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            Text("顶部快记可直接写下一条推进。")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }
}
