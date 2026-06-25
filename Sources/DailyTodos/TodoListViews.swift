import SwiftUI

struct ListToolbar: View {
    @Binding var searchText: String
    @Binding var allTodosViewMode: AllTodosViewMode
    let scope: TodoScope

    var body: some View {
        HStack(spacing: 12) {
            SearchField(text: $searchText)
                .frame(maxWidth: .infinity)

            if scope == .all {
                Divider()
                    .frame(height: 24)
                    .overlay(AppTheme.adaptiveBlack(0.10))
                AllTodosViewModePicker(selection: $allTodosViewMode)
            }
        }
        .padding(5)
        .background(AppTheme.adaptiveWhite(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.85))
        )
        .shadow(color: AppTheme.rowShadow.opacity(0.72), radius: 9, x: 0, y: 5)
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
        ScrollViewReader { proxy in
            ScrollView {
                listBody
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
    private var listBody: some View {
        if scope == .dashboard {
            dashboardList
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
            boardList
                .id("all-todos-board")
                .padding(6)
                .transition(AppMotion.viewTransition)
        } else if isMatrixAllTodos {
            matrixList
                .id("all-todos-matrix")
                .padding(6)
                .transition(AppMotion.viewTransition)
        } else {
            groupedList
                .id("todos-grouped")
                .padding(6)
                .transition(AppMotion.viewTransition)
        }
    }

    private var dashboardList: some View {
        LazyVStack(spacing: 6) {
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

            DashboardSummaryStrip(groups: dashboardGroups)

            ForEach(dashboardGroups) { group in
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
                        .id(todo.id)
                    }
                }
            }

            if dashboardGroups.allSatisfy({ $0.todos.isEmpty }) {
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
        LazyVStack(spacing: 7) {
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
                    .id(todo.id)
                    .transition(AppMotion.rowTransition)
                }
            }
        }
    }

    private var groupedList: some View {
        LazyVStack(spacing: 6) {
            if todos.isEmpty {
                EmptyTodoHint(isAllScope: scope == .all)
            } else if scope == .all {
                ForEach(groupedTodos) { group in
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
                    .id(todo.id)
                    .transition(AppMotion.rowTransition)
                }
            }
        }
    }

