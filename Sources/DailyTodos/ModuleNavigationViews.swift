import SwiftUI

// MARK: - 完整模块视图

/// 待办模块完整视图：导航树 + 详情面板
/// 由 ContentView 分发，通过 Binding 访问 ContentView 的状态
struct TodoModuleView: View {
    @EnvironmentObject private var store: TodoStore

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
            secondarySidebar {
                TodoSidebarView(scope: $scope, isCollapsed: $isSecondarySidebarCollapsed)
            } collapsed: {
                CollapsedSecondarySidebarRail(title: "待办", isCollapsed: $isSecondarySidebarCollapsed)
            }

            // 详情（右侧）
            VStack(spacing: 0) {
                AppTopBar(
                    title: contentTitle,
                    subtitle: contentSubtitle
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

    @ViewBuilder
    private func secondarySidebar<Content: View, Collapsed: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder collapsed: () -> Collapsed
    ) -> some View {
        if isSecondarySidebarCollapsed {
            collapsed()
                .frame(width: collapsedSecondarySidebarWidth)
                .transition(.opacity)
        } else {
            content()
                .frame(width: secondarySidebarWidth)
                .background(AppTheme.sidebar)
                .transition(.move(edge: .leading).combined(with: .opacity))
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

    @Binding var handbookCategory: HandbookCategory?
    @Binding var handbookFolder: String?
    @Binding var handbookSearchText: String
    let debouncedHandbookSearchText: String

    @Binding var isSecondarySidebarCollapsed: Bool

    // 回调
    let onCreate: (HandbookCategory, String, String, String, [HandbookAttachment]) -> HandbookItem?
    let onUpdate: (HandbookItem, HandbookCategory, String, String, String, [HandbookAttachment]) -> Void
    let onDelete: (HandbookItem) -> Void

    @StateObject private var workspaceModel = HandbookWorkspaceViewModel()

    private let notesListWidth: CGFloat = 368

    private var selectedItem: HandbookItem? {
        workspaceModel.selectedItem
    }

    var body: some View {
        HStack(spacing: 0) {
            secondarySidebar {
                HandbookFolderSidebarView(
                    sidebarIndex: workspaceModel.sidebarIndex,
                    selectedCategory: $handbookCategory,
                    selectedFolder: $handbookFolder,
                    isSecondarySidebarCollapsed: $isSecondarySidebarCollapsed,
                    isLoaded: store.didLoadHandbookItems,
                    onMove: { itemIDs, category, folder in
                        var didMove = false
                        for itemID in itemIDs {
                            guard let item = workspaceModel.item(for: itemID) else { continue }
                            onUpdate(item, category ?? item.category, folder ?? "", item.title, item.body, item.attachments)
                            didMove = true
                        }
                        return didMove
                    }
                )
            } collapsed: {
                CollapsedSecondarySidebarRail(title: "手记", isCollapsed: $isSecondarySidebarCollapsed)
            }

            Divider()
                .overlay(AppTheme.hairline.opacity(0.72))

            HandbookNotesListView(
                snapshot: workspaceModel.listSnapshot,
                selectedCategory: $handbookCategory,
                selectedFolder: $handbookFolder,
                searchText: $handbookSearchText,
                selectedItemID: workspaceModel.selectedItemID,
                isLoaded: store.didLoadHandbookItems,
                onSelect: { itemID in
                    workspaceModel.selectItem(id: itemID)
                },
                onCreateDraft: createDraftHandbookItem,
                onDelete: { itemID in
                    guard let item = workspaceModel.item(for: itemID) else { return }
                    onDelete(item)
                    if workspaceModel.selectedItemID == item.id {
                        workspaceModel.selectItem(id: nil)
                    }
                }
            )
            .frame(width: notesListWidth)

            Divider()
                .overlay(AppTheme.hairline.opacity(0.72))

            HandbookDetailPanel(
                item: selectedItem,
                onUpdate: { item, category, folder, title, body, attachments in
                    onUpdate(item, category, folder, title, body, attachments)
                },
                onDelete: { item in
                    onDelete(item)
                    if workspaceModel.selectedItemID == item.id {
                        workspaceModel.selectItem(id: nil)
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                AppTheme.workSurface
                    .ignoresSafeArea(.container, edges: [.top, .bottom, .trailing])
            }
        }
        .onAppear {
            workspaceModel.refresh(
                items: store.handbookItems,
                selectedCategory: handbookCategory,
                selectedFolder: handbookFolder,
                searchText: debouncedHandbookSearchText
            )
        }
        .onChange(of: store.handbookItems) { _, newItems in
            workspaceModel.refresh(
                items: newItems,
                selectedCategory: handbookCategory,
                selectedFolder: handbookFolder,
                searchText: debouncedHandbookSearchText
            )
        }
        .onChange(of: handbookCategory) { _, _ in
            workspaceModel.updateScope(
                selectedCategory: handbookCategory,
                selectedFolder: handbookFolder,
                searchText: debouncedHandbookSearchText
            )
        }
        .onChange(of: handbookFolder) { _, _ in
            workspaceModel.updateScope(
                selectedCategory: handbookCategory,
                selectedFolder: handbookFolder,
                searchText: debouncedHandbookSearchText
            )
        }
        .onChange(of: debouncedHandbookSearchText) { _, _ in
            workspaceModel.updateScope(
                selectedCategory: handbookCategory,
                selectedFolder: handbookFolder,
                searchText: debouncedHandbookSearchText
            )
        }
    }

    private func createDraftHandbookItem() {
        let category = handbookCategory ?? .businessRule
        let folder = handbookFolder?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let createdItem = onCreate(category, folder, "未命名手记", "", []) else { return }
        handbookCategory = category
        handbookFolder = createdItem.trimmedFolder.isEmpty ? nil : createdItem.trimmedFolder
        workspaceModel.refresh(
            items: store.handbookItems,
            selectedCategory: handbookCategory,
            selectedFolder: handbookFolder,
            searchText: debouncedHandbookSearchText
        )
        workspaceModel.selectItem(id: createdItem.id)
    }

    @ViewBuilder
    private func secondarySidebar<Content: View, Collapsed: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder collapsed: () -> Collapsed
    ) -> some View {
        if isSecondarySidebarCollapsed {
            collapsed()
                .frame(width: collapsedSecondarySidebarWidth)
                .transition(.opacity)
        } else {
            content()
                .frame(width: secondarySidebarWidth)
                .background(AppTheme.sidebar)
                .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }
}
