import SwiftUI

/// 待办模块的导航视图
/// 替代原来的 TodoSidebarView，但集成到2栏布局中
struct TodoNavigationView: View {
    @State private var scope: TodoScope = .dashboard
    @EnvironmentObject private var store: TodoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            VStack(alignment: .leading, spacing: 4) {
                Text("待办")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("管理日常待办事项")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.horizontal, 17)
            .padding(.top, 48)
            .padding(.bottom, 14)

            SearchField(text: .constant(""))

            // scope 列表
            VStack(alignment: .leading, spacing: 7) {
                SidebarSectionLabel("视图")

                // 从现有的 TodoSidebarView 借鉴 scope 按钮
                TodoScopeButton(scope: .dashboard, isSelected: scope == .dashboard) {
                    scope = .dashboard
                }
                TodoScopeButton(scope: .all, isSelected: scope == .all) {
                    scope = .all
                }
                TodoScopeButton(scope: .waiting, isSelected: scope == .waiting) {
                    scope = .waiting
                }
                TodoScopeButton(scope: .weekly, isSelected: scope == .weekly) {
                    scope = .weekly
                }
            }
            .padding(.horizontal, 17)
            .padding(.top, 14)

            Spacer(minLength: 0)

            // 底部统计
            VStack(alignment: .leading, spacing: 4) {
                Text("待办")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("共 \(store.todos.count) 条")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 13)
        }
        .background(AppTheme.sidebar)
        .foregroundStyle(AppTheme.ink)
    }
}

/// 待办模块的内容视图
struct TodoContentView: View {
    @EnvironmentObject private var store: TodoStore

    var body: some View {
        Text("待办内容视图")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 手记模块的导航视图（框架，目录树会在下一步实现）
struct HandbookNavigationView: View {
    @EnvironmentObject private var store: TodoStore
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("手记")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("业务规则、调研、会议、灵感")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.horizontal, 17)
            .padding(.top, 48)
            .padding(.bottom, 14)

            SearchField(text: $searchText)

            // 目录树占位符 - 下一步实现
            HandbookTreePlaceholder()

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("手记")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("共 \(store.handbookItems.count) 条沉淀")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 13)
        }
        .background(AppTheme.sidebar)
        .foregroundStyle(AppTheme.ink)
    }
}

/// 手记模块的内容视图
struct HandbookModuleContentView: View {
    @EnvironmentObject private var store: TodoStore

    var body: some View {
        Text("手记内容视图")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 手记目录树占位符
struct HandbookTreePlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            SidebarSectionLabel("目录")
            Text("目录树即将实现")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
        }
        .padding(.horizontal, 17)
        .padding(.top, 14)
    }
}

/// TodoScope 切换按钮
/// 复用现有 DateButton 的视觉风格，作为导航视图中 scope 切换的占位组件
struct TodoScopeButton: View {
    let scope: TodoScope
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var title: String {
        switch scope {
        case .dashboard: "今日推进"
        case .all: "全部待办"
        case .waiting: "等待反馈"
        case .weekly: "本周固定"
        case .day: "按日期"
        }
    }

    private var subtitle: String {
        switch scope {
        case .dashboard: "风险优先，推进今天"
        case .all: "完整任务池"
        case .waiting: "需要别人推进"
        case .weekly: "重复管理动作"
        case .day: "选择某天查看"
        }
    }

    private var systemImage: String {
        switch scope {
        case .dashboard: "target"
        case .all: "tray.full.fill"
        case .waiting: "person.2.fill"
        case .weekly: "repeat"
        case .day: "calendar"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? AppTheme.accentWarm : Color.clear)
                    .frame(width: 3, height: 30)

                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(navBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.24) : AppTheme.adaptiveWhite(isHovered ? 0.36 : 0.0))
            )
        }
        .buttonStyle(.tactilePlain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { hovered in
            isHovered = hovered
        }
        .animation(AppMotion.hover, value: isHovered)
        .animation(AppMotion.smooth, value: isSelected)
    }

    private var navBackground: Color {
        if isSelected {
            return AppTheme.sidebarSelected
        }
        if isHovered {
            return AppTheme.adaptiveWhite(0.46)
        }
        return Color.clear
    }
}

// MARK: - 完整模块视图

/// 待办模块完整视图：导航树 + 详情面板
/// 由 ContentView 分发，通过 Binding 访问 ContentView 的状态
struct TodoModuleView: View {
    @EnvironmentObject private var store: TodoStore
    @EnvironmentObject private var aiSettings: AISettingsStore

    // 导航
    @Binding var scope: TodoScope

    // 搜索与视图模式
    @Binding var searchText: String
    @Binding var allTodosViewMode: AllTodosViewMode

    // 列表数据
    let filteredTodosCache: [TodoItem]
    let debouncedSearchText: String
    let highlightedTodoID: TodoItem.ID?
    @Binding var scrollTargetTodoID: TodoItem.ID?

    // 快记栏状态
    @Binding var newTitle: String
    @Binding var newPriority: TodoPriority
    @Binding var newProgress: TodoProgress
    @Binding var newDate: Date
    let previewDate: Date
    @Binding var newNotes: String
    @Binding var newIsWeekly: Bool
    @Binding var isQuickCaptureExpanded: Bool
    var focusedField: FocusState<FocusField?>.Binding
    let isCreatingTodo: Bool
    let aiStatusMessage: String?
    let quickCaptureAITrace: AITrace?
    let quickCaptureAIResultSummary: String?
    let isAIEnabled: Bool

