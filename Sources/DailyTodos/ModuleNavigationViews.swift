import SwiftUI

struct TodoContextSidebar: View {
    @Binding var scope: TodoScope
    @Binding var isSecondarySidebarCollapsed: Bool

    var body: some View {
        Group {
            if isSecondarySidebarCollapsed {
                CollapsedSecondarySidebarRail(title: "待办", isCollapsed: $isSecondarySidebarCollapsed)
                    .frame(width: collapsedSecondarySidebarWidth)
            } else {
                TodoSidebarView(scope: $scope, isCollapsed: $isSecondarySidebarCollapsed)
                    .frame(width: secondarySidebarWidth)
                    .background(AppTheme.sidebar)
            }
        }
    }
}

struct TodoWorkspaceContent: View {
    @EnvironmentObject private var store: TodoStore

    @Binding var searchText: String
    @Binding var allTodosViewMode: AllTodosViewMode
    let scope: TodoScope
    let filteredTodosCache: [TodoItem]
    let debouncedSearchText: String
    let highlightedTodoID: TodoItem.ID?
    @Binding var scrollTargetTodoID: TodoItem.ID?
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
    let contentTitle: String
    let contentSubtitle: String
    let onActivate: () -> Void
    let onCreate: () -> Void
    let onClear: () -> Void
    let onUpdate: (TodoItem, TodoDraft) -> Void
    let onProgressChange: (TodoItem, TodoProgress) -> Void
    let onToggle: (TodoItem) -> Void
    let onDelete: (TodoItem) -> Void

    var body: some View {
        WorkspaceContentContainer {
            ContentHeader(title: contentTitle, subtitle: contentSubtitle)
        } toolbar: {
            ContentToolbar {
                ListToolbar(searchText: $searchText, allTodosViewMode: $allTodosViewMode, scope: scope)
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: 0) {
                if let error = store.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
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
                .padding(.horizontal, 20)
                .padding(.top, 14)
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
                .padding(.horizontal, 14)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.workspaceSurface)
        }
    }
}

struct HandbookContextSidebar: View {
    @ObservedObject var workspaceModel: HandbookWorkspaceViewModel
    @Binding var handbookCategory: HandbookCategory?
    @Binding var handbookFolder: String?
    @Binding var isSecondarySidebarCollapsed: Bool
    let isLoaded: Bool
    let onUpdate: (HandbookItem, HandbookCategory, String, String, String, [HandbookAttachment]) -> Void

    var body: some View {
        Group {
            if isSecondarySidebarCollapsed {
                CollapsedSecondarySidebarRail(title: "手记", isCollapsed: $isSecondarySidebarCollapsed)
                    .frame(width: collapsedSecondarySidebarWidth)
            } else {
                HandbookFolderSidebarView(
                    sidebarIndex: workspaceModel.sidebarIndex,
                    selectedCategory: $handbookCategory,
                    selectedFolder: $handbookFolder,
                    isSecondarySidebarCollapsed: $isSecondarySidebarCollapsed,
                    isLoaded: isLoaded,
                    onMove: moveHandbookItems
                )
                .frame(width: secondarySidebarWidth)
                .background(AppTheme.sidebar)
            }
        }
    }

    private func moveHandbookItems(
        _ itemIDs: [UUID],
        category: HandbookCategory?,
        folder: String?
    ) -> Bool {
        var didMove = false
        for itemID in itemIDs {
            guard let item = workspaceModel.item(for: itemID) else { continue }
            onUpdate(item, category ?? item.category, folder ?? "", item.title, item.body, item.attachments)
            didMove = true
        }
        return didMove
    }
}

struct HandbookWorkspaceContent: View {
    @EnvironmentObject private var store: TodoStore

    @ObservedObject var workspaceModel: HandbookWorkspaceViewModel
    @Binding var handbookCategory: HandbookCategory?
    @Binding var handbookFolder: String?
    @Binding var handbookSearchText: String
    let debouncedHandbookSearchText: String
    let onCreate: (HandbookCategory, String, String, String, [HandbookAttachment]) -> HandbookItem?
    let onUpdate: (HandbookItem, HandbookCategory, String, String, String, [HandbookAttachment]) -> Void
    let onDelete: (HandbookItem) -> Void

    private let notesListWidth: CGFloat = 368

    var body: some View {
        WorkspaceContentContainer {
            ContentHeader(
                title: handbookCategory?.title ?? "全部手记",
                subtitle: handbookCategory?.subtitle ?? "收集业务规则、调研、会议和灵感"
            )
        } toolbar: {
            ContentToolbar {
                SearchField(text: $handbookSearchText)
                    .frame(maxWidth: 280)

                Button(action: createDraftHandbookItem) {
                    Label("新建", systemImage: "square.and.pencil")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.tactilePlain)
            }
        } bodyContent: {
            HStack(spacing: 0) {
                HandbookNotesListView(
                    snapshot: workspaceModel.listSnapshot,
                    selectedCategory: $handbookCategory,
                    selectedFolder: $handbookFolder,
                    searchText: $handbookSearchText,
                    selectedItemID: workspaceModel.selectedItemID,
                    isLoaded: store.didLoadHandbookItems,
                    onSelect: { workspaceModel.selectItem(id: $0) },
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
                    item: workspaceModel.selectedItem,
                    onUpdate: onUpdate,
                    onDelete: { item in
                        onDelete(item)
                        if workspaceModel.selectedItemID == item.id {
                            workspaceModel.selectItem(id: nil)
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppTheme.workspaceSurface)
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
}
