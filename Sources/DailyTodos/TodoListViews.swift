import SwiftUI

struct ListToolbar: View {
    @Binding var searchText: String
    @Binding var allTodosViewMode: AllTodosViewMode
    let scope: TodoScope

    var body: some View {
        HStack(spacing: 8) {
            SearchField(text: $searchText)
                .frame(minWidth: 160, maxWidth: .infinity)
                .frame(height: 30)

            if scope == .all {
                Divider()
                    .frame(height: 22)
                    .overlay(AppTheme.adaptiveBlack(0.10))
                AllTodosViewModePicker(selection: $allTodosViewMode)
            }
        }
    }
}

struct TodoListView: View {
    @EnvironmentObject private var aiSettings: AISettingsStore

    let todos: [TodoItem]
    let scope: TodoScope
    let allTodosViewMode: AllTodosViewMode
    let onUpdate: (TodoItem, TodoDraft) -> Void
    let onProgressChange: (TodoItem, TodoProgress) -> Void
    let onToggle: (TodoItem) -> Void
    let onDelete: (TodoItem) -> Void
    let highlightedTodoID: TodoItem.ID?
    @Binding var scrollTargetTodoID: TodoItem.ID?
    let isSearching: Bool

    @State private var dailySuggestion: String?
    @State private var dailySuggestionError: String?
    @State private var dailySuggestionTrace: AITrace?
    @State private var dailySuggestionStep: String?
    @State private var isGeneratingDailySuggestion = false

