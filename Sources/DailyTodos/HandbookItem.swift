import Foundation

struct HandbookItem: Identifiable, Codable, Equatable {
    var id: UUID
    var category: HandbookCategory
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        category: HandbookCategory,
        title: String,
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum HandbookCategory: String, Codable, CaseIterable, Identifiable, Equatable {
    case businessRule
    case research
    case meeting
    case inspiration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .businessRule: "业务规则"
        case .research: "调研"
        case .meeting: "会议"
        case .inspiration: "灵感"
        }
    }

    var subtitle: String {
        switch self {
        case .businessRule: "流程、口径、约束"
        case .research: "用户、竞品、资料"
        case .meeting: "纪要、结论、行动"
        case .inspiration: "想法、机会、片段"
        }
    }

    var icon: String {
        switch self {
        case .businessRule: "list.bullet.rectangle.portrait"
        case .research: "magnifyingglass.circle"
        case .meeting: "person.2.wave.2"
        case .inspiration: "sparkle.magnifyingglass"
        }
    }
}

extension HandbookItem {
    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
