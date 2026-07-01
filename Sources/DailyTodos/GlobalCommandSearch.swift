import Foundation
import SwiftUI

enum GlobalSearchModule: String, CaseIterable, Identifiable {
    case todos
    case handbook
    case credentials

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todos: "待办"
        case .handbook: "手记"
        case .credentials: "凭证"
        }
    }

    var icon: String {
        switch self {
        case .todos: "checklist"
        case .handbook: "book.closed"
        case .credentials: "key.fill"
        }
    }
}

enum GlobalSearchTarget: Identifiable, Equatable {
    case todo(UUID, scope: TodoScope)
    case handbook(UUID, category: HandbookCategory?, folder: String?)
    case credential(UUID, type: CredentialType?)

    var id: String {
        switch self {
        case .todo(let id, _): "todo-\(id.uuidString)"
        case .handbook(let id, _, _): "handbook-\(id.uuidString)"
        case .credential(let id, _): "credential-\(id.uuidString)"
        }
    }
}

struct GlobalSearchResult: Identifiable, Equatable {
    let id: String
    let module: GlobalSearchModule
    let title: String
    let subtitle: String
    let detail: String
    let target: GlobalSearchTarget

    init(module: GlobalSearchModule, title: String, subtitle: String, detail: String, target: GlobalSearchTarget) {
        self.module = module
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.target = target
        self.id = "\(module.rawValue)-\(target.id)"
    }
}

struct GlobalCommandSearchContext {
    let todos: [TodoItem]
    let handbookItems: [HandbookItem]
    let credentials: [CredentialItem]
    let didLoadHandbookItems: Bool
    let isLoadingHandbookItems: Bool
    let isCredentialVaultUnlocked: Bool
}

struct GlobalCommandSearchEngine {
    private let calendar = Calendar.current
    private let credentialDetailTagLimit = 3

    func results(query rawQuery: String, context: GlobalCommandSearchContext) -> [GlobalSearchModule: [GlobalSearchResult]] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [:] }
        let normalizedQuery = query.localizedLowercase

        return [
            .todos: todoResults(query: normalizedQuery, todos: context.todos),
            .handbook: handbookResults(query: normalizedQuery, items: context.handbookItems),
            .credentials: context.isCredentialVaultUnlocked
                ? credentialResults(query: normalizedQuery, credentials: context.credentials)
                : []
        ]
    }

    private func todoResults(query: String, todos: [TodoItem]) -> [GlobalSearchResult] {
        todos.compactMap { todo in
            let title = todo.trimmedTitle
            let haystack = [
                title,
                todo.trimmedNotes,
                todo.priority.label,
                todo.progress.label,
                todo.date.formatted(.dateTime.year().month().day().hour().minute())
            ].joined(separator: " ").localizedLowercase
            guard haystack.contains(query) else { return nil }

            let scope: TodoScope = calendar.isDateInToday(todo.date) ? .dashboard : .all
            return GlobalSearchResult(
                module: .todos,
                title: title.isEmpty ? "未命名待办" : title,
                subtitle: todo.progress.label,
                detail: todo.date.formatted(.dateTime.month().day().hour().minute()),
                target: .todo(todo.id, scope: scope)
            )
        }
        .prefix(5)
        .map { $0 }
    }

    private func handbookResults(query: String, items: [HandbookItem]) -> [GlobalSearchResult] {
        items.compactMap { item in
            let attachmentText = item.attachments.map(\.name).joined(separator: " ")
            let haystack = [
                item.trimmedTitle,
                item.trimmedBody,
                item.category.title,
                item.trimmedFolder,
                attachmentText
            ].joined(separator: " ").localizedLowercase
            guard haystack.contains(query) else { return nil }

            return GlobalSearchResult(
                module: .handbook,
                title: item.trimmedTitle.isEmpty ? "未命名手记" : item.trimmedTitle,
                subtitle: item.category.title,
                detail: item.trimmedFolder.isEmpty ? "未归档" : item.trimmedFolder,
                target: .handbook(
                    item.id,
                    category: item.category,
                    folder: item.trimmedFolder.isEmpty ? nil : item.trimmedFolder
                )
            )
        }
        .prefix(5)
        .map { $0 }
    }

    private func credentialResults(query: String, credentials: [CredentialItem]) -> [GlobalSearchResult] {
        credentials.compactMap { item in
            let haystack = credentialSearchHaystack(for: item)
            guard haystack.contains(query) else { return nil }

            return GlobalSearchResult(
                module: .credentials,
                title: item.trimmedTitle.isEmpty ? "未命名凭证" : item.trimmedTitle,
                subtitle: item.type.title,
                detail: credentialSearchDetail(for: item),
                target: .credential(item.id, type: item.type)
            )
        }
        .prefix(5)
        .map { $0 }
    }

    private func credentialSearchHaystack(for item: CredentialItem) -> String {
        [
            item.title,
            item.type.title,
            item.tags.joined(separator: " ")
        ].joined(separator: " ").localizedLowercase
    }

    private func credentialSearchDetail(for item: CredentialItem) -> String {
        let visibleTags = item.tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !visibleTags.isEmpty else {
            return "敏感字段默认隐藏"
        }

        let cappedTags = visibleTags.prefix(credentialDetailTagLimit).joined(separator: "、")
        return "标签：\(cappedTags)"
    }
}