    var body: some View {
        let snapshot = TodoListSnapshot(todos: todos)
        ScrollViewReader { proxy in
            ScrollView {
                listBody(snapshot: snapshot)
            }
            .onChange(of: scrollTargetTodoID) { _, targetID in
                guard let targetID, todos.contains(where: { $0.id == targetID }) else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(90))
                    await MainActor.run {
                        withAnimation(AppMotion.smooth) {
                            proxy.scrollTo(targetID, anchor: .center)
                        }
                        scrollTargetTodoID = nil
                    }
                }
            }
        }
        .animation(isSearching ? AppMotion.quick : AppMotion.modeSwitch, value: scope)
        .animation(isSearching ? AppMotion.quick : AppMotion.modeSwitch, value: allTodosViewMode)
        .animation(isSearching ? AppMotion.quick : AppMotion.list, value: todos.count)
    }

    @ViewBuilder
    private func listBody(snapshot: TodoListSnapshot) -> some View {
        if scope == .dashboard {
            dashboardList(snapshot: snapshot)
                .id("dashboard")
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .transition(AppMotion.viewTransition)
        } else if isCompactAllTodos {
            compactList
                .id("all-todos-compact")
                .padding(6)
                .transition(AppMotion.viewTransition)
        } else if isBoardAllTodos {
            boardList(snapshot: snapshot)
                .id("all-todos-board")
                .padding(6)
                .transition(AppMotion.viewTransition)
        } else if isMatrixAllTodos {
            matrixList(snapshot: snapshot)
                .id("all-todos-matrix")
                .padding(6)
                .transition(AppMotion.viewTransition)
        } else {
            groupedList(snapshot: snapshot)
                .id("todos-grouped")
                .padding(6)
                .transition(AppMotion.viewTransition)
        }
    }

    private func dashboardList(snapshot: TodoListSnapshot) -> some View {
        LazyVStack(spacing: 4) {
            if aiSettings.canUseAI {
                DailySuggestionCard(
                    suggestion: dailySuggestion,
                    error: dailySuggestionError,
                    trace: dailySuggestionTrace,
                    step: dailySuggestionStep,
                    isLoading: isGeneratingDailySuggestion,
                    onGenerate: generateDailySuggestion
                )
            }

            DashboardSummaryStrip(groups: snapshot.dashboardGroups)

            ForEach(snapshot.dashboardGroups) { group in
                if !group.todos.isEmpty {
                    WorkSection(group: group) { todo in
                        TodoFlowRow(
                            todo: todo,
                            onToggle: { onToggle(todo) },
                            onProgressChange: { progress in onProgressChange(todo, progress) },
                            onUpdate: { draft in onUpdate(todo, draft) },
                            onDelete: { onDelete(todo) },
                            isHighlighted: highlightedTodoID == todo.id
                        )
                        .equatable()
                        .id(todo.id)
                    }
                }
            }

            if snapshot.dashboardGroups.allSatisfy({ $0.todos.isEmpty }) {
                EmptyTodoHint(isAllScope: false)
            }
        }
    }

    private func generateDailySuggestion() {
        guard aiSettings.canUseAI, !isGeneratingDailySuggestion else { return }
        isGeneratingDailySuggestion = true
        dailySuggestionError = nil
        dailySuggestionTrace = nil
        dailySuggestionStep = "正在整理未完成事项"
        let configuration = aiSettings.configuration
        let apiKey = aiSettings.apiKey
        let sourceTodos = todos
        Task {
            do {
                await MainActor.run {
                    dailySuggestionStep = "正在请求 DeepSeek"
                }
                let result = try await AIClient.shared.dailySuggestion(
                    todos: sourceTodos,
                    configuration: configuration,
                    apiKey: apiKey
                )
                await MainActor.run {
                    withAnimation(AppMotion.reveal) {
                        dailySuggestion = result.content
                        dailySuggestionTrace = result.trace
                        dailySuggestionStep = "已收到模型返回"
                        isGeneratingDailySuggestion = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(AppMotion.reveal) {
                        dailySuggestionError = error.localizedDescription
                        dailySuggestionStep = "请求失败，未更新建议"
                        isGeneratingDailySuggestion = false
                    }
                }
            }
        }
    }

    private var isCompactAllTodos: Bool {
        scope == .all && allTodosViewMode == .compact
    }

    private var isBoardAllTodos: Bool {
        scope == .all && allTodosViewMode == .board
    }

    private var isMatrixAllTodos: Bool {
        scope == .all && allTodosViewMode == .matrix
    }

    private var compactList: some View {
        LazyVStack(spacing: 3) {
            if todos.isEmpty {
                EmptyTodoHint(isAllScope: true)
            } else {
                ForEach(todos) { todo in
                    TodoFlowRow(
                        todo: todo,
                        onToggle: { onToggle(todo) },
                        onProgressChange: { progress in onProgressChange(todo, progress) },
                        onUpdate: { draft in onUpdate(todo, draft) },
                        onDelete: { onDelete(todo) },
                        isHighlighted: highlightedTodoID == todo.id
                    )
                    .equatable()
                    .id(todo.id)
                    .transition(AppMotion.rowTransition)
                }
            }
        }
    }

    private func groupedList(snapshot: TodoListSnapshot) -> some View {
        LazyVStack(spacing: 3) {
            if todos.isEmpty {
                EmptyTodoHint(isAllScope: scope == .all)
            } else if scope == .all {
                ForEach(snapshot.groupedTodos) { group in
                    TodoDateGroupHeader(date: group.date, count: group.todos.count)
                    ForEach(group.todos) { todo in
                        TodoFlowRow(
                            todo: todo,
                            onToggle: { onToggle(todo) },
                            onProgressChange: { progress in onProgressChange(todo, progress) },
                            onUpdate: { draft in onUpdate(todo, draft) },
                            onDelete: { onDelete(todo) },
                            isHighlighted: highlightedTodoID == todo.id
                        )
                        .equatable()
                        .id(todo.id)
                        .transition(AppMotion.rowTransition)
                    }
                }
            } else {
                ForEach(todos) { todo in
                    TodoFlowRow(
                        todo: todo,
                        onToggle: { onToggle(todo) },
                        onProgressChange: { progress in onProgressChange(todo, progress) },
                        onUpdate: { draft in onUpdate(todo, draft) },
                        onDelete: { onDelete(todo) },
                        isHighlighted: highlightedTodoID == todo.id
                    )
                    .equatable()
                    .id(todo.id)
                    .transition(AppMotion.rowTransition)
                }
            }
        }
    }

    private func boardList(snapshot: TodoListSnapshot) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(TodoProgress.allCases) { progress in
                    TodoBoardColumn(
                        progress: progress,
                        todos: snapshot.boardGroups[progress, default: []],
                        onToggle: onToggle,
                        onProgressChange: onProgressChange,
                        onUpdate: onUpdate,
                        onDelete: onDelete,
                        highlightedTodoID: highlightedTodoID
                    )
                    .frame(width: 300)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func matrixList(snapshot: TodoListSnapshot) -> some View {
        LazyVGrid(columns: matrixColumns, alignment: .leading, spacing: 12) {
            ForEach(snapshot.matrixGroups) { group in
                TodoMatrixQuadrant(
                    group: group,
                    onToggle: onToggle,
                    onProgressChange: onProgressChange,
                    onUpdate: onUpdate,
                    onDelete: onDelete,
                    highlightedTodoID: highlightedTodoID
                )
                .transition(AppMotion.rowTransition)
            }
        }
    }

    private var matrixColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 300), spacing: 12),
            GridItem(.flexible(minimum: 300), spacing: 12)
        ]
    }
}

