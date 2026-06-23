import Foundation
import SwiftUI

struct TodoSidebarMetrics: Equatable {
    static let empty = TodoSidebarMetrics(
        activeCount: 0,
        overdueCount: 0,
        waitingCount: 0,
        weeklyCount: 0,
        dashboardCount: 0,
        datesWithTodos: [],
        totalCountByDay: [:],
        pendingCountByDay: [:]
    )

    let activeCount: Int
    let overdueCount: Int
    let waitingCount: Int
    let weeklyCount: Int
    let dashboardCount: Int
    let datesWithTodos: [Date]
    private let totalCountByDay: [Date: Int]
    private let pendingCountByDay: [Date: Int]

    init(
        activeCount: Int,
        overdueCount: Int,
        waitingCount: Int,
        weeklyCount: Int,
        dashboardCount: Int,
        datesWithTodos: [Date],
        totalCountByDay: [Date: Int],
        pendingCountByDay: [Date: Int]
    ) {
        self.activeCount = activeCount
        self.overdueCount = overdueCount
        self.waitingCount = waitingCount
        self.weeklyCount = weeklyCount
        self.dashboardCount = dashboardCount
        self.datesWithTodos = datesWithTodos
        self.totalCountByDay = totalCountByDay
        self.pendingCountByDay = pendingCountByDay
    }

    init(todos: [TodoItem], calendar: Calendar, now: Date) {
        let today = calendar.startOfDay(for: now)
        var activeCount = 0
        var overdueCount = 0
        var waitingCount = 0
        var weeklyCount = 0
        var dashboardCount = 0
        var totalCountByDay: [Date: Int] = [:]
        var pendingCountByDay: [Date: Int] = [:]

        for todo in todos {
            let day = calendar.startOfDay(for: todo.date)
            totalCountByDay[day, default: 0] += 1

            if todo.progress != .done {
                activeCount += 1
                pendingCountByDay[day, default: 0] += 1
            }
            if todo.progress != .done && todo.progress != .waiting && day < today {
                overdueCount += 1
            }
            if todo.progress == .waiting {
                waitingCount += 1
            }
            if todo.isWeekly && todo.progress != .done {
                weeklyCount += 1
            }
            if todo.progress != .done && (day <= today || todo.progress == .waiting || todo.isWeekly) {
                dashboardCount += 1
            }
        }

        self.activeCount = activeCount
        self.overdueCount = overdueCount
        self.waitingCount = waitingCount
        self.weeklyCount = weeklyCount
        self.dashboardCount = dashboardCount
        self.datesWithTodos = totalCountByDay.keys.sorted(by: >)
        self.totalCountByDay = totalCountByDay
        self.pendingCountByDay = pendingCountByDay
    }

    func todoCount(on date: Date, calendar: Calendar) -> Int {
        totalCountByDay[calendar.startOfDay(for: date), default: 0]
    }

    func pendingCount(on date: Date, calendar: Calendar) -> Int {
        pendingCountByDay[calendar.startOfDay(for: date), default: 0]
    }
}

struct HandbookSidebarMetrics: Equatable {
    static let empty = HandbookSidebarMetrics(
        totalCount: 0,
        scopedCount: 0,
        categoryCounts: [:],
        folderCounts: [:],
        folders: []
    )

    let totalCount: Int
    let scopedCount: Int
    let categoryCounts: [HandbookCategory: Int]
    let folderCounts: [String: Int]
    let folders: [String]

    init(
        totalCount: Int,
        scopedCount: Int,
        categoryCounts: [HandbookCategory: Int],
        folderCounts: [String: Int],
        folders: [String]
    ) {
        self.totalCount = totalCount
        self.scopedCount = scopedCount
        self.categoryCounts = categoryCounts
        self.folderCounts = folderCounts
        self.folders = folders
    }

    init(items: [HandbookItem], selectedCategory: HandbookCategory?) {
        var categoryCounts: [HandbookCategory: Int] = [:]
        var folderCounts: [String: Int] = [:]
        var scopedCount = 0

        for item in items {
            categoryCounts[item.category, default: 0] += 1
            guard selectedCategory == nil || item.category == selectedCategory else { continue }
            scopedCount += 1

            let folder = item.trimmedFolder
            if !folder.isEmpty {
                folderCounts[folder, default: 0] += 1
            }
        }

        self.totalCount = items.count
        self.scopedCount = scopedCount
        self.categoryCounts = categoryCounts
        self.folderCounts = folderCounts
        self.folders = folderCounts.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}

enum HandbookListFilter: String, CaseIterable, Identifiable {
    case all
    case recent
    case attached
    case longform

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .recent: "最近"
        case .attached: "附件"
        case .longform: "沉淀"
        }
    }

    var icon: String {
        switch self {
        case .all: "tray.full"
        case .recent: "clock"
        case .attached: "paperclip"
        case .longform: "doc.richtext"
        }
    }

    var emptyText: String {
        switch self {
        case .all: "当前没有手记"
        case .recent: "最近 7 天没有更新的手记"
        case .attached: "当前范围没有带附件的手记"
        case .longform: "当前范围还没有中篇或文章"
        }
    }

    func filter(_ items: [HandbookItem]) -> [HandbookItem] {
        switch self {
        case .all:
            return items
        case .recent:
            let threshold = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
            return items.filter { $0.updatedAt >= threshold }
        case .attached:
            return items.filter { !$0.attachments.isEmpty }
        case .longform:
            return items.filter { $0.lengthKind == .medium || $0.lengthKind == .article }
        }
    }
}


struct HandbookListCacheKey: Equatable {
    let itemCount: Int
    let firstItemID: UUID?
    let firstUpdatedAt: Date?
    let lastItemID: UUID?
    let lastUpdatedAt: Date?
    let selectedCategory: HandbookCategory?
    let selectedFolder: String?
    let searchText: String
    let activeFilter: HandbookListFilter
}

struct HandbookBodyMetrics: Equatable {
    static let empty = HandbookBodyMetrics(text: "")

    let characterCount: Int
    let lengthKind: HandbookLengthKind
    let editorHeight: CGFloat
    let isEmpty: Bool

    init(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let characterCount = trimmed.count
        self.characterCount = characterCount
        self.isEmpty = trimmed.isEmpty

        if characterCount >= 1200 {
            lengthKind = .article
        } else if characterCount >= 300 {
            lengthKind = .medium
        } else {
            lengthKind = .snippet
        }

        let estimatedLines = text
            .split(separator: "\n", maxSplits: 259, omittingEmptySubsequences: false)
            .reduce(0) { partialResult, line in
                partialResult + max(1, (line.count + 58) / 59)
            }
        editorHeight = min(2600, max(360, CGFloat(max(12, estimatedLines)) * 24 + 32))
    }
}