struct GlobalCommandSearchPanel: View {
    let query: String
    let groupedResults: [GlobalSearchModule: [GlobalSearchResult]]
    let selectedResultID: GlobalSearchResult.ID?
    let didLoadHandbookItems: Bool
    let isLoadingHandbookItems: Bool
    let isCredentialVaultUnlocked: Bool
    let onSelect: (GlobalSearchResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(statusText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.workspaceTokens.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

            Divider().overlay(AppTheme.workspaceTokens.hairline.opacity(0.72))

            if totalCount == 0 {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(GlobalSearchModule.allCases) { module in
                            if let results = groupedResults[module], !results.isEmpty {
                                resultSection(module: module, results: results)
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: 340)
            }
        }
        .frame(width: 520)
        .background(AppTheme.workspaceTokens.contentSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.workspaceTokens.hairline)
        )
        .shadow(color: AppTheme.workspaceTokens.shadow.opacity(0.95), radius: 18, x: 0, y: 10)
    }

    private var totalCount: Int {
        groupedResults.values.reduce(0) { $0 + $1.count }
    }

    private var statusText: String {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "输入关键词，跨待办、手记和凭证定位内容"
        }
        if isLoadingHandbookItems {
            return "正在加载手记，同时搜索已加载内容"
        }
        if !didLoadHandbookItems {
            return "手记尚未加载，打开搜索会自动加载"
        }
        if !isCredentialVaultUnlocked {
            return "凭证库锁定时只搜索待办和手记"
        }
        return "按回车打开选中结果，Esc 关闭"
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("没有匹配结果")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
            Text("可以减少关键词，或切换到对应模块使用局部搜索。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.workspaceTokens.textMuted)
        }
        .padding(14)
    }

    private func resultSection(module: GlobalSearchModule, results: [GlobalSearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(module.title, systemImage: module.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.workspaceTokens.textMuted)
                .padding(.horizontal, 4)

            ForEach(results) { result in
                GlobalSearchResultRow(
                    result: result,
                    isSelected: result.id == selectedResultID,
                    onSelect: {
                        onSelect(result)
                    }
                )
            }
        }
    }
}

struct GlobalSearchResultRow: View {
    let result: GlobalSearchResult
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: result.module.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.workspaceTokens.accent)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
                        .lineLimit(1)
                    Text("\(result.subtitle) · \(result.detail)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.workspaceTokens.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                rowBackground,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isSelected {
            return AppTheme.workspaceTokens.accentSoft
        }
        if isHovered {
            return AppTheme.workspaceTokens.listRowHover
        }
        return .clear
    }
}