    // 顶栏
    let contentTitle: String
    let contentSubtitle: String
    @Binding var isSecondarySidebarCollapsed: Bool
    let onOpenAISettings: () -> Void

    // 回调
    let onActivate: () -> Void
    let onCreate: () -> Void
    let onClear: () -> Void
    let onUpdate: (TodoItem, TodoDraft) -> Void
    let onProgressChange: (TodoItem, TodoProgress) -> Void
    let onToggle: (TodoItem) -> Void
    let onDelete: (TodoItem) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // 导航树（左侧）
            TodoSidebarView(scope: $scope)
                .frame(width: secondarySidebarWidth)
                .background(AppTheme.sidebar)

            // 详情（右侧）
            VStack(spacing: 0) {
                AppTopBar(
                    title: contentTitle,
                    subtitle: contentSubtitle,
                    isSecondarySidebarCollapsed: $isSecondarySidebarCollapsed,
                    isAIEnabled: isAIEnabled,
                    onOpenAISettings: onOpenAISettings
                )
                .frame(height: 48)

                Divider()
                    .overlay(AppTheme.hairline)

                taskColumn
            }
            .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
            .background {
                AppTheme.workSurface
                    .ignoresSafeArea(.container, edges: [.top, .bottom, .trailing])
            }
        }
    }

    private var taskColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
                .frame(height: 16)

            if let error = store.lastError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 10)
            }

            QuickCaptureBar(
                title: $newTitle,
                priority: $newPriority,
                progress: $newProgress,
                date: $newDate,
                previewDate: previewDate,
                notes: $newNotes,
                isWeekly: $newIsWeekly,
                isExpanded: $isQuickCaptureExpanded,
                focusedField: focusedField,
                onActivate: onActivate,
                onCreate: onCreate,
                onClear: onClear,
                isCreating: isCreatingTodo,
                aiStatusMessage: aiStatusMessage,
                aiTrace: quickCaptureAITrace,
                aiResultSummary: quickCaptureAIResultSummary,
                isAIEnabled: isAIEnabled
            )
            .padding(.horizontal, 28)
            .padding(.bottom, 8)

            ListToolbar(
                searchText: $searchText,
                allTodosViewMode: $allTodosViewMode,
                scope: scope
            )
            .padding(.horizontal, 28)
            .padding(.bottom, 10)

            TodoListView(
                todos: filteredTodosCache,
                scope: scope,
                allTodosViewMode: allTodosViewMode,
                onUpdate: onUpdate,
                onProgressChange: onProgressChange,
                onToggle: onToggle,
                onDelete: onDelete,
                highlightedTodoID: highlightedTodoID,
                scrollTargetTodoID: $scrollTargetTodoID,
                isSearching: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .background(AppTheme.workSurface)
    }
}

/// 手记模块完整视图：目录树 + 详情面板
struct HandbookModuleView: View {
    @EnvironmentObject private var store: TodoStore
    @EnvironmentObject private var aiSettings: AISettingsStore

    @Binding var handbookCategory: HandbookCategory?
    @Binding var handbookFolder: String?
    @Binding var handbookSearchText: String
    let debouncedHandbookSearchText: String

    // 顶栏
    let contentTitle: String
    let contentSubtitle: String
    @Binding var isSecondarySidebarCollapsed: Bool
    let isAIEnabled: Bool
    let onOpenAISettings: () -> Void

    // 回调
    let onCreate: (HandbookCategory, String, String, String, [HandbookAttachment]) -> Void
    let onUpdate: (HandbookItem, HandbookCategory, String, String, String, [HandbookAttachment]) -> Void
    let onDelete: (HandbookItem) -> Void

    @State private var selectedItemID: UUID?

    private var selectedItem: HandbookItem? {
        guard let selectedItemID else {
            return store.handbookItems.first
        }
        return store.handbookItems.first { $0.id == selectedItemID } ?? store.handbookItems.first
    }

    var body: some View {
        HStack(spacing: 0) {
            // 目录树（左侧）- 替代 HandbookSidebarView + HandbookContentView 的列表
            VStack(spacing: 0) {
                AppTopBar(
                    title: contentTitle,
                    subtitle: contentSubtitle,
                    isSecondarySidebarCollapsed: $isSecondarySidebarCollapsed,
                    isAIEnabled: isAIEnabled,
                    onOpenAISettings: onOpenAISettings
                )
                .frame(height: 48)

                Divider()
                    .overlay(AppTheme.hairline)

                HandbookTreeView(
                    items: store.handbookItems,
                    selectedCategory: $handbookCategory,
                    selectedFolder: $handbookFolder,
                    selectedItemID: $selectedItemID,
                    searchText: debouncedHandbookSearchText,
                    isLoaded: store.didLoadHandbookItems,
                    onSelect: { item in
                        selectedItemID = item.id
                    },
                    onCreate: { category, folder, title, body, attachments in
                        onCreate(category, folder, title, body, attachments)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: secondarySidebarWidth)
            .background(AppTheme.sidebar)

            // 详情面板（右侧）
            HandbookDetailPanel(
                item: selectedItem,
                onUpdate: { item, category, folder, title, body, attachments in
                    onUpdate(item, category, folder, title, body, attachments)
                },
                onDelete: { item in
                    onDelete(item)
                    if selectedItemID == item.id {
                        selectedItemID = nil
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                AppTheme.workSurface
                    .ignoresSafeArea(.container, edges: [.top, .bottom, .trailing])
            }
            .animation(AppMotion.smooth, value: selectedItemID)
        }
    }
}