    private var boardList: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(TodoProgress.allCases) { progress in
                    TodoBoardColumn(
                        progress: progress,
                        todos: todos.filter { $0.progress == progress },
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

    private var matrixList: some View {
        let groups = matrixGroups
        return LazyVGrid(columns: matrixColumns, alignment: .leading, spacing: 12) {
            ForEach(groups) { group in
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

    private var dashboardGroups: [WorkSectionGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let activeTodos = todos.filter { $0.progress != .done }
        let overdue = activeTodos.filter { todo in
            todo.progress != .waiting && calendar.startOfDay(for: todo.date) < today
        }
        let todayItems = activeTodos.filter { todo in
            todo.progress != .waiting && calendar.isDateInToday(todo.date)
        }
        let waiting = activeTodos.filter { $0.progress == .waiting }
        let weekly = activeTodos.filter { todo in
            todo.isWeekly
                && !overdue.contains(where: { $0.id == todo.id })
                && !todayItems.contains(where: { $0.id == todo.id })
                && !waiting.contains(where: { $0.id == todo.id })
        }
        return [
            WorkSectionGroup(kind: .overdue, todos: overdue),
            WorkSectionGroup(kind: .today, todos: todayItems),
            WorkSectionGroup(kind: .waiting, todos: waiting),
            WorkSectionGroup(kind: .weekly, todos: weekly)
        ]
    }

    private var groupedTodos: [TodoDateGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: todos) { calendar.startOfDay(for: $0.date) }
        return groups
            .map { TodoDateGroup(date: $0.key, todos: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private var matrixColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 300), spacing: 12),
            GridItem(.flexible(minimum: 300), spacing: 12)
        ]
    }

    private var matrixGroups: [TodoMatrixGroup] {
        let activeTodos = todos.filter { $0.progress != .done }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func isImportant(_ todo: TodoItem) -> Bool {
            todo.priority == .high
        }

        func isUrgent(_ todo: TodoItem) -> Bool {
            todo.progress != .waiting && calendar.startOfDay(for: todo.date) <= today
        }

        return TodoMatrixKind.allCases.map { kind in
            let filtered = activeTodos.filter { todo in
                switch kind {
                case .urgentImportant:
                    return isUrgent(todo) && isImportant(todo)
                case .importantNotUrgent:
                    return !isUrgent(todo) && isImportant(todo)
                case .urgentNotImportant:
                    return isUrgent(todo) && !isImportant(todo)
                case .notUrgentNotImportant:
                    return !isUrgent(todo) && !isImportant(todo)
                }
            }
            return TodoMatrixGroup(kind: kind, todos: filtered)
        }
    }
}

struct TodoDateGroup: Identifiable {
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

struct TodoMatrixGroup: Identifiable {
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

            LazyVStack(spacing: 6) {
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

            LazyVStack(spacing: 8) {
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
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center, spacing: 8) {
                    PriorityOutlineTag(priority: todo.priority, isCompact: true)
                        .fixedSize()

                    if isOverdue {
                        Text("逾期")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(TodoPriority.high.displayColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(TodoPriority.high.displayColor.opacity(0.10), in: Capsule())
                    }

                    Spacer(minLength: 6)

                    ProgressMenuTag(progress: todo.progress, onSelect: onProgressChange)

                    Button {
                        withAnimation(AppMotion.quick) {
                            isEditing = true
                        }
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .interactionHitArea()
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(AppTheme.mutedInk)
                    .help("编辑")
                }

                HStack(alignment: .top, spacing: 9) {
                    Button(action: onToggle) {
                        ZStack {
                            Circle()
                                .fill(todo.isDone ? TodoProgress.done.displayColor.opacity(0.17) : AppTheme.adaptiveWhite(isHovered || isHighlighted ? 0.94 : 0.72))
                                .overlay(
                                    Circle()
                                        .stroke(todo.isDone ? TodoProgress.done.displayColor.opacity(0.38) : AppTheme.hairline, lineWidth: 1)
                                )
                                .frame(width: 22, height: 22)
                            Image(systemName: todo.isDone ? "checkmark" : "circle")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .interactionHitArea()
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(todo.isDone ? TodoProgress.done.displayColor : AppTheme.mutedInk)
                    .help(todo.isDone ? "标记为待处理" : "标记为完成")

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
            .padding(.vertical, 11)
            .padding(.leading, 13)
            .padding(.trailing, 11)
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
        isOverdue ? TodoPriority.high.displayColor : AppTheme.mutedInk
    }

    private var cardBackgroundColor: Color {
        if isHighlighted {
            return AppTheme.accentSoft.opacity(0.96)
        }
        return AppTheme.rowTint(priority: todo.priority, isOverdue: isOverdue)
    }

    private var cardBorderColor: Color {
        if isHighlighted {
            return AppTheme.accent.opacity(0.36)
        }
        if isOverdue {
            return TodoPriority.high.displayColor.opacity(isHovered ? 0.42 : 0.26)
        }
        return isHovered ? todo.priority.displayColor.opacity(0.36) : AppTheme.border
    }

    private var priorityRailColor: Color {
        if todo.isDone {
            return TodoProgress.done.displayColor.opacity(isHighlighted ? 0.70 : 0.48)
        }
        return isOverdue ? TodoPriority.high.displayColor : todo.priority.displayColor.opacity(0.78)
    }

    private var cardOpacity: Double {
        if !todo.isDone {
            return 1
        }
        return isHighlighted ? 0.88 : 0.78
    }
}

enum WorkSectionKind: String, Identifiable {
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
