import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case todos
    case handbook

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todos: "待办"
        case .handbook: "手记"
        }
    }

    var icon: String {
        switch self {
        case .todos: "checklist"
        case .handbook: "book.closed"
        }
    }
}

enum TodoScope: Equatable {
    case dashboard
    case all
    case waiting
    case weekly
    case day(Date)

    var analyticsName: String {
        switch self {
        case .dashboard: "dashboard"
        case .all: "all"
        case .waiting: "waiting"
        case .weekly: "weekly"
        case .day: "day"
        }
    }
}

enum AllTodosViewMode: String, CaseIterable, Identifiable {
    case compact
    case grouped
    case board
    case matrix

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact: "紧凑"
        case .grouped: "分组"
        case .board: "看板"
        case .matrix: "四象限"
        }
    }

    var icon: String {
        switch self {
        case .compact: "text.alignleft"
        case .grouped: "calendar"
        case .board: "rectangle.3.group"
        case .matrix: "square.grid.2x2"
        }
    }
}

enum FocusField: Hashable {
    case newTitle
}

enum HandbookFocusField: Hashable {
    case title
    case body
}

struct TodoDraft: Equatable {
    var title: String
    var notes: String
    var priority: TodoPriority
    var progress: TodoProgress
    var date: Date
    var isWeekly: Bool
}
