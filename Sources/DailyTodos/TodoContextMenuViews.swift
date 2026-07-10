import AppKit
import SwiftUI

struct TodoContextMenuContent: View {
    let todo: TodoItem
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onProgressChange: (TodoProgress) -> Void
    let onUpdate: (TodoDraft) -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            Menu("状态") {
                ForEach(TodoProgress.allCases) { progress in
                    Button {
                        onProgressChange(progress)
                    } label: {
                        Label(progress.label, systemImage: progress.contextMenuIcon)
                    }
                }
            }

            Menu("优先级") {
                ForEach(TodoPriority.allCases) { priority in
                    Button {
                        update(priority: priority)
                    } label: {
                        Label(priority.contextMenuTitle, systemImage: priority.contextMenuIcon)
                    }
                }
            }

            Menu("跟进日期") {
                Button("今天") {
                    update(date: relativeDate(daysFromToday: 0))
                }
                Button("明天") {
                    update(date: relativeDate(daysFromToday: 1))
                }
                Button("下周") {
                    update(date: relativeDate(daysFromToday: 7))
                }
            }

            Divider()

            Button {
                onEdit()
            } label: {
                Label("编辑", systemImage: "pencil")
            }

            Button {
                onToggle()
            } label: {
                Label(todo.isDone ? "恢复待处理" : "标记完成", systemImage: todo.isDone ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }

            Button {
                update(isWeekly: !todo.isWeekly)
            } label: {
                Label(todo.isWeekly ? "取消每周固定" : "设为每周固定", systemImage: "repeat")
            }

            Divider()

            Button {
                copyTitle()
            } label: {
                Label("复制标题", systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func update(progress: TodoProgress) {
        onProgressChange(progress)
    }

    private func update(priority: TodoPriority) {
        onUpdate(draft(priority: priority))
    }

    private func update(date: Date) {
        onUpdate(draft(date: date))
    }

    private func update(isWeekly: Bool) {
        onUpdate(draft(isWeekly: isWeekly))
    }

    private func draft(
        priority: TodoPriority? = nil,
        date: Date? = nil,
        isWeekly: Bool? = nil
    ) -> TodoDraft {
        TodoDraft(
            title: todo.title,
            notes: todo.notes,
            priority: priority ?? todo.priority,
            progress: todo.progress,
            date: date ?? todo.date,
            isWeekly: isWeekly ?? todo.isWeekly
        )
    }

    private func relativeDate(daysFromToday: Int) -> Date {
        let calendar = Calendar.current
        let currentComponents = calendar.dateComponents([.hour, .minute], from: todo.date)
        let baseDay = calendar.date(byAdding: .day, value: daysFromToday, to: calendar.startOfDay(for: Date())) ?? Date()
        return calendar.date(
            bySettingHour: currentComponents.hour ?? 0,
            minute: currentComponents.minute ?? 0,
            second: 0,
            of: baseDay
        ) ?? baseDay
    }

    private func copyTitle() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(todo.trimmedTitle, forType: .string)
    }
}

extension TodoProgress {
    var contextMenuIcon: String {
        switch self {
        case .pending: "circle"
        case .inProgress: "play.fill"
        case .waiting: "person.2"
        case .done: "checkmark.circle"
        }
    }
}

extension TodoPriority {
    var contextMenuTitle: String {
        switch self {
        case .high: "高优先级"
        case .medium: "中优先级"
        case .low: "低优先级"
        }
    }

    var contextMenuIcon: String {
        switch self {
        case .high: "exclamationmark.square.fill"
        case .medium: "minus.circle"
        case .low: "arrow.down.circle"
        }
    }
}
