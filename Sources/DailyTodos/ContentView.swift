import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: TodoStore
    @EnvironmentObject private var credentialStore: CredentialStore
    @EnvironmentObject private var credentialActions: CredentialManagementActions
    @EnvironmentObject private var aiSettings: AISettingsStore
    @EnvironmentObject private var updateController: UpdateController
    @EnvironmentObject private var moduleRegistry: AppModuleRegistry
    @AppStorage(AppSkin.storageKey) private var selectedSkinRawValue = AppSkin.ocean.rawValue
    @State private var scope: TodoScope = .all
    @State private var handbookCategory: HandbookCategory? = nil
    @State private var handbookFolder: String? = nil
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var handbookSearchText = ""
    @State private var debouncedHandbookSearchText = ""
    @State private var globalSearchText = ""
    @State private var newTitle = ""
    @State private var newPriority: TodoPriority = .medium
    @State private var newProgress: TodoProgress = .pending
    @State private var newDate = Date()
    @State private var didCustomizeNewDate = false
    @State private var newNotes = ""
    @State private var newIsWeekly = false
    @State private var isQuickCaptureExpanded = false
    @State private var isCreatingTodo = false
    @State private var aiStatusMessage: String?
    @State private var quickCaptureAITrace: AITrace?
    @State private var quickCaptureAIResultSummary: String?
    @State private var appSettingsSection: AppSettingsSection = .appearance
    @State private var credentialSearchText = ""
    @State private var credentialSelectedType: CredentialType?
    @State private var isSecondarySidebarCollapsed = false
    @State private var allTodosViewMode: AllTodosViewMode = .compact
    @State private var highlightedTodoID: TodoItem.ID?
    @State private var scrollTargetTodoID: TodoItem.ID?
    @State private var todoFeedback: TodoActionFeedback?
    @State private var filteredTodosCache: [TodoItem] = []
    @State private var todoSearchDebounceTask: Task<Void, Never>?
    @State private var handbookSearchDebounceTask: Task<Void, Never>?
    @StateObject private var handbookWorkspaceModel = HandbookWorkspaceViewModel()
    @FocusState private var focusedField: FocusField?

    private let calendar = Calendar.current

    var body: some View {
        WorkspaceShell(
            installedModules: moduleRegistry.installedModules,
            activeModuleID: Binding(
                get: { moduleRegistry.activeModuleID },
                set: { moduleRegistry.activate($0) }
            ),
            globalSearchText: $globalSearchText,
            hasUpdate: updateController.hasAvailableUpdate,
            onOpenSettings: { activateSettings(.appearance) },
            onActivateModule: { moduleRegistry.activate($0) },
            contextSidebar: { activeContextSidebarView },
            content: { activeWorkspaceContentView }
        )
        .overlay(alignment: .bottom) {
            if let todoFeedback {
                TodoFeedbackBanner(
                    feedback: todoFeedback,
                    onUndo: performTodoUndo,
                    onDismiss: dismissTodoFeedback
                )
                .padding(.leading, primarySidebarWidth)
                .padding(.bottom, 18)
                .transition(AppMotion.inlineTransition)
            }
        }
        .foregroundStyle(AppTheme.ink)
        .font(.system(size: 13, weight: .regular, design: .default))
        .id(selectedSkinRawValue)
        .onAppear {
            activeAppSkin = AppSkin(rawValue: selectedSkinRawValue) ?? .ocean
            activeColorScheme = colorScheme
            rebuildFilteredTodos()
        }
        .onChange(of: selectedSkinRawValue) { _, newValue in
            activeAppSkin = AppSkin(rawValue: newValue) ?? .ocean
        }
        .onChange(of: colorScheme) { _, newValue in
            activeColorScheme = newValue
        }
        .onChange(of: scope) { _, newValue in
            PerformanceMonitor.event("ContentView.todoScope", detail: newValue.analyticsName)
            rebuildFilteredTodos()
            guard !didCustomizeNewDate else {
                return
            }
            if case .day(let date) = newValue {
                newDate = dateOnSelectedDay(date, preservingTimeFrom: Date())
            } else {
                newDate = Date()
            }
        }
        .onChange(of: moduleRegistry.activeModuleID) { _, newValue in
            guard newValue == "handbook" else { return }
            store.scheduleLoadHandbookItemsIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTodoRequested)) { _ in
            moduleRegistry.activate("todos")
            focusQuickCapture()
        }
        .onChange(of: searchText) { _, newValue in
            debounceSearchText(newValue)
        }
        .onChange(of: handbookSearchText) { _, newValue in
            debounceHandbookSearchText(newValue)
        }
        .onChange(of: debouncedSearchText) { _, _ in
            rebuildFilteredTodos()
        }
        .onChange(of: store.todos) { _, _ in
            rebuildFilteredTodos()
        }
    }

    @ViewBuilder
    private var activeContextSidebarView: some View {
        switch moduleRegistry.activeModuleID {
        case "todos":
            TodoContextSidebar(scope: $scope, isSecondarySidebarCollapsed: $isSecondarySidebarCollapsed)
        case "handbook":
            HandbookContextSidebar(
                workspaceModel: handbookWorkspaceModel,
                handbookCategory: $handbookCategory,
                handbookFolder: $handbookFolder,
                isSecondarySidebarCollapsed: $isSecondarySidebarCollapsed,
                isLoaded: store.didLoadHandbookItems,
                onUpdate: updateHandbookItem
            )
        case "credentials":
            CredentialContextSidebar(
                searchText: $credentialSearchText,
                selectedType: $credentialSelectedType
            )
                .environmentObject(credentialStore)
        case "settings":
            SettingsContextSidebar(selectedSection: $appSettingsSection)
                .environmentObject(updateController)
                .environmentObject(aiSettings)
        case "account":
            EmptyWorkspaceContextSidebar(title: "账户")
        default:
            EmptyWorkspaceContextSidebar(title: "模块")
        }
    }

    @ViewBuilder
    private var activeWorkspaceContentView: some View {
        switch moduleRegistry.activeModuleID {
        case "todos":
            todoWorkspaceContentView
        case "handbook":
            handbookWorkspaceContentView
        case "credentials":
            CredentialsModuleView(
                searchText: $credentialSearchText,
                selectedType: $credentialSelectedType
            )
        case "settings":
            SettingsModuleView(
                selectedSkinRawValue: $selectedSkinRawValue,
                selectedSection: $appSettingsSection
            )
            .environmentObject(updateController)
            .environmentObject(moduleRegistry)
            .environmentObject(aiSettings)
            .environmentObject(credentialStore)
            .environmentObject(credentialActions)
        case "account":
            AccountModuleView()
        default:
            Text("未知模块")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var todoWorkspaceContentView: some View {
        TodoWorkspaceContent(
            searchText: $searchText,
            allTodosViewMode: $allTodosViewMode,
            scope: scope,
            filteredTodosCache: filteredTodosCache,
            debouncedSearchText: debouncedSearchText,
            highlightedTodoID: highlightedTodoID,
            scrollTargetTodoID: $scrollTargetTodoID,
            newTitle: $newTitle,
            newPriority: $newPriority,
            newProgress: $newProgress,
            newDate: quickCaptureDateBinding,
            previewDate: quickCaptureFallbackDate(),
            newNotes: $newNotes,
            newIsWeekly: $newIsWeekly,
            isQuickCaptureExpanded: $isQuickCaptureExpanded,
            focusedField: $focusedField,
            isCreatingTodo: isCreatingTodo,
            aiStatusMessage: aiStatusMessage,
            quickCaptureAITrace: quickCaptureAITrace,
            quickCaptureAIResultSummary: quickCaptureAIResultSummary,
            isAIEnabled: aiSettings.canUseAI,
                contentTitle: todoContentTitle,
                contentSubtitle: todoContentSubtitle,
            onActivate: focusQuickCapture,
            onCreate: createTodo,
            onClear: cancelCreate,
            onUpdate: updateTodo,
            onProgressChange: updateProgress,
            onToggle: toggleTodo,
            onDelete: deleteTodo
        )
    }

    private var handbookWorkspaceContentView: some View {
        HandbookWorkspaceContent(
            workspaceModel: handbookWorkspaceModel,
            handbookCategory: $handbookCategory,
            handbookFolder: $handbookFolder,
            handbookSearchText: $handbookSearchText,
            debouncedHandbookSearchText: debouncedHandbookSearchText,
            onCreate: createHandbookItem,
            onUpdate: updateHandbookItem,
            onDelete: deleteHandbookItem
        )
    }

    private func rebuildFilteredTodos() {
        switch scope {
        case .dashboard:
            filteredTodosCache = store.todos(matching: debouncedSearchText)
        case .all:
            filteredTodosCache = store.todos(matching: debouncedSearchText)
        case .day(let date):
            filteredTodosCache = store.todos(on: date, matching: debouncedSearchText)
        case .waiting:
            filteredTodosCache = store.todos(matching: debouncedSearchText).filter { $0.progress == .waiting }
        case .weekly:
            filteredTodosCache = store.todos(matching: debouncedSearchText).filter(\.isWeekly)
        }
    }

    private func activateSettings(_ section: AppSettingsSection) {
        appSettingsSection = section
        moduleRegistry.activate("settings")
    }

    private var todoContentTitle: String {
        dayTitle
    }

    private var todoContentSubtitle: String {
        daySubtitle
    }

    private var dayTitle: String {
        switch scope {
        case .dashboard:
            return "今日推进"
        case .all:
            return "全部待办"
        case .waiting:
            return "等待反馈"
        case .weekly:
            return "本周固定"
        case .day(let selectedDate):
            if calendar.isDateInToday(selectedDate) {
                return "今天"
            }
            if calendar.isDateInTomorrow(selectedDate) {
                return "明天"
            }
            if calendar.isDateInYesterday(selectedDate) {
                return "昨天"
            }
            return selectedDate.formatted(.dateTime.month(.wide).day())
        }
    }

    private var daySubtitle: String {
        switch scope {
        case .dashboard:
            return dashboardSubtitle
        case .all:
            return "完整任务池，按当前视图阅读"
        case .waiting:
            return "所有需要别人反馈或推进的事项"
        case .weekly:
            return "每周重复出现的管理动作"
        case .day(let selectedDate):
            return selectedDate.formatted(.dateTime.year().month().day().weekday(.wide))
        }
    }

    private var dashboardSubtitle: String {
        let today = Date().formatted(.dateTime.year().month().day().weekday(.wide))
        return "\(today)，先处理风险，再推进今天"
    }

    private var overdueTodos: [TodoItem] {
        filteredTodosCache.filter { todo in
            todo.progress != .done
                && todo.progress != .waiting
                && calendar.startOfDay(for: todo.date) < calendar.startOfDay(for: Date())
        }
    }

    private var todayActiveTodos: [TodoItem] {
        filteredTodosCache.filter { todo in
            todo.progress != .done
                && todo.progress != .waiting
                && calendar.isDateInToday(todo.date)
        }
    }

    private var waitingTodos: [TodoItem] {
        store.todos(matching: searchText).filter { $0.progress == .waiting }
    }

    private var weeklyTodos: [TodoItem] {
        store.todos(matching: searchText).filter(\.isWeekly)
    }

    private func createTodo() {
        guard !isCreatingTodo else { return }
        let now = Date()
        let parsedInput = TodoQuickInputParser.parse(
            title: newTitle,
            notes: newNotes,
            priority: newPriority,
            date: quickCaptureFallbackDate(now: now),
            progress: newProgress,
            isWeekly: newIsWeekly,
            calendar: calendar,
            now: now
        )
        guard !parsedInput.title.isEmpty else {
            focusedField = .newTitle
            return
        }

        let rawTitle = newTitle
        let rawNotes = newNotes
        let aiConfiguration = aiSettings.configuration
        let aiAPIKey = aiSettings.apiKey

        if aiSettings.canUseAI {
            isCreatingTodo = true
            aiStatusMessage = "AI 正在解析快记..."
            quickCaptureAITrace = nil
            quickCaptureAIResultSummary = nil
            Task {
                do {
                    let aiResult = try await AIClient.shared.parseQuickInput(
                        rawTitle: rawTitle,
                        rawNotes: rawNotes,
                        fallback: parsedInput,
                        configuration: aiConfiguration,
                        apiKey: aiAPIKey,
                        calendar: calendar
                    )
                    await MainActor.run {
                        quickCaptureAITrace = aiResult.trace
                        quickCaptureAIResultSummary = aiResultSummary(from: parsedInput, to: aiResult.input)
                        finishCreateTodo(with: aiResult.input)
                        aiStatusMessage = nil
                        isCreatingTodo = false
                    }
                } catch {
                    await MainActor.run {
                        finishCreateTodo(with: parsedInput)
                        aiStatusMessage = "AI 解析失败，已用本地规则记录"
                        quickCaptureAITrace = nil
                        quickCaptureAIResultSummary = nil
                        isCreatingTodo = false
                    }
                }
            }
            return
        }

        finishCreateTodo(with: parsedInput)
    }

    private func finishCreateTodo(with parsedInput: ParsedTodoInput) {
        guard !parsedInput.title.isEmpty else {
            focusedField = .newTitle
            return
        }

        let resetDate = quickCaptureResetDate(afterCreating: parsedInput.date)

        withAnimation(AppMotion.capture) {
            let createdTodo = store.add(
                title: parsedInput.title,
                notes: parsedInput.notes,
                priority: parsedInput.priority,
                date: parsedInput.date,
                progress: parsedInput.progress,
                isWeekly: parsedInput.isWeekly
            )
            highlightTodo(createdTodo?.id, shouldScroll: true)
            showTodoFeedback(
                TodoActionFeedback(
                    message: "已记录：\(parsedInput.title)",
                    systemImage: "plus.circle.fill",
                    undoAction: nil
                )
            )
            if case .day = scope {
                scope = .day(parsedInput.date)
            }
            newTitle = ""
            newPriority = .medium
            newProgress = .pending
            newNotes = ""
            didCustomizeNewDate = false
            newDate = resetDate
            newIsWeekly = false
            isQuickCaptureExpanded = false
        }
        focusedField = .newTitle
    }

    private func updateTodo(_ todo: TodoItem, _ draft: TodoDraft) {
        let existingTodoIDs = Set(store.todos.map(\.id))
        withAnimation(AppMotion.smooth) {
            store.update(
                todo,
                title: draft.title,
                notes: draft.notes,
                priority: draft.priority,
                date: draft.date,
                progress: draft.progress,
                isWeekly: draft.isWeekly
            )
            let generatedTodos = todosCreated(after: existingTodoIDs)
            highlightTodo(todo.id, shouldScroll: true)
            showTodoFeedback(
                TodoActionFeedback(
                    message: "已更新：\(draft.title.trimmingCharacters(in: .whitespacesAndNewlines))",
                    systemImage: "checkmark.circle.fill",
                    undoAction: .revertTodo(todo, generatedTodos: generatedTodos)
                )
            )
        }
    }

    private func updateProgress(_ todo: TodoItem, _ progress: TodoProgress) {
        let existingTodoIDs = Set(store.todos.map(\.id))
        withAnimation(AppMotion.status) {
            store.update(
                todo,
                title: todo.title,
                notes: todo.notes,
                priority: todo.priority,
                date: todo.date,
                progress: progress,
                isWeekly: todo.isWeekly
            )
            let generatedTodos = todosCreated(after: existingTodoIDs)
            highlightTodo(todo.id, shouldScroll: true)
            showTodoFeedback(
                TodoActionFeedback(
                    message: "已改为\(progress.label)",
                    systemImage: "arrow.triangle.2.circlepath.circle.fill",
                    undoAction: .revertTodo(todo, generatedTodos: generatedTodos)
                )
            )
        }
    }

    private func toggleTodo(_ todo: TodoItem) {
        let existingTodoIDs = Set(store.todos.map(\.id))
        withAnimation(AppMotion.complete) {
            store.toggle(todo)
            let generatedTodos = todosCreated(after: existingTodoIDs)
            highlightTodo(todo.id, shouldScroll: true)
            let isCompleting = todo.progress != .done
            showTodoFeedback(
                TodoActionFeedback(
                    message: isCompleting ? "已完成：\(todo.trimmedTitle)" : "已恢复待处理：\(todo.trimmedTitle)",
                    systemImage: isCompleting ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill",
                    undoAction: .revertTodo(todo, generatedTodos: generatedTodos)
                )
            )
        }
    }

    private func deleteTodo(_ todo: TodoItem) {
        withAnimation(AppMotion.quick) {
            store.delete(todo)
            showTodoFeedback(
                TodoActionFeedback(
                    message: "已删除：\(todo.trimmedTitle)",
                    systemImage: "trash.circle.fill",
                    undoAction: .restoreDeleted(todo)
                )
            )
        }
    }

    private func createHandbookItem(
        category: HandbookCategory,
        folder: String,
        title: String,
        body: String,
        attachments: [HandbookAttachment]
    ) -> HandbookItem? {
        var createdItem: HandbookItem?
        withAnimation(AppMotion.capture) {
            createdItem = store.addHandbookItem(category: category, folder: folder, title: title, body: body, attachments: attachments)
            handbookCategory = category
            handbookFolder = folder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : folder.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return createdItem
    }

    private func updateHandbookItem(
        _ item: HandbookItem,
        category: HandbookCategory,
        folder: String,
        title: String,
        body: String,
        attachments: [HandbookAttachment]
    ) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            store.update(item, category: category, folder: folder, title: title, body: body, attachments: attachments)
        }
    }

    private func deleteHandbookItem(_ item: HandbookItem) {
        withAnimation(AppMotion.quick) {
            store.delete(item)
        }
    }

    private func focusQuickCapture() {
        if !didCustomizeNewDate {
            newDate = quickCaptureFallbackDate()
        }
        withAnimation(AppMotion.smooth) {
            isQuickCaptureExpanded = true
        }
        focusedField = .newTitle
    }

    private func cancelCreate() {
        guard !isCreatingTodo else { return }
        newTitle = ""
        newPriority = .medium
        newProgress = .pending
        didCustomizeNewDate = false
        newDate = quickCaptureFallbackDate()
        newNotes = ""
        newIsWeekly = false
        aiStatusMessage = nil
        quickCaptureAITrace = nil
        quickCaptureAIResultSummary = nil
        withAnimation(AppMotion.smooth) {
            isQuickCaptureExpanded = false
        }
    }

    private func aiResultSummary(from local: ParsedTodoInput, to ai: ParsedTodoInput) -> String {
        var changes: [String] = []
        if local.priority != ai.priority {
            changes.append("优先级 \(ai.priority.label)")
        }
        if local.progress != ai.progress {
            changes.append("状态 \(ai.progress.shortLabel)")
        }
        if !calendar.isDate(local.date, equalTo: ai.date, toGranularity: .minute) {
            changes.append("时间 \(compactDateTime(ai.date))")
        }
        if local.isWeekly != ai.isWeekly {
            changes.append(ai.isWeekly ? "固定每周" : "非固定")
        }
        if local.notes != ai.notes, !ai.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            changes.append("备注已识别")
        }
        if changes.isEmpty {
            return "AI 已校验，采用本地解析结果"
        }
        return "AI 已修正：" + changes.joined(separator: " / ")
    }

    private var quickCaptureDateBinding: Binding<Date> {
        Binding(
            get: { newDate },
            set: { updatedDate in
                newDate = updatedDate
                didCustomizeNewDate = true
            }
        )
    }

    private func quickCaptureFallbackDate(now: Date = Date()) -> Date {
        if didCustomizeNewDate {
            return newDate
        }
        if case .day(let selectedDate) = scope {
            return dateOnSelectedDay(selectedDate, preservingTimeFrom: now)
        }
        return now
    }

    private func quickCaptureResetDate(afterCreating createdDate: Date) -> Date {
        let now = Date()
        if case .day = scope {
            return dateOnSelectedDay(createdDate, preservingTimeFrom: now)
        }
        return now
    }

    private func dateOnSelectedDay(_ selectedDate: Date, preservingTimeFrom referenceDate: Date) -> Date {
        var dayComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: referenceDate)
        dayComponents.hour = timeComponents.hour
        dayComponents.minute = timeComponents.minute
        dayComponents.second = timeComponents.second
        return calendar.date(from: dayComponents) ?? selectedDate
    }

    private func highlightTodo(_ id: TodoItem.ID?, shouldScroll: Bool = false) {
        highlightedTodoID = id
        if shouldScroll {
            scrollTargetTodoID = id
        }
        guard let id else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(1300))
            await MainActor.run {
                if highlightedTodoID == id {
                    withAnimation(AppMotion.smooth) {
                        highlightedTodoID = nil
                    }
                }
            }
        }
    }

    private func showTodoFeedback(_ feedback: TodoActionFeedback) {
        todoFeedback = feedback
        Task {
            try? await Task.sleep(for: .seconds(4))
            await MainActor.run {
                if todoFeedback?.id == feedback.id {
                    withAnimation(AppMotion.smooth) {
                        todoFeedback = nil
                    }
                }
            }
        }
    }

    private func dismissTodoFeedback() {
        withAnimation(AppMotion.quick) {
            todoFeedback = nil
        }
    }

    private func performTodoUndo(_ action: TodoUndoAction) {
        withAnimation(AppMotion.smooth) {
            switch action {
            case .restoreDeleted(let todo):
                store.restore(todo)
                highlightTodo(todo.id, shouldScroll: true)
                showTodoFeedback(
                    TodoActionFeedback(
                        message: "已恢复：\(todo.trimmedTitle)",
                        systemImage: "arrow.uturn.backward.circle.fill",
                        undoAction: nil
                    )
                )
            case .revertTodo(let todo, let generatedTodos):
                generatedTodos.forEach { generatedTodo in
                    store.delete(generatedTodo)
                }
                store.update(
                    todo,
                    title: todo.title,
                    notes: todo.notes,
                    priority: todo.priority,
                    date: todo.date,
                    progress: todo.progress,
                    isWeekly: todo.isWeekly
                )
                highlightTodo(todo.id, shouldScroll: true)
                showTodoFeedback(
                    TodoActionFeedback(
                        message: "已撤销：\(todo.trimmedTitle)",
                        systemImage: "arrow.uturn.backward.circle.fill",
                        undoAction: nil
                    )
                )
            }
        }
    }

    private func todosCreated(after existingTodoIDs: Set<TodoItem.ID>) -> [TodoItem] {
        store.todos.filter { !existingTodoIDs.contains($0.id) }
    }

    private func debounceSearchText(_ value: String) {
        todoSearchDebounceTask?.cancel()
        todoSearchDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if searchText == value {
                    withAnimation(AppMotion.quick) {
                        debouncedSearchText = value
                    }
                }
            }
        }
    }

    private func debounceHandbookSearchText(_ value: String) {
        handbookSearchDebounceTask?.cancel()
        handbookSearchDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if handbookSearchText == value {
                    withAnimation(AppMotion.quick) {
                        debouncedHandbookSearchText = value
                    }
                }
            }
        }
    }

    private func compactDateTime(_ date: Date) -> String {
        let timeText = timeSuffix(for: date, calendar: calendar)
        if calendar.isDateInToday(date) { return "今天\(timeText)" }
        if calendar.isDateInTomorrow(date) { return "明天\(timeText)" }
        if calendar.isDateInYesterday(date) { return "昨天\(timeText)" }
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)/\(day)\(timeText)"
    }
}
