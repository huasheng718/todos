import Foundation

struct TodoItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var notes: String
    var priority: TodoPriority
    var date: Date
    var progress: TodoProgress
    var isWeekly: Bool
    var isDone: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        priority: TodoPriority = .medium,
        date: Date,
        progress: TodoProgress = .pending,
        isWeekly: Bool = false,
        isDone: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.priority = priority
        self.date = date
        self.progress = isDone ? .done : progress
        self.isWeekly = isWeekly
        self.isDone = self.progress == .done
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case priority
        case date
        case progress
        case isWeekly
        case isDone
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decode(String.self, forKey: .notes)
        priority = try container.decodeIfPresent(TodoPriority.self, forKey: .priority) ?? .medium
        date = try container.decode(Date.self, forKey: .date)
        let legacyIsDone = try container.decode(Bool.self, forKey: .isDone)
        progress = try container.decodeIfPresent(TodoProgress.self, forKey: .progress) ?? (legacyIsDone ? .done : .pending)
        isWeekly = try container.decodeIfPresent(Bool.self, forKey: .isWeekly) ?? false
        isDone = progress == .done
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

enum TodoProgress: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case pending
    case inProgress
    case waiting
    case done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: "待处理"
        case .inProgress: "推进中"
        case .waiting: "等待他人"
        case .done: "已完成"
        }
    }

    var shortLabel: String {
        switch self {
        case .pending: "待"
        case .inProgress: "推进"
        case .waiting: "等待"
        case .done: "完成"
        }
    }

    var sortRank: Int {
        switch self {
        case .pending: 0
        case .inProgress: 1
        case .waiting: 2
        case .done: 3
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = TodoProgress(rawValue: value) ?? .pending
    }
}

enum TodoPriority: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case high
    case medium
    case low

    var id: String { rawValue }

    var label: String {
        switch self {
        case .high: "高"
        case .medium: "中"
        case .low: "低"
        }
    }

    var sortRank: Int {
        switch self {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = TodoPriority(rawValue: value) ?? .medium
    }
}

extension TodoItem {
    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