struct TodoListSnapshot: Equatable {
    let groupedTodos: [TodoDateGroup]
    let dashboardGroups: [WorkSectionGroup]
    let boardGroups: [TodoProgress: [TodoItem]]
    let matrixGroups: [TodoMatrixGroup]

    init(todos: [TodoItem], calendar: Calendar = .current, now: Date = Date()) {
        let today = calendar.startOfDay(for: now)
        var overdue: [TodoItem] = []
        var todayItems: [TodoItem] = []
        var waiting: [TodoItem] = []
        var weekly: [TodoItem] = []
        var boardGroups: [TodoProgress: [TodoItem]] = [:]
        var groupedByDate: [Date: [TodoItem]] = [:]
        var buckets = Dictionary(uniqueKeysWithValues: TodoMatrixKind.allCases.map { ($0, [TodoItem]()) })

        func isImportant(_ todo: TodoItem) -> Bool {
            todo.priority == .high
        }

        func isUrgent(_ todo: TodoItem) -> Bool {
            todo.progress != .waiting && calendar.startOfDay(for: todo.date) <= today
        }

        for todo in todos {
            let day = calendar.startOfDay(for: todo.date)
            groupedByDate[day, default: []].append(todo)
            boardGroups[todo.progress, default: []].append(todo)

            guard todo.progress != .done else { continue }

            if todo.progress == .waiting {
                waiting.append(todo)
            } else if day < today {
                overdue.append(todo)
            } else if calendar.isDateInToday(todo.date) {
                todayItems.append(todo)
            } else if todo.isWeekly {
                weekly.append(todo)
            }

            let matrixKind: TodoMatrixKind
            switch (isUrgent(todo), isImportant(todo)) {
            case (true, true): matrixKind = .urgentImportant
            case (false, true): matrixKind = .importantNotUrgent
            case (true, false): matrixKind = .urgentNotImportant
            case (false, false): matrixKind = .notUrgentNotImportant
            }
            buckets[matrixKind, default: []].append(todo)
        }

        self.groupedTodos = groupedByDate
            .map { TodoDateGroup(date: $0.key, todos: $0.value) }
            .sorted { $0.date > $1.date }
        self.dashboardGroups = [
            WorkSectionGroup(kind: .overdue, todos: overdue),
            WorkSectionGroup(kind: .today, todos: todayItems),
            WorkSectionGroup(kind: .waiting, todos: waiting),
            WorkSectionGroup(kind: .weekly, todos: weekly)
        ]
        self.boardGroups = boardGroups
        self.matrixGroups = TodoMatrixKind.allCases.map { kind in
            TodoMatrixGroup(kind: kind, todos: buckets[kind, default: []])
        }
    }
}

struct TodoDateGroup: Identifiable, Equatable {
    let date: Date
    let todos: [TodoItem]

    var id: Date { date }
}

enum TodoMatrixKind: String, CaseIterable, Identifiable {
    case urgentImportant
    case importantNotUrgent
    case urgentNotImportant
    case notUrgentNotImportant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .urgentImportant: "立即推进"
        case .importantNotUrgent: "计划推进"
        case .urgentNotImportant: "快速处理"
        case .notUrgentNotImportant: "低压跟进"
        }
    }

    var subtitle: String {
        switch self {
        case .urgentImportant: "重要且紧急"
        case .importantNotUrgent: "重要但不紧急"
        case .urgentNotImportant: "紧急但不重要"
        case .notUrgentNotImportant: "不紧急也不重要"
        }
    }

    var icon: String {
        switch self {
        case .urgentImportant: "flame.fill"
        case .importantNotUrgent: "calendar.badge.clock"
        case .urgentNotImportant: "bolt.fill"
        case .notUrgentNotImportant: "tray.fill"
        }
    }

    var color: Color {
        switch self {
        case .urgentImportant: TodoPriority.high.displayColor
        case .importantNotUrgent: AppTheme.accent
        case .urgentNotImportant: Color(red: 0.86, green: 0.44, blue: 0.16)
        case .notUrgentNotImportant: AppTheme.mutedInk
        }
    }
}

struct TodoMatrixGroup: Identifiable, Equatable {
    let kind: TodoMatrixKind
    let todos: [TodoItem]

    var id: TodoMatrixKind { kind }
}

