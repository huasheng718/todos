import Foundation
import SwiftUI

struct TodoSidebarMetrics: Equatable {
    static let empty = TodoSidebarMetrics(
        activeCount: 0,
        completedCount: 0,
        overdueCount: 0,
        waitingCount: 0,
        weeklyCount: 0,
        dashboardCount: 0,
        datesWithTodos: [],
        totalCountByDay: [:],
        pendingCountByDay: [:]
    )

    let activeCount: Int
    let completedCount: Int
    let overdueCount: Int
    let waitingCount: Int
    let weeklyCount: Int
    let dashboardCount: Int
    let datesWithTodos: [Date]
    private let totalCountByDay: [Date: Int]
    private let pendingCountByDay: [Date: Int]

    init(
        activeCount: Int,
        completedCount: Int,
        overdueCount: Int,
        waitingCount: Int,
        weeklyCount: Int,
        dashboardCount: Int,
        datesWithTodos: [Date],
        totalCountByDay: [Date: Int],
        pendingCountByDay: [Date: Int]
    ) {
        self.activeCount = activeCount
        self.completedCount = completedCount
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
        var completedCount = 0
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
            } else {
                completedCount += 1
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
        self.completedCount = completedCount
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

struct HandbookScope: Equatable, Sendable {
    static let all = HandbookScope(category: nil, folder: nil, searchText: "")

    let category: HandbookCategory?
    let folder: String?
    let searchText: String

    init(category: HandbookCategory?, folder: String?, searchText: String) {
        self.category = category
        let cleanedFolder = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.folder = cleanedFolder
        self.searchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func contains(_ summary: HandbookNoteSummary) -> Bool {
        if let category, summary.category != category {
            return false
        }

        if let folder {
            if folder.isEmpty {
                guard summary.folder.isEmpty else { return false }
            } else if summary.folder != folder {
                return false
            }
        }

        guard !searchText.isEmpty else { return true }
        return summary.matches(searchText)
    }
}

struct HandbookNoteSummary: Equatable, Identifiable, Sendable {
    let id: UUID
    let category: HandbookCategory
    let folder: String
    let title: String
    let preview: String
    let createdAt: Date
    let updatedAt: Date
    let attachmentCount: Int
    let attachmentNames: [String]
    fileprivate let searchIndex: String

    init(item: HandbookItem) {
        let trimmedBody = item.trimmedBody
        self.id = item.id
        self.category = item.category
        self.folder = item.trimmedFolder
        self.title = item.displayTitle
        self.preview = Self.previewText(for: item)
        self.createdAt = item.createdAt
        self.updatedAt = item.updatedAt
        self.attachmentCount = item.attachments.count
        self.attachmentNames = item.attachments.map(\.name)
        self.searchIndex = Self.searchIndex(for: item, trimmedBody: trimmedBody)
    }

    func matches(_ query: String) -> Bool {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return searchIndex.range(of: cleanedQuery, options: options) != nil
    }

    private static func previewText(for item: HandbookItem) -> String {
        let body = item.trimmedBody
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
        if !body.isEmpty {
            return String(body.prefix(80))
        }
        return item.category.subtitle
    }

    private static func searchIndex(for item: HandbookItem, trimmedBody: String) -> String {
        ([item.displayTitle, trimmedBody, item.trimmedFolder, item.category.title] + item.attachments.map(\.name))
            .joined(separator: "\n")
    }
}

struct HandbookSidebarIndex: Equatable, Sendable {
    static let empty = HandbookSidebarIndex(totalCount: 0, scopedCount: 0, categoryCounts: [:], folders: [])

    let totalCount: Int
    let scopedCount: Int
    let categoryCounts: [HandbookCategory: Int]
    let folders: [HandbookFolderSummary]

    init(totalCount: Int, scopedCount: Int, categoryCounts: [HandbookCategory: Int], folders: [HandbookFolderSummary]) {
        self.totalCount = totalCount
        self.scopedCount = scopedCount
        self.categoryCounts = categoryCounts
        self.folders = folders
    }

    init(summaries: [HandbookNoteSummary], selectedCategory: HandbookCategory?) {
        var categoryCounts: [HandbookCategory: Int] = [:]
        var folderCounts: [String: Int] = [:]
        var scopedCount = 0

        for summary in summaries {
            categoryCounts[summary.category, default: 0] += 1
            guard selectedCategory == nil || summary.category == selectedCategory else { continue }
            scopedCount += 1

            if !summary.folder.isEmpty {
                folderCounts[summary.folder, default: 0] += 1
            }
        }

        self.totalCount = summaries.count
        self.scopedCount = scopedCount
        self.categoryCounts = categoryCounts
        self.folders = folderCounts
            .map { HandbookFolderSummary(name: $0.key, count: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

struct HandbookFolderSummary: Equatable, Identifiable, Sendable {
    let name: String
    let count: Int

    var id: String { name }
}

struct HandbookNotesListSnapshot: Equatable {
    static let empty = HandbookNotesListSnapshot()

    let groups: [HandbookNotesGroup]
    let scopedCount: Int
    let visibleCount: Int
    let cacheKey: HandbookNotesListSnapshotKey

    private init() {
        self.groups = []
        self.scopedCount = 0
        self.visibleCount = 0
        self.cacheKey = .empty
    }

    init(
        items: [HandbookItem],
        selectedCategory: HandbookCategory?,
        selectedFolder: String?,
        searchText: String
    ) {
        self.init(
            summaries: items.map(HandbookNoteSummary.init),
            scope: HandbookScope(category: selectedCategory, folder: selectedFolder, searchText: searchText)
        )
    }

    init(
        summaries: [HandbookNoteSummary],
        scope: HandbookScope
    ) {
        self.cacheKey = HandbookNotesListSnapshotKey(
            summaries: summaries,
            scope: scope
        )

        let scoped = summaries.filter { summary in
            let scopeWithoutSearch = HandbookScope(
                category: scope.category,
                folder: scope.folder,
                searchText: ""
            )
            return scopeWithoutSearch.contains(summary)
        }
        let visible = scoped
            .filter { summary in
                scope.searchText.isEmpty || summary.matches(scope.searchText)
            }

        self.scopedCount = scoped.count
        self.visibleCount = visible.count
        self.groups = Self.groupRows(visible)
    }

    private static func groupRows(_ summaries: [HandbookNoteSummary]) -> [HandbookNotesGroup] {
        var buckets: [(key: String, title: String, rows: [HandbookNotesRowData])] = []

        for summary in summaries {
            let group = HandbookNotesDateGrouper.group(for: summary.updatedAt)
            let row = HandbookNotesRowData(summary: summary)

            if let index = buckets.firstIndex(where: { $0.key == group.key }) {
                buckets[index].rows.append(row)
            } else {
                buckets.append((key: group.key, title: group.title, rows: [row]))
            }
        }

        return buckets.map { bucket in
            HandbookNotesGroup(id: bucket.key, title: bucket.title, rows: bucket.rows)
        }
    }
}

struct HandbookNotesListSnapshotKey: Equatable {
    static let empty = HandbookNotesListSnapshotKey(
        itemCount: 0,
        rowSignature: "",
        selectedCategory: nil,
        selectedFolder: nil,
        searchText: ""
    )

    let itemCount: Int
    let rowSignature: String
    let selectedCategory: HandbookCategory?
    let selectedFolder: String?
    let searchText: String

    private init(
        itemCount: Int,
        rowSignature: String,
        selectedCategory: HandbookCategory?,
        selectedFolder: String?,
        searchText: String
    ) {
        self.itemCount = itemCount
        self.rowSignature = rowSignature
        self.selectedCategory = selectedCategory
        self.selectedFolder = selectedFolder
        self.searchText = searchText
    }

    init(
        items: [HandbookItem],
        selectedCategory: HandbookCategory?,
        selectedFolder: String?,
        searchText: String
    ) {
        self.init(
            summaries: items.map(HandbookNoteSummary.init),
            scope: HandbookScope(category: selectedCategory, folder: selectedFolder, searchText: searchText)
        )
    }

    init(
        summaries: [HandbookNoteSummary],
        scope: HandbookScope
    ) {
        let includesFullTextSearch = !scope.searchText.isEmpty
        self.itemCount = summaries.count
        self.rowSignature = summaries
            .map { summary in
                [
                    summary.id.uuidString,
                    summary.category.rawValue,
                    summary.folder,
                    String(summary.title.count),
                    Self.stableTextSignature(summary.title),
                    String(summary.preview.count),
                    Self.stableTextSignature(summary.preview),
                    includesFullTextSearch ? Self.stableTextSignature(summary.searchIndex) : "",
                    "\(summary.attachmentCount)",
                    Self.timestampSignature(summary.updatedAt)
                ].joined(separator: "\u{1F}")
            }
            .joined(separator: "\u{1E}")
        self.selectedCategory = scope.category
        self.selectedFolder = scope.folder
        self.searchText = scope.searchText
    }

    private static func timestampSignature(_ date: Date) -> String {
        String(Int64(date.timeIntervalSince1970 * 1000))
    }

    private static func stableTextSignature(_ text: String) -> String {
        let hash = text.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

struct HandbookNotesGroup: Equatable, Identifiable {
    let id: String
    let title: String
    let rows: [HandbookNotesRowData]
}

struct HandbookNotesRowData: Equatable, Identifiable {
    let id: UUID
    let title: String
    let preview: String
    let dateText: String
    let folder: String
    let category: HandbookCategory
    let attachmentCount: Int

    init(item: HandbookItem) {
        self.init(summary: HandbookNoteSummary(item: item))
    }

    init(summary: HandbookNoteSummary) {
        self.id = summary.id
        self.title = summary.title
        self.preview = summary.preview
        self.dateText = HandbookNotesRowData.dateText(for: summary.updatedAt)
        self.folder = summary.folder
        self.category = summary.category
        self.attachmentCount = summary.attachmentCount
    }

    private static func dateText(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
        }
        if calendar.isDateInYesterday(date) {
            return "昨天"
        }
        return date.formatted(.dateTime.month().day())
    }
}

enum HandbookNotesDateGrouper {
    static func group(for date: Date) -> (key: String, title: String) {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return ("today", "今天")
        }
        if calendar.isDateInYesterday(date) {
            return ("yesterday", "昨天")
        }

        let components = calendar.dateComponents([.year, .month], from: date)
        let currentYear = calendar.component(.year, from: Date())
        let year = components.year ?? currentYear
        let month = components.month ?? 1

        if year == currentYear {
            return ("\(year)-\(month)", monthTitle(month))
        }
        return ("\(year)", "\(year)年")
    }

    private static func monthTitle(_ month: Int) -> String {
        let titles = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]
        guard (1...12).contains(month) else { return "\(month)月" }
        return titles[month - 1]
    }
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
