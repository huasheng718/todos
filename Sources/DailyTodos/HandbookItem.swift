import Foundation

struct HandbookItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var category: HandbookCategory
    var folder: String
    var title: String
    var body: String
    var attachments: [HandbookAttachment]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        category: HandbookCategory,
        folder: String = "",
        title: String,
        body: String,
        attachments: [HandbookAttachment] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.folder = folder
        self.title = title
        self.body = body
        self.attachments = attachments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct HandbookAttachment: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: HandbookAttachmentKind
    var name: String
    var path: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        kind: HandbookAttachmentKind,
        name: String,
        path: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.path = path
        self.createdAt = createdAt
    }
}

enum HandbookAttachmentKind: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case file
    case image
    case video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .file: "附件"
        case .image: "图片"
        case .video: "视频"
        }
    }

    var icon: String {
        switch self {
        case .file: "paperclip"
        case .image: "photo"
        case .video: "film"
        }
    }
}

enum HandbookLengthKind: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case snippet
    case medium
    case article

    var id: String { rawValue }

    var title: String {
        switch self {
        case .snippet: "杂记"
        case .medium: "中篇"
        case .article: "文章"
        }
    }

    var icon: String {
        switch self {
        case .snippet: "note.text"
        case .medium: "doc.text"
        case .article: "doc.richtext"
        }
    }
}

enum HandbookCategory: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
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
    var trimmedFolder: String {
        folder.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayTitle: String {
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        for line in body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let summary = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            if !summary.isEmpty {
                return String(summary.prefix(32))
            }
        }
        return "未命名手记"
    }

    var cardSummary: String? {
        let source = trimmedBody
        guard !source.isEmpty else { return nil }
        let normalized = source
            .prefix(180)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return normalized.isEmpty ? nil : normalized
    }

    var bodyCharacterCount: Int {
        trimmedBody.count
    }

    var lengthKind: HandbookLengthKind {
        let characterCount = bodyCharacterCount
        if characterCount >= 1200 {
            return .article
        }
        if characterCount >= 300 {
            return .medium
        }
        return .snippet
    }
}