struct TodoMatrixQuadrant: View {
    let group: TodoMatrixGroup
    let onToggle: (TodoItem) -> Void
    let onProgressChange: (TodoItem, TodoProgress) -> Void
    let onUpdate: (TodoItem, TodoDraft) -> Void
    let onDelete: (TodoItem) -> Void
    let highlightedTodoID: TodoItem.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: group.kind.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(group.kind.color)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(group.kind.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(group.kind.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Text("\(group.todos.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(group.kind.color)
                    .frame(minWidth: 24, minHeight: 22)
                    .background(group.kind.color.opacity(0.10), in: Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            LazyVStack(spacing: 4) {
                if group.todos.isEmpty {
                    Text("暂无事项")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(AppTheme.adaptiveWhite(0.78), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    ForEach(group.todos) { todo in
                        TodoFlowRow(
                            todo: todo,
                            onToggle: { onToggle(todo) },
                            onProgressChange: { progress in onProgressChange(todo, progress) },
                            onUpdate: { draft in onUpdate(todo, draft) },
                            onDelete: { onDelete(todo) },
                            editStyle: .compact,
                            isHighlighted: highlightedTodoID == todo.id
                        )
                        .id(todo.id)
                        .transition(AppMotion.rowTransition)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
        .background(group.kind.color.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(group.kind.color.opacity(0.16), lineWidth: 1)
        )
    }
}

struct TodoBoardColumn: View {
    let progress: TodoProgress
    let todos: [TodoItem]
    let onToggle: (TodoItem) -> Void
    let onProgressChange: (TodoItem, TodoProgress) -> Void
    let onUpdate: (TodoItem, TodoDraft) -> Void
    let onDelete: (TodoItem) -> Void
    let highlightedTodoID: TodoItem.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: progress.boardIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(progress.displayColor)
                Text(progress.boardTitle)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(todos.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(progress.displayColor)
                    .frame(minWidth: 24, minHeight: 22)
                    .background(progress.displayColor.opacity(0.10), in: Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            LazyVStack(spacing: 4) {
                if todos.isEmpty {
                    Text("暂无事项")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .background(AppTheme.adaptiveWhite(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    ForEach(todos) { todo in
                        TodoBoardCard(
                            todo: todo,
                            onToggle: { onToggle(todo) },
                            onProgressChange: { newProgress in onProgressChange(todo, newProgress) },
                            onUpdate: { draft in onUpdate(todo, draft) },
                            onDelete: { onDelete(todo) },
                            isHighlighted: highlightedTodoID == todo.id
                        )
                        .id(todo.id)
                        .transition(AppMotion.rowTransition)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(progress.displayColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(progress.displayColor.opacity(0.16))
        )
    }
}

struct TodoBoardCard: View {
    let todo: TodoItem
    let onToggle: () -> Void
    let onProgressChange: (TodoProgress) -> Void
    let onUpdate: (TodoDraft) -> Void
    let onDelete: () -> Void
    let isHighlighted: Bool

    @State private var isEditing = false
    @State private var isHovered = false

    var body: some View {
        if isEditing {
            TodoBoardEditCard(
                todo: todo,
                onUpdate: onUpdate,
                onDelete: onDelete,
                onExitEditing: { isEditing = false }
            )
            .transition(AppMotion.inlineTransition)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    TodoIssuePriorityIcon(priority: todo.priority)
                    TodoIssueProgressIcon(progress: todo.progress)
                    if isOverdue {
                        Image(systemName: "clock")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(TodoPriority.high.displayColor)
                            .frame(width: 16, height: 20)
                            .help("逾期")
                    }

                    Spacer(minLength: 6)
                }

                HStack(alignment: .top, spacing: 9) {
                    TodoIssueStatusMarker(todo: todo, isHighlighted: isHovered || isHighlighted)

                    VStack(alignment: .leading, spacing: hasNotes ? 7 : 0) {
                        Text(titleText)
                            .font(.system(size: 14, weight: todo.isDone ? .regular : .semibold))
                            .foregroundStyle(todo.isDone ? AppTheme.mutedInk : AppTheme.ink)
                            .strikethrough(todo.isDone, color: AppTheme.mutedInk)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if hasNotes {
                            Text(todo.trimmedNotes)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(todo.isDone ? AppTheme.mutedInk.opacity(0.82) : AppTheme.mutedInk)
                                .strikethrough(todo.isDone, color: AppTheme.mutedInk)
                                .lineLimit(5)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 1)
                        }
                    }
                    .padding(.top, hasNotes ? 1 : 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 8) {
                    Label(boardFollowUpText, systemImage: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(boardDateColor)
                        .lineLimit(1)
                    if todo.isWeekly {
                        Label("固定", systemImage: "repeat")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 41)
            }
            .padding(.vertical, 9)
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(priorityRailColor)
                    .frame(width: 3)
                    .padding(.vertical, 13)
                    .padding(.leading, 5)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(cardBorderColor, lineWidth: isHovered ? 1.25 : 1)
            )
            .shadow(
                color: isHovered || isHighlighted ? AppTheme.rowShadow.opacity(0.95) : AppTheme.rowShadow.opacity(0.62),
                radius: isHovered || isHighlighted ? 10 : 6,
                x: 0,
                y: isHovered || isHighlighted ? 5 : 3
            )
            .opacity(cardOpacity)
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .contextMenu {
                TodoContextMenuContent(
                    todo: todo,
                    onEdit: startEditing,
                    onToggle: onToggle,
                    onProgressChange: onProgressChange,
                    onUpdate: onUpdate,
                    onDelete: onDelete
                )
            }
            .onHover { hovered in
                withAnimation(AppMotion.hover) {
                    isHovered = hovered
                }
            }
            .animation(AppMotion.status, value: todo.progress)
            .animation(AppMotion.complete, value: todo.isDone)
            .animation(AppMotion.reveal, value: isHighlighted)
            .transition(AppMotion.inlineTransition)
        }
    }

    private var boardFollowUpText: String {
        let calendar = Calendar.current
        let timeText = timeSuffix(for: todo.date, calendar: calendar)
        if calendar.isDateInToday(todo.date) { return "今天\(timeText)" }
        if calendar.isDateInTomorrow(todo.date) { return "明天\(timeText)" }
        if calendar.isDateInYesterday(todo.date) { return "昨天\(timeText)" }
        return formatFullFollowUpDate(todo.date, calendar: calendar)
    }

    private var titleText: String {
        todo.trimmedTitle.isEmpty ? "未命名待办" : todo.trimmedTitle
    }

    private var hasNotes: Bool {
        !todo.trimmedNotes.isEmpty
    }

    private var isOverdue: Bool {
        let calendar = Calendar.current
        return todo.progress != .done
            && todo.progress != .waiting
            && calendar.startOfDay(for: todo.date) < calendar.startOfDay(for: Date())
    }

    private var boardDateColor: Color {
        isOverdue ? TodoPriority.high.displayColor.opacity(AppTheme.isDark ? 0.78 : 0.68) : AppTheme.mutedInk
    }

    private var cardBackgroundColor: Color {
        if isHighlighted {
            return AppTheme.accentSoft.opacity(0.96)
        }
        if isHovered {
            return AppTheme.adaptiveWhite(AppTheme.isDark ? 0.18 : 0.86)
        }
        return AppTheme.adaptiveWhite(AppTheme.isDark ? 0.14 : 0.78)
    }

    private var cardBorderColor: Color {
        if isHighlighted {
            return AppTheme.accent.opacity(0.36)
        }
        return isHovered ? todo.priority.displayColor.opacity(0.36) : AppTheme.border
    }

    private var priorityRailColor: Color {
        if todo.isDone {
            return TodoProgress.done.displayColor.opacity(isHighlighted ? 0.70 : 0.48)
        }
        return todo.priority.displayColor.opacity(isOverdue ? 0.48 : 0.78)
    }

    private var cardOpacity: Double {
        if !todo.isDone {
            return 1
        }
        return isHighlighted ? 0.88 : 0.78
    }

    private func startEditing() {
        withAnimation(AppMotion.quick) {
            isEditing = true
        }
    }
}

enum WorkSectionKind: String, Identifiable, Equatable {
    case overdue
    case today
    case waiting
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overdue: "逾期未完成"
        case .today: "今天要推进"
        case .waiting: "等待反馈"
        case .weekly: "本周固定"
        }
    }

    var subtitle: String {
        switch self {
        case .overdue: "今天之前还没关闭的风险"
        case .today: "今天计划处理或必须推进"
        case .waiting: "需要别人给结果或动作"
        case .weekly: "重复出现的管理动作"
        }
    }

    var icon: String {
        switch self {
        case .overdue: "exclamationmark.triangle"
        case .today: "target"
        case .waiting: "person.2"
        case .weekly: "repeat"
        }
    }

    var color: Color {
        switch self {
        case .overdue: Color(red: 0.93, green: 0.18, blue: 0.24)
        case .today: AppTheme.accent
        case .waiting: Color(red: 0.48, green: 0.44, blue: 0.96)
        case .weekly: Color(red: 0.18, green: 0.70, blue: 0.52)
        }
    }
}
