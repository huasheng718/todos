import SwiftUI

struct EditableTodoRow: View {
    let todo: TodoItem
    let onToggle: () -> Void
    let onUpdate: (TodoDraft) -> Void
    let onDelete: () -> Void
    let startsEditing: Bool
    let onExitEditing: (() -> Void)?

    @State private var title: String
    @State private var notes: String
    @State private var priority: TodoPriority
    @State private var progress: TodoProgress
    @State private var date: Date
    @State private var isWeekly: Bool
    @State private var isEditing = false

    init(
        todo: TodoItem,
        onToggle: @escaping () -> Void,
        onUpdate: @escaping (TodoDraft) -> Void,
        onDelete: @escaping () -> Void,
        startsEditing: Bool = false,
        onExitEditing: (() -> Void)? = nil
    ) {
        self.todo = todo
        self.onToggle = onToggle
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.startsEditing = startsEditing
        self.onExitEditing = onExitEditing
        _title = State(initialValue: todo.title)
        _notes = State(initialValue: todo.notes)
        _priority = State(initialValue: todo.priority)
        _progress = State(initialValue: todo.progress)
        _date = State(initialValue: todo.date)
        _isWeekly = State(initialValue: todo.isWeekly)
        _isEditing = State(initialValue: startsEditing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggle) {
                    HStack(spacing: 6) {
                        Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17))
                        Text(todo.isDone ? "完成" : "待办")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(todo.isDone ? TodoProgress.done.displayColor : AppTheme.mutedInk)
                    .padding(.top, 7)
                    .frame(width: statusColumnWidth, alignment: .leading)
                }
                .buttonStyle(.tactilePlain)
                .interactionHitArea()

                if isEditing {
                    InlineTextField("待办", text: $title, isEmphasized: true)
                        .strikethrough(todo.isDone, color: AppTheme.mutedInk)
                        .frame(minWidth: 190, maxWidth: .infinity, alignment: .leading)

                    ProgressPicker(progress: $progress)
                        .frame(width: progressColumnWidth, alignment: .leading)

                    PriorityPicker(priority: $priority)
                        .frame(width: priorityColumnWidth, alignment: .leading)

                    DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(width: followUpColumnWidth, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title.isEmpty ? "未命名待办" : title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(todo.isDone ? AppTheme.mutedInk : AppTheme.ink)
                            .strikethrough(todo.isDone, color: AppTheme.mutedInk)
                            .lineLimit(3)

                        if todo.isWeekly {
                            Label("每周固定", systemImage: "repeat")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.mutedInk)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .frame(minWidth: 190, maxWidth: .infinity, alignment: .leading)

                    ProgressBadge(progress: progress)
                        .frame(width: progressColumnWidth, alignment: .leading)

                    PriorityBadge(priority: priority)
                        .frame(width: priorityColumnWidth, alignment: .leading)

                    Text(formatFullFollowUpDate(date))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.mutedInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .frame(width: followUpColumnWidth, alignment: .leading)
                }

                HStack(spacing: 8) {
                    if isEditing {
                        Button(action: submitEdit) {
                            Label("提交", systemImage: "checkmark")
                                .font(.caption.weight(.semibold))
                                .frame(width: 64, height: 30)
                        }
                        .buttonStyle(.tactilePlain)
                        .tactilePlainControlAppearance(
                            isDisabled: !canSubmit,
                            enabledForeground: AppTheme.workspaceTokens.accentForeground,
                            enabledBackground: AppTheme.workspaceTokens.accent,
                            enabledBorder: AppTheme.workspaceTokens.accent,
                            shape: .capsule
                        )
                        .interactionHitArea()
                        .disabled(!canSubmit)
                        .help("提交修改")

                        Button(action: cancelEdit) {
                            Image(systemName: "xmark")
                                .interactionHitArea()
                        }
                        .help("取消编辑")
                        .buttonStyle(.tactilePlain)
                        .foregroundStyle(AppTheme.mutedInk)
                    } else {
                        Button {
                            withAnimation(AppMotion.quick) {
                                isEditing = true
                            }
                        } label: {
                            Image(systemName: "pencil")
                                .interactionHitArea()
                        }
                        .help("编辑")
                        .buttonStyle(.tactilePlain)
                        .foregroundStyle(AppTheme.mutedInk)
                    }
                }
                .frame(width: todoActionColumnWidth, alignment: .trailing)
            }

            if isEditing {
                Toggle(isOn: $isWeekly) {
                    Label("每周固定，完成后自动生成下周同一天", systemImage: "repeat")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .toggleStyle(.checkbox)
                .padding(.leading, statusColumnWidth + 12)

                NotesRowLabelEditor("备注", placeholder: "添加备注", text: $notes, reservesActionColumn: true)

                HStack {
                    Spacer()

                    Button(role: .destructive, action: onDelete) {
                        Label("删除待办", systemImage: "trash")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(AppTheme.mutedInk)
                    .interactionHitArea()
                }
                .padding(.trailing, 2)
            } else if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                NotesReadOnlyRow(title: title, notes: notes, isDone: todo.isDone)
            }
        }
        .padding(14)
        .background(AppTheme.rowTint(priority: priority, isOverdue: isOverdue), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border)
        )
        .shadow(color: AppTheme.rowShadow, radius: 9, x: 0, y: 5)
        .onChange(of: todo) { _, newTodo in
            if !isEditing {
                withAnimation(AppMotion.smooth) {
                    syncFromTodo(newTodo)
                }
            }
        }
        .onAppear {
            if startsEditing {
                isEditing = true
            }
        }
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
        let draft = TodoDraft(
            title: title,
            notes: notes,
            priority: priority,
            progress: progress,
            date: date,
            isWeekly: isWeekly
        )
        guard draft != TodoDraft(
            title: todo.title,
            notes: todo.notes,
            priority: todo.priority,
            progress: todo.progress,
            date: todo.date,
            isWeekly: todo.isWeekly
        ) else {
            withAnimation(AppMotion.quick) {
                isEditing = false
            }
            onExitEditing?()
            return
        }
        guard canSubmit else { return }
        onUpdate(draft)
        withAnimation(AppMotion.quick) {
            isEditing = false
        }
        onExitEditing?()
    }

    private func cancelEdit() {
        syncFromTodo(todo)
        withAnimation(AppMotion.quick) {
            isEditing = false
        }
        onExitEditing?()
    }

    private func syncFromTodo(_ todo: TodoItem) {
        title = todo.title
        notes = todo.notes
        priority = todo.priority
        progress = todo.progress
        date = todo.date
        isWeekly = todo.isWeekly
    }
}
