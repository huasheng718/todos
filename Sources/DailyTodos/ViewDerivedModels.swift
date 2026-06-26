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

struct HandbookTreeSnapshot: Equatable {
    static let empty = HandbookTreeSnapshot()

    let allItems: [HandbookItem]
    let sections: [HandbookTreeSection]
    let structureNodeIDs: Set<String>
    let structureSignature: String
    let cacheKey: HandbookTreeSnapshotKey

    var totalCount: Int { allItems.count }

    private init() {
        self.allItems = []
        self.sections = []
        self.structureNodeIDs = []
        self.structureSignature = ""
        self.cacheKey = HandbookTreeSnapshotKey.empty
    }

    init(items: [HandbookItem], searchText: String) {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cacheKey = HandbookTreeSnapshotKey(items: items, query: query)

        let visibleItems: [HandbookItem]
        if query.isEmpty {
            visibleItems = items
        } else {
            visibleItems = items.filter { item in
                item.matchesHandbookTreeSearch(query)
            }
        }

        var sectionItems: [HandbookCategory: [HandbookItem]] = [:]
        for item in visibleItems {
            sectionItems[item.category, default: []].append(item)
        }

        var nodeIDs = Set(["all"])
        var signatureParts = ["all"]
        self.sections = HandbookCategory.allCases.map { category in
            let items = sectionItems[category] ?? []
            let section = HandbookTreeSection(category: category, items: items)
            let categoryNodeID = HandbookTreeNodeID.category(category)
            nodeIDs.insert(categoryNodeID)
            signatureParts.append(categoryNodeID)
            for folder in section.folders {
                nodeIDs.insert(folder.id)
                signatureParts.append(folder.id)
            }
            if section.hasUnfiledItems {
                let unfiledNodeID = HandbookTreeNodeID.unfiled(category)
                nodeIDs.insert(unfiledNodeID)
                signatureParts.append(unfiledNodeID)
            }
            return section
        }
        self.allItems = visibleItems
        self.structureNodeIDs = nodeIDs
        self.structureSignature = signatureParts.joined(separator: "|")

        PerformanceMonitor.event("HandbookTreeSnapshot.count", detail: "\(visibleItems.count)")
    }
}

struct HandbookTreeSnapshotKey: Equatable {
    static let empty = HandbookTreeSnapshotKey(
        itemCount: 0,
        firstItemID: nil,
        lastItemID: nil,
        rowSignature: "",
        searchableSignature: "",
        query: ""
    )

    let itemCount: Int
    let firstItemID: UUID?
    let lastItemID: UUID?
    let rowSignature: String
    let searchableSignature: String
    let query: String

    private init(
        itemCount: Int,
        firstItemID: UUID?,
        lastItemID: UUID?,
        rowSignature: String,
        searchableSignature: String,
        query: String
    ) {
        self.itemCount = itemCount
        self.firstItemID = firstItemID
        self.lastItemID = lastItemID
        self.rowSignature = rowSignature
        self.searchableSignature = searchableSignature
        self.query = query
    }

    init(items: [HandbookItem], query: String) {
        self.itemCount = items.count
        self.firstItemID = items.first?.id
        self.lastItemID = items.last?.id
        self.rowSignature = items
            .map { item in
                [
                    item.id.uuidString,
                    item.category.rawValue,
                    item.trimmedFolder,
                    item.displayTitle,
                    "\(item.attachments.count)"
                ].joined(separator: "\u{1F}")
            }
            .joined(separator: "|")
        if query.isEmpty {
            self.searchableSignature = ""
        } else {
            self.searchableSignature = items
                .map { item in
                    [
                        item.id.uuidString,
                        item.displayTitle,
                        item.trimmedBody,
                        item.trimmedFolder,
                        item.category.rawValue
                    ].joined(separator: "\u{1F}")
                }
                .joined(separator: "|")
        }
        self.query = query
    }
}

struct HandbookTreeSection: Equatable, Identifiable {
    var id: HandbookCategory { category }

    let category: HandbookCategory
    let items: [HandbookItem]
    let folders: [HandbookTreeFolder]
    let unfiledItems: [HandbookItem]

    var nodeID: String { HandbookTreeNodeID.category(category) }
    var hasUnfiledItems: Bool { !unfiledItems.isEmpty }

    init(category: HandbookCategory, items: [HandbookItem]) {
        self.category = category
        self.items = items

        var folderItems: [String: [HandbookItem]] = [:]
        var unfiledItems: [HandbookItem] = []
        for item in items {
            let folder = item.trimmedFolder
            if folder.isEmpty {
                unfiledItems.append(item)
            } else {
                folderItems[folder, default: []].append(item)
            }
        }

        self.folders = folderItems.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { folder in
                HandbookTreeFolder(category: category, name: folder, items: folderItems[folder] ?? [])
            }
        self.unfiledItems = unfiledItems
    }
}

struct HandbookTreeFolder: Equatable, Identifiable {
    let category: HandbookCategory
    let name: String
    let items: [HandbookItem]

    var id: String { HandbookTreeNodeID.folder(category: category, folder: name) }
}

enum HandbookTreeNodeID {
    static let all = "all"

    static func category(_ category: HandbookCategory) -> String {
        "cat-\(category.rawValue)"
    }

    static func folder(category: HandbookCategory, folder: String) -> String {
        "folder-\(category.rawValue)-\(folder)"
    }

    static func unfiled(_ category: HandbookCategory) -> String {
        "unfiled-\(category.rawValue)"
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

private extension HandbookItem {
    func matchesHandbookTreeSearch(_ query: String) -> Bool {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return displayTitle.range(of: query, options: options) != nil
            || trimmedTitle.range(of: query, options: options) != nil
            || trimmedBody.range(of: query, options: options) != nil
            || trimmedFolder.range(of: query, options: options) != nil
            || category.title.range(of: query, options: options) != nil
            || category.subtitle.range(of: query, options: options) != nil
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
    static let stableEditorHeight: CGFloat = 560

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

        editorHeight = Self.stableEditorHeight
    }
}
