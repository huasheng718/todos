import SwiftUI

private let statusColumnWidth: CGFloat = 82
private let progressColumnWidth: CGFloat = 104
private let priorityColumnWidth: CGFloat = 78
private let followUpColumnWidth: CGFloat = 154
private let todoActionColumnWidth: CGFloat = 128
private let compactHitTargetSize: CGFloat = 32

private enum AppMotion {
    static let press = Animation.easeOut(duration: 0.12)
    static let quick = Animation.easeInOut(duration: 0.16)
    static let hover = Animation.easeOut(duration: 0.14)
    static let smooth = Animation.spring(response: 0.30, dampingFraction: 0.86, blendDuration: 0.08)
    static let reveal = Animation.spring(response: 0.26, dampingFraction: 0.84, blendDuration: 0.05)
    static let list = Animation.spring(response: 0.34, dampingFraction: 0.88, blendDuration: 0.08)
    static let capture = Animation.spring(response: 0.24, dampingFraction: 0.80, blendDuration: 0.04)
    static let status = Animation.spring(response: 0.22, dampingFraction: 0.76, blendDuration: 0.04)
    static let complete = Animation.spring(response: 0.20, dampingFraction: 0.68, blendDuration: 0.04)
    static let modeSwitch = Animation.spring(response: 0.38, dampingFraction: 0.88, blendDuration: 0.08)

    static var rowTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .scale(scale: 0.985, anchor: .top)),
            removal: .opacity
                .combined(with: .move(edge: .trailing))
                .combined(with: .scale(scale: 0.985, anchor: .center))
        )
    }

    static var viewTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .leading))
        )
    }
}

private struct TactilePlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.76 : 1)
            .animation(AppMotion.press, value: configuration.isPressed)
    }
}

private extension ButtonStyle where Self == TactilePlainButtonStyle {
    static var tactilePlain: TactilePlainButtonStyle { TactilePlainButtonStyle() }
}

private extension View {
    func interactionHitArea(_ minSize: CGFloat = compactHitTargetSize) -> some View {
        frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }
}

private enum AppSkin: String, CaseIterable, Identifiable {
    case ocean
    case aurora
    case board
    case leafcutter

    static let storageKey = "dailyTodos.selectedSkin"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ocean: "清蓝工作台"
        case .aurora: "柔紫课程"
        case .board: "看板粉彩"
        case .leafcutter: "切叶森工"
        }
    }

    var shortTitle: String {
        switch self {
        case .ocean: "清蓝"
        case .aurora: "柔紫"
        case .board: "粉彩"
        case .leafcutter: "切叶"
        }
    }

    var icon: String {
        switch self {
        case .ocean: "drop.fill"
        case .aurora: "sparkles"
        case .board: "square.grid.2x2.fill"
        case .leafcutter: "leaf.fill"
        }
    }

    static var stored: AppSkin {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey),
              let skin = AppSkin(rawValue: rawValue) else {
            return .ocean
        }
        return skin
    }

    static var current: AppSkin {
        activeAppSkin
    }
}

nonisolated(unsafe) private var activeAppSkin = AppSkin.stored

private enum AppTheme {
    static var canvasGradient: [Color] {
        switch AppSkin.current {
        case .ocean:
            return [
                Color(red: 0.925, green: 0.960, blue: 1.0),
                Color(red: 0.855, green: 0.915, blue: 0.990)
            ]
        case .aurora:
            return [
                Color(red: 0.965, green: 0.915, blue: 1.0),
                Color(red: 0.900, green: 0.980, blue: 0.975)
            ]
        case .board:
            return [
                Color(red: 0.900, green: 0.900, blue: 0.905),
                Color(red: 0.965, green: 0.930, blue: 0.960)
            ]
        case .leafcutter:
            return [
                Color(red: 0.938, green: 0.962, blue: 0.895),
                Color(red: 0.984, green: 0.902, blue: 0.812)
            ]
        }
    }

    static var workSurface: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.965, green: 0.982, blue: 1.0)
        case .aurora: Color(red: 0.985, green: 0.980, blue: 1.0)
        case .board: Color(red: 0.990, green: 0.988, blue: 0.982)
        case .leafcutter: Color(red: 0.985, green: 0.972, blue: 0.930)
        }
    }

    static var sidebar: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.945, green: 0.970, blue: 1.0)
        case .aurora: Color(red: 0.972, green: 0.942, blue: 1.0)
        case .board: Color(red: 0.955, green: 0.948, blue: 0.975)
        case .leafcutter: Color(red: 0.955, green: 0.934, blue: 0.850)
        }
    }

    static var sidebarSelected: Color {
        switch AppSkin.current {
        case .ocean: accent.opacity(0.12)
        case .aurora: accent.opacity(0.14)
        case .board: accent.opacity(0.08)
        case .leafcutter: accent.opacity(0.13)
        }
    }

    static var ink: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.035, green: 0.060, blue: 0.095)
        case .aurora: Color(red: 0.045, green: 0.042, blue: 0.070)
        case .board: Color(red: 0.060, green: 0.058, blue: 0.062)
        case .leafcutter: Color(red: 0.095, green: 0.060, blue: 0.035)
        }
    }

    static var mutedInk: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.335, green: 0.405, blue: 0.500)
        case .aurora: Color(red: 0.420, green: 0.405, blue: 0.500)
        case .board: Color(red: 0.330, green: 0.320, blue: 0.345)
        case .leafcutter: Color(red: 0.405, green: 0.345, blue: 0.260)
        }
    }

    static var panel: Color {
        switch AppSkin.current {
        case .ocean, .aurora: Color.white.opacity(0.98)
        case .board: Color.white.opacity(0.96)
        case .leafcutter: Color(red: 1.0, green: 0.985, blue: 0.948).opacity(0.98)
        }
    }

    static var row: Color {
        switch AppSkin.current {
        case .ocean: Color.white.opacity(0.98)
        case .aurora: Color(red: 0.975, green: 0.960, blue: 1.0)
        case .board: Color(red: 0.955, green: 0.975, blue: 1.0)
        case .leafcutter: Color(red: 1.0, green: 0.978, blue: 0.922)
        }
    }

    static func rowTint(priority: TodoPriority, isOverdue: Bool) -> Color {
        if isOverdue {
            return Color(red: 1.0, green: 0.945, blue: 0.955)
        }

        switch AppSkin.current {
        case .ocean:
            return row
        case .aurora:
            switch priority {
            case .high: return Color(red: 1.0, green: 0.925, blue: 0.965)
            case .medium: return Color(red: 0.940, green: 0.925, blue: 1.0)
            case .low: return Color(red: 0.920, green: 0.980, blue: 0.965)
            }
        case .board:
            switch priority {
            case .high: return Color(red: 1.0, green: 0.910, blue: 0.900)
            case .medium: return Color(red: 0.900, green: 0.940, blue: 1.0)
            case .low: return Color(red: 0.890, green: 0.980, blue: 0.930)
            }
        case .leafcutter:
            switch priority {
            case .high: return Color(red: 1.0, green: 0.930, blue: 0.880)
            case .medium: return Color(red: 0.965, green: 0.952, blue: 0.870)
            case .low: return Color(red: 0.910, green: 0.965, blue: 0.860)
            }
        }
    }

    static var border: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.790, green: 0.850, blue: 0.925)
        case .aurora: Color(red: 0.840, green: 0.790, blue: 0.940)
        case .board: Color(red: 0.830, green: 0.825, blue: 0.830)
        case .leafcutter: Color(red: 0.820, green: 0.748, blue: 0.610)
        }
    }

    static var hairline: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.835, green: 0.885, blue: 0.945)
        case .aurora: Color(red: 0.875, green: 0.830, blue: 0.950)
        case .board: Color(red: 0.850, green: 0.845, blue: 0.850)
        case .leafcutter: Color(red: 0.858, green: 0.790, blue: 0.650)
        }
    }

    static var accent: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.275, green: 0.400, blue: 0.945)
        case .aurora: Color(red: 0.385, green: 0.350, blue: 0.920)
        case .board: Color(red: 0.060, green: 0.058, blue: 0.062)
        case .leafcutter: Color(red: 0.720, green: 0.170, blue: 0.100)
        }
    }

    static var accentCyan: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.245, green: 0.790, blue: 0.925)
        case .aurora: Color(red: 0.975, green: 0.390, blue: 0.740)
        case .board: Color(red: 0.455, green: 0.330, blue: 0.930)
        case .leafcutter: Color(red: 0.410, green: 0.720, blue: 0.230)
        }
    }

    static var accentSoft: Color {
        switch AppSkin.current {
        case .ocean: accent.opacity(0.10)
        case .aurora: accent.opacity(0.12)
        case .board: accent.opacity(0.08)
        case .leafcutter: accent.opacity(0.11)
        }
    }

    static var shellStroke: Color {
        switch AppSkin.current {
        case .ocean, .aurora: Color.white.opacity(0.95)
        case .board: Color.white.opacity(0.82)
        case .leafcutter: Color.white.opacity(0.86)
        }
    }

    static var shadow: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.270, green: 0.430, blue: 0.700).opacity(0.14)
        case .aurora: Color(red: 0.500, green: 0.360, blue: 0.720).opacity(0.14)
        case .board: Color.black.opacity(0.12)
        case .leafcutter: Color(red: 0.360, green: 0.220, blue: 0.110).opacity(0.15)
        }
    }

    static var rowShadow: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.270, green: 0.430, blue: 0.700).opacity(0.08)
        case .aurora: Color(red: 0.500, green: 0.360, blue: 0.720).opacity(0.08)
        case .board: Color.black.opacity(0.06)
        case .leafcutter: Color(red: 0.360, green: 0.220, blue: 0.110).opacity(0.08)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: TodoStore
    @EnvironmentObject private var aiSettings: AISettingsStore
    @AppStorage(AppSkin.storageKey) private var selectedSkinRawValue = AppSkin.ocean.rawValue
    @State private var scope: TodoScope = .all
    @State private var searchText = ""
    @State private var newTitle = ""
    @State private var newPriority: TodoPriority = .medium
    @State private var newProgress: TodoProgress = .pending
    @State private var newDate = Date()
    @State private var newNotes = ""
    @State private var newIsWeekly = false
    @State private var isQuickCaptureExpanded = false
    @State private var isCreatingTodo = false
    @State private var aiStatusMessage: String?
    @State private var isAISettingsPresented = false
    @State private var allTodosViewMode: AllTodosViewMode = .compact
    @FocusState private var focusedField: FocusField?

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            LinearGradient(
                colors: AppTheme.canvasGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                SidebarView(scope: $scope)
                    .frame(width: 236)

                Divider()
                    .overlay(AppTheme.hairline)

                taskColumn
                    .frame(minWidth: 700)
            }
            .background(AppTheme.workSurface, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(AppTheme.shellStroke, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow, radius: 34, x: 0, y: 22)
            .padding(18)
            .id(selectedSkinRawValue)
        }
        .foregroundStyle(AppTheme.ink)
        .onAppear {
            activeAppSkin = AppSkin(rawValue: selectedSkinRawValue) ?? .ocean
        }
        .onChange(of: selectedSkinRawValue) { _, newValue in
            activeAppSkin = AppSkin(rawValue: newValue) ?? .ocean
        }
        .onChange(of: scope) { _, newValue in
            if case .day(let date) = newValue {
                newDate = date
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTodoRequested)) { _ in
            isQuickCaptureExpanded = true
            focusedField = .newTitle
        }
    }

    private var taskColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 28)
                .padding(.top, 34)
                .padding(.bottom, 10)

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
                notes: $newNotes,
                isWeekly: $newIsWeekly,
                isExpanded: $isQuickCaptureExpanded,
                focusedField: $focusedField,
                onCreate: createTodo,
                onClear: cancelCreate,
                isCreating: isCreatingTodo,
                aiStatusMessage: aiStatusMessage,
                isAIEnabled: aiSettings.canUseAI
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
                todos: filteredTodos,
                scope: scope,
                allTodosViewMode: allTodosViewMode,
                onUpdate: updateTodo,
                onProgressChange: updateProgress,
                onToggle: toggleTodo,
                onDelete: deleteTodo
            )
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
            .animation(AppMotion.list, value: filteredTodos)
            .animation(AppMotion.smooth, value: scope)
            .animation(AppMotion.smooth, value: allTodosViewMode)
        }
        .background(AppTheme.workSurface)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(dayTitle)
                    .font(.system(size: 28, weight: .semibold))
                Text(daySubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 8) {
                    AISettingsButton(
                        isEnabled: aiSettings.canUseAI,
                        action: { isAISettingsPresented = true }
                    )

                    SkinPickerButton(selection: $selectedSkinRawValue)

                    Button {
                        withAnimation(AppMotion.smooth) {
                            isQuickCaptureExpanded = true
                        }
                        focusedField = .newTitle
                    } label: {
                        Label("快记", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                            .frame(width: 72, height: 30)
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(.white)
                    .background(AppTheme.accent, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.52))
                    )
                    .shadow(color: AppTheme.accent.opacity(0.24), radius: 12, x: 0, y: 7)
                    .interactionHitArea(34)
                    .help("记录新的待办")
                }

                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .sheet(isPresented: $isAISettingsPresented) {
            AISettingsSheet()
                .environmentObject(aiSettings)
        }
    }

    private var filteredTodos: [TodoItem] {
        switch scope {
        case .dashboard:
            store.todos(matching: searchText)
        case .all:
            store.todos(matching: searchText)
        case .day(let date):
            store.todos(on: date, matching: searchText)
        case .waiting:
            store.todos(matching: searchText).filter { $0.progress == .waiting }
        case .weekly:
            store.todos(matching: searchText).filter(\.isWeekly)
        }
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
            let pending = store.todos.filter { !$0.isDone }.count
            return "\(store.todos.count) 个事项，\(pending) 个未完成"
        case .waiting:
            return "所有需要别人反馈或推进的事项"
        case .weekly:
            return "每周重复出现的管理动作"
        case .day(let selectedDate):
            return selectedDate.formatted(.dateTime.year().month().day().weekday(.wide))
        }
    }

    private var summaryText: String {
        switch scope {
        case .dashboard:
            return "\(overdueTodos.count) 逾期 / \(todayActiveTodos.count) 今日 / \(waitingTodos.count) 等待"
        case .all:
            let completed = store.todos.filter(\.isDone).count
            let pending = store.todos.count - completed
            return "\(pending) 未完成 / \(completed) 已完成"
        case .day(let date):
            return "\(store.pendingCount(on: date)) 未完成 / \(store.completedCount(on: date)) 已完成"
        case .waiting:
            return "\(waitingTodos.count) 等待反馈"
        case .weekly:
            return "\(weeklyTodos.count) 个固定事项"
        }
    }

    private var dashboardSubtitle: String {
        let today = Date().formatted(.dateTime.year().month().day().weekday(.wide))
        return "\(today)，先处理风险，再推进今天"
    }

    private var overdueTodos: [TodoItem] {
        filteredTodos.filter { todo in
            todo.progress != .done
                && todo.progress != .waiting
                && calendar.startOfDay(for: todo.date) < calendar.startOfDay(for: Date())
        }
    }

    private var todayActiveTodos: [TodoItem] {
        filteredTodos.filter { todo in
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
        let parsedInput = TodoQuickInputParser.parse(
            title: newTitle,
            notes: newNotes,
            priority: newPriority,
            date: newDate,
            progress: newProgress,
            isWeekly: newIsWeekly,
            calendar: calendar
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
            Task {
                do {
                    let aiParsedInput = try await AIClient.shared.parseQuickInput(
                        rawTitle: rawTitle,
                        rawNotes: rawNotes,
                        fallback: parsedInput,
                        configuration: aiConfiguration,
                        apiKey: aiAPIKey,
                        calendar: calendar
                    )
                    await MainActor.run {
                        finishCreateTodo(with: aiParsedInput)
                        aiStatusMessage = nil
                        isCreatingTodo = false
                    }
                } catch {
                    await MainActor.run {
                        finishCreateTodo(with: parsedInput)
                        aiStatusMessage = "AI 解析失败，已用本地规则记录"
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

        withAnimation(AppMotion.capture) {
            store.add(
                title: parsedInput.title,
                notes: parsedInput.notes,
                priority: parsedInput.priority,
                date: parsedInput.date,
                progress: parsedInput.progress,
                isWeekly: parsedInput.isWeekly
            )
            if case .day = scope {
                scope = .day(parsedInput.date)
            }
            newTitle = ""
            newPriority = .medium
            newProgress = .pending
            newNotes = ""
            newIsWeekly = false
            isQuickCaptureExpanded = false
        }
        focusedField = .newTitle
    }

    private func updateTodo(_ todo: TodoItem, _ draft: TodoDraft) {
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
        }
    }

    private func updateProgress(_ todo: TodoItem, _ progress: TodoProgress) {
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
        }
    }

    private func toggleTodo(_ todo: TodoItem) {
        withAnimation(AppMotion.complete) {
            store.toggle(todo)
        }
    }

    private func deleteTodo(_ todo: TodoItem) {
        withAnimation(AppMotion.quick) {
            store.delete(todo)
        }
    }

    private func cancelCreate() {
        guard !isCreatingTodo else { return }
        newTitle = ""
        newPriority = .medium
        newProgress = .pending
        newDate = Date()
        newNotes = ""
        newIsWeekly = false
        aiStatusMessage = nil
        withAnimation(AppMotion.smooth) {
            isQuickCaptureExpanded = false
        }
    }
}

enum TodoScope: Equatable {
    case dashboard
    case all
    case waiting
    case weekly
    case day(Date)
}

enum AllTodosViewMode: String, CaseIterable, Identifiable {
    case compact
    case grouped
    case board
    case matrix

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact: "紧凑"
        case .grouped: "分组"
        case .board: "看板"
        case .matrix: "四象限"
        }
    }
}

enum FocusField: Hashable {
    case newTitle
}

struct TodoDraft: Equatable {
    var title: String
    var notes: String
    var priority: TodoPriority
    var progress: TodoProgress
    var date: Date
    var isWeekly: Bool
}

struct SkinPickerButton: View {
    @Binding var selection: String

    private var currentSkin: AppSkin {
        AppSkin(rawValue: selection) ?? .ocean
    }

    var body: some View {
        Menu {
            ForEach(AppSkin.allCases) { skin in
                Button {
                    withAnimation(AppMotion.smooth) {
                        activeAppSkin = skin
                        selection = skin.rawValue
                    }
                } label: {
                    HStack {
                        Label(skin.title, systemImage: skin.icon)
                        if skin == currentSkin {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: currentSkin.icon)
                    .font(.system(size: 11, weight: .bold))
                Text(currentSkin.shortTitle)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(AppTheme.accent)
            .frame(width: 76, height: 30)
            .background(AppTheme.accentSoft, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.accent.opacity(0.22))
            )
            .interactionHitArea(34)
        }
        .menuStyle(.borderlessButton)
        .help("切换皮肤")
    }
}

struct AISettingsButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text("AI")
                    .font(.caption.weight(.semibold))
                Circle()
                    .fill(isEnabled ? Color(red: 0.18, green: 0.70, blue: 0.40) : AppTheme.mutedInk.opacity(0.45))
                    .frame(width: 6, height: 6)
            }
            .foregroundStyle(isEnabled ? AppTheme.accent : AppTheme.mutedInk)
            .frame(width: 64, height: 30)
            .background(isEnabled ? AppTheme.accentSoft : Color.white.opacity(0.58), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isEnabled ? AppTheme.accent.opacity(0.24) : AppTheme.hairline)
            )
            .interactionHitArea(34)
        }
        .buttonStyle(.tactilePlain)
        .help("AI 设置")
    }
}

struct AISettingsSheet: View {
    @EnvironmentObject private var aiSettings: AISettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("AI 设置")
                        .font(.system(size: 22, weight: .semibold))
                    Text("接入 DeepSeek，用于快记解析、每日建议和备注摘要。API Key 只保存在本机钥匙串。")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .interactionHitArea()
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .help("关闭")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    settingsCard
                    usageSection
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.visible)
        }
        .padding(22)
        .frame(width: 660, height: 560)
        .background(AppTheme.workSurface)
        .foregroundStyle(AppTheme.ink)
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Toggle(isOn: $aiSettings.configuration.isEnabled) {
                Label("启用 AI 能力", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
            }
            .toggleStyle(.switch)

            LabeledContent("供应商") {
                Text(aiSettings.configuration.provider.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            LabeledContent("API 地址") {
                TextField("https://api.deepseek.com", text: $aiSettings.configuration.baseURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity)
            }

            LabeledContent("模型") {
                DeepSeekModelPicker(model: $aiSettings.configuration.model)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            LabeledContent("API Key") {
                SecureField("sk-...", text: $aiSettings.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity)
            }

            Label("密钥通过 macOS Keychain 保存，不写入源码、配置文件或 Git 仓库。", systemImage: "lock.shield")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            connectionControls
        }
        .labeledContentStyle(AISettingsLabeledContentStyle())
        .padding(16)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.border)
        )
    }

    private var connectionControls: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                Task {
                    await aiSettings.testConnection()
                }
            } label: {
                Label(aiSettings.isTestingConnection ? "测试中" : "测试连接", systemImage: "network")
                    .font(.caption.weight(.semibold))
                    .frame(width: 96, height: 30)
            }
            .buttonStyle(.tactilePlain)
            .foregroundStyle(.white)
            .background(aiSettings.configuration.hasEndpoint && aiSettings.hasAPIKey ? AppTheme.accent : Color.black.opacity(0.28), in: Capsule())
            .interactionHitArea()
            .disabled(aiSettings.isTestingConnection || !aiSettings.configuration.hasEndpoint || !aiSettings.hasAPIKey)

            if aiSettings.isTestingConnection {
                ProgressView()
                    .controlSize(.small)
            }

            if let message = aiSettings.connectionMessage {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(aiSettings.connectionSucceeded ? Color(red: 0.14, green: 0.58, blue: 0.34) : TodoPriority.high.displayColor)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AIUsageRow(icon: "command", title: "快记解析", detail: "提交时自动拆出时间、优先级、状态、备注和固定周期。")
            AIUsageRow(icon: "sun.max", title: "每日建议", detail: "在今日推进页按当前未完成事项生成 1-3 条推进建议。")
            AIUsageRow(icon: "text.alignleft", title: "备注摘要", detail: "长备注可一键压缩成适合扫读的一句话。")
        }
    }
}

private struct AISettingsLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 14) {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 72, alignment: .leading)
            configuration.content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DeepSeekModelPicker: View {
    @Binding var model: String

    private var currentModel: DeepSeekModel? {
        DeepSeekModel(rawValue: model)
    }

    var body: some View {
        Menu {
            ForEach(DeepSeekModel.allCases) { option in
                Button {
                    model = option.rawValue
                } label: {
                    VStack(alignment: .leading) {
                        Text(option.title)
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentModel?.title ?? "自定义模型")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(model.isEmpty ? AIProvider.deepSeek.defaultModel : model)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(AppTheme.border)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.tactilePlain)
        .menuStyle(.borderlessButton)
        .help(currentModel?.subtitle ?? "当前使用自定义模型名")
    }
}

struct AIUsageRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 22, height: 22)
                .background(AppTheme.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AppLogoImage: View {
    var body: some View {
        Group {
            if let image = Self.logoImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .frame(width: 46, height: 46)
        .shadow(color: Color.black.opacity(0.10), radius: 5, x: 0, y: 3)
        .accessibilityHidden(true)
    }

    private static var logoImage: NSImage? {
        if let url = Bundle.module.url(forResource: "InAppLogo", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        if let url = Bundle.main.url(forResource: "InAppLogo", withExtension: "png") {
            return NSImage(contentsOf: url)
        }

        return nil
    }
}

struct SidebarView: View {
    @EnvironmentObject private var store: TodoStore
    @Binding var scope: TodoScope
    @State private var calendarMonth = Date()

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                AppLogoImage()

                VStack(alignment: .leading, spacing: 2) {
                    Text("蚁序")
                        .font(.system(size: 18, weight: .bold))
                    Text("个人推进秩序")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                DateButton(
                    title: "今日推进",
                    subtitle: "\(dashboardCount) 个需关注",
                    count: overdueCount,
                    isSelected: scope == .dashboard
                ) {
                    scope = .dashboard
                }

                DateButton(
                    title: "等待反馈",
                    subtitle: "需要别人推进",
                    count: waitingCount,
                    isSelected: scope == .waiting
                ) {
                    scope = .waiting
                }

                DateButton(
                    title: "本周固定",
                    subtitle: "重复管理动作",
                    count: weeklyCount,
                    isSelected: scope == .weekly
                ) {
                    scope = .weekly
                }

                DateButton(
                    title: "全部待办",
                    subtitle: "\(store.todos.count) 个事项",
                    count: activeCount,
                    isSelected: scope == .all
                ) {
                    scope = .all
                }

                Text("快速日期")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .padding(.top, 8)

                QuickDateStrip(
                    dates: quickDates,
                    selectedDate: selectedDate,
                    pendingCount: { store.pendingCount(on: $0) },
                    onSelect: { date in
                        calendarMonth = date
                        scope = .day(date)
                    }
                )
            }

            TodoMiniCalendar(
                visibleMonth: $calendarMonth,
                datesWithTodos: store.datesWithTodos(),
                selectedDate: selectedDate,
                todoCount: { store.todos(on: $0).count },
                pendingCount: { store.pendingCount(on: $0) },
                onSelect: { date in
                    calendarMonth = date
                    scope = .day(date)
                }
            )

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 32)
        .padding(.bottom, 20)
        .background(AppTheme.sidebar)
        .foregroundStyle(AppTheme.ink)
        .onAppear {
            if let selectedDate {
                calendarMonth = selectedDate
            }
        }
        .onChange(of: selectedDate) { _, newValue in
            if let newValue {
                calendarMonth = newValue
            }
        }
    }

    private var activeCount: Int {
        store.todos.filter { $0.progress != .done }.count
    }

    private var overdueCount: Int {
        let today = calendar.startOfDay(for: Date())
        return store.todos.filter { todo in
            todo.progress != .done
                && todo.progress != .waiting
                && calendar.startOfDay(for: todo.date) < today
        }.count
    }

    private var waitingCount: Int {
        store.todos.filter { $0.progress == .waiting }.count
    }

    private var weeklyCount: Int {
        store.todos.filter { $0.isWeekly && $0.progress != .done }.count
    }

    private var dashboardCount: Int {
        let today = calendar.startOfDay(for: Date())
        return store.todos.filter { todo in
            todo.progress != .done
                && (calendar.startOfDay(for: todo.date) <= today || todo.progress == .waiting || todo.isWeekly)
        }.count
    }

    private var quickDates: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: Date()) }
    }

    private var selectedDate: Date? {
        guard case .day(let selectedDate) = scope else {
            return nil
        }
        return selectedDate
    }
}

struct DateButton: View {
    let title: String
    let subtitle: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isSelected ? .white : AppTheme.accent)
                    .frame(minWidth: 24, minHeight: 20)
                    .background(isSelected ? AppTheme.accent : AppTheme.accent.opacity(0.10), in: Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.sidebarSelected : Color.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.28) : AppTheme.hairline)
            )
        }
        .buttonStyle(.tactilePlain)
        .animation(AppMotion.smooth, value: isSelected)
    }
}

struct QuickDateStrip: View {
    let dates: [Date]
    let selectedDate: Date?
    let pendingCount: (Date) -> Int
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    private let calendar = Calendar.current

    var body: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(dates, id: \.self) { date in
                QuickDateCell(
                    date: date,
                    count: pendingCount(date),
                    isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                    action: { onSelect(date) }
                )
            }
        }
    }
}

struct QuickDateCell: View {
    let date: Date
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                Circle()
                    .fill(count > 0 ? (isSelected ? Color.white : AppTheme.accent) : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .foregroundStyle(isSelected ? .white : AppTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? AppTheme.accent : Color.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.34) : AppTheme.hairline)
            )
        }
        .buttonStyle(.tactilePlain)
        .help("\(date.formatted(.dateTime.year().month().day()))：\(count) 个未完成")
        .animation(AppMotion.smooth, value: isSelected)
        .animation(AppMotion.smooth, value: count)
    }

    private var label: String {
        if calendar.isDateInToday(date) { return "今" }
        if calendar.isDateInTomorrow(date) { return "明" }
        return date.formatted(.dateTime.weekday(.narrow))
    }
}

struct TodoMiniCalendar: View {
    @Binding var visibleMonth: Date
    let datesWithTodos: [Date]
    let selectedDate: Date?
    let todoCount: (Date) -> Int
    let pendingCount: (Date) -> Int
    let onSelect: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("有记录的日期")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                Spacer()
                Text(monthTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .bold))
                        .interactionHitArea()
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .help("上个月")
                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .interactionHitArea()
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .help("下个月")
            }

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarDays) { day in
                    if let date = day.date {
                        MiniCalendarDayCell(
                            date: date,
                            isInCurrentMonth: day.isInCurrentMonth,
                            isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                            isToday: calendar.isDateInToday(date),
                            totalCount: todoCount(date),
                            pendingCount: pendingCount(date),
                            action: { onSelect(date) }
                        )
                    } else {
                        Color.clear
                            .frame(height: 28)
                    }
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.hairline)
            )
        }
    }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.year().month(.wide))
    }

    private func shiftMonth(_ value: Int) {
        if let nextMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) {
            withAnimation(AppMotion.quick) {
                visibleMonth = nextMonth
            }
        }
    }

    private var calendarDays: [MiniCalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
              let monthRange = calendar.range(of: .day, in: .month, for: visibleMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday + 5) % 7
        var days = Array(repeating: MiniCalendarDay(date: nil, isInCurrentMonth: false), count: leadingBlanks)

        for day in monthRange {
            var components = calendar.dateComponents([.year, .month], from: visibleMonth)
            components.day = day
            days.append(MiniCalendarDay(date: calendar.date(from: components), isInCurrentMonth: true))
        }

        while days.count % 7 != 0 {
            days.append(MiniCalendarDay(date: nil, isInCurrentMonth: false))
        }
        return days
    }
}

struct MiniCalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
    let isInCurrentMonth: Bool
}

struct MiniCalendarDayCell: View {
    let date: Date
    let isInCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let totalCount: Int
    let pendingCount: Int
    let action: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 11, weight: isToday || isSelected ? .bold : .semibold))
                    .monospacedDigit()
                HStack(spacing: 2) {
                    Circle()
                        .fill(totalCount > 0 ? markerColor : Color.clear)
                        .frame(width: 4, height: 4)
                    if pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.system(size: 8, weight: .bold))
                            .monospacedDigit()
                    }
                }
                .frame(height: 8)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(stroke)
            )
            .interactionHitArea()
        }
        .buttonStyle(.tactilePlain)
        .disabled(!isInCurrentMonth)
        .help("\(date.formatted(.dateTime.year().month().day()))：\(totalCount) 项，\(pendingCount) 未完成")
        .animation(AppMotion.smooth, value: isSelected)
        .animation(AppMotion.smooth, value: totalCount)
        .animation(AppMotion.smooth, value: pendingCount)
    }

    private var markerColor: Color {
        pendingCount > 0 ? AppTheme.accent : TodoProgress.done.displayColor
    }

    private var foreground: Color {
        if isSelected { return .white }
        if !isInCurrentMonth { return AppTheme.mutedInk.opacity(0.45) }
        if isToday { return AppTheme.accent }
        return AppTheme.ink
    }

    private var background: Color {
        if isSelected { return AppTheme.accent }
        if isToday { return AppTheme.accentSoft }
        return Color.white.opacity(totalCount > 0 ? 0.70 : 0.0)
    }

    private var stroke: Color {
        if isSelected { return AppTheme.accent.opacity(0.36) }
        if isToday { return AppTheme.accent.opacity(0.22) }
        return totalCount > 0 ? AppTheme.hairline : Color.clear
    }
}

struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.mutedInk)
            TextField("搜索标题或备注", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .interactionHitArea()
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border)
        )
    }
}

struct AllTodosViewModePicker: View {
    @Binding var selection: AllTodosViewMode

    var body: some View {
        Picker("全部待办视图", selection: $selection) {
            ForEach(AllTodosViewMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 304)
    }
}

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
                    .overlay(Color.black.opacity(0.10))
                AllTodosViewModePicker(selection: $allTodosViewMode)
            }
        }
        .padding(6)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border)
        )
        .shadow(color: AppTheme.rowShadow, radius: 12, x: 0, y: 6)
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

    @State private var dailySuggestion: String?
    @State private var dailySuggestionError: String?
    @State private var isGeneratingDailySuggestion = false

    var body: some View {
        ScrollView {
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
        .animation(AppMotion.modeSwitch, value: scope)
        .animation(AppMotion.modeSwitch, value: allTodosViewMode)
        .animation(AppMotion.list, value: todos)
    }

    private var dashboardList: some View {
        LazyVStack(spacing: 6) {
            if aiSettings.canUseAI {
                DailySuggestionCard(
                    suggestion: dailySuggestion,
                    error: dailySuggestionError,
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
                            onDelete: { onDelete(todo) }
                        )
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
        let configuration = aiSettings.configuration
        let apiKey = aiSettings.apiKey
        let sourceTodos = todos
        Task {
            do {
                let suggestion = try await AIClient.shared.dailySuggestion(
                    todos: sourceTodos,
                    configuration: configuration,
                    apiKey: apiKey
                )
                await MainActor.run {
                    withAnimation(AppMotion.reveal) {
                        dailySuggestion = suggestion
                        isGeneratingDailySuggestion = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(AppMotion.reveal) {
                        dailySuggestionError = error.localizedDescription
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
                        onDelete: { onDelete(todo) }
                    )
                    .transition(AppMotion.rowTransition)
                }
            }
        }
        .animation(AppMotion.list, value: todos)
    }

    private var groupedList: some View {
        LazyVStack(spacing: 8) {
            TodoTableHeader()

            if todos.isEmpty {
                EmptyTodoHint(isAllScope: scope == .all)
            } else if scope == .all {
                ForEach(groupedTodos) { group in
                    TodoDateGroupHeader(date: group.date, count: group.todos.count)
                    ForEach(group.todos) { todo in
                        EditableTodoRow(
                            todo: todo,
                            onToggle: { onToggle(todo) },
                            onUpdate: { draft in onUpdate(todo, draft) },
                            onDelete: { onDelete(todo) }
                        )
                        .transition(AppMotion.rowTransition)
                    }
                }
            } else {
                ForEach(todos) { todo in
                    EditableTodoRow(
                        todo: todo,
                        onToggle: { onToggle(todo) },
                        onUpdate: { draft in onUpdate(todo, draft) },
                        onDelete: { onDelete(todo) }
                    )
                    .transition(AppMotion.rowTransition)
                }
            }
        }
        .animation(AppMotion.list, value: todos)
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
                        onDelete: onDelete
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
                    onDelete: onDelete
                )
                .transition(AppMotion.rowTransition)
            }
        }
        .animation(AppMotion.list, value: todos)
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.mutedInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    ForEach(group.todos) { todo in
                        TodoFlowRow(
                            todo: todo,
                            onToggle: { onToggle(todo) },
                            onProgressChange: { progress in onProgressChange(todo, progress) },
                            onUpdate: { draft in onUpdate(todo, draft) },
                            onDelete: { onDelete(todo) },
                            editStyle: .compact
                        )
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
        .animation(AppMotion.list, value: group.todos)
    }
}

struct TodoBoardColumn: View {
    let progress: TodoProgress
    let todos: [TodoItem]
    let onToggle: (TodoItem) -> Void
    let onProgressChange: (TodoItem, TodoProgress) -> Void
    let onUpdate: (TodoItem, TodoDraft) -> Void
    let onDelete: (TodoItem) -> Void

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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.mutedInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .background(Color.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    ForEach(todos) { todo in
                        TodoBoardCard(
                            todo: todo,
                            onToggle: { onToggle(todo) },
                            onProgressChange: { newProgress in onProgressChange(todo, newProgress) },
                            onUpdate: { draft in onUpdate(todo, draft) },
                            onDelete: { onDelete(todo) }
                        )
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
        .animation(AppMotion.list, value: todos)
    }
}

struct TodoBoardCard: View {
    let todo: TodoItem
    let onToggle: () -> Void
    let onProgressChange: (TodoProgress) -> Void
    let onUpdate: (TodoDraft) -> Void
    let onDelete: () -> Void

    @State private var isEditing = false

    var body: some View {
        if isEditing {
            TodoBoardEditCard(
                todo: todo,
                onUpdate: onUpdate,
                onDelete: onDelete,
                onExitEditing: { isEditing = false }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
        } else {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 8) {
                    Button(action: onToggle) {
                        Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14, weight: .semibold))
                            .interactionHitArea()
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(todo.isDone ? TodoProgress.done.displayColor : AppTheme.mutedInk)

                    PriorityOutlineTag(priority: todo.priority)

                    Spacer()

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
                }

                Text(todo.trimmedTitle.isEmpty ? "未命名待办" : todo.trimmedTitle)
                    .font(.system(size: 14, weight: todo.isDone ? .regular : .semibold))
                    .foregroundStyle(todo.isDone ? AppTheme.mutedInk : AppTheme.ink)
                    .strikethrough(todo.isDone, color: AppTheme.mutedInk)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if !todo.trimmedNotes.isEmpty {
                    Text(todo.trimmedNotes)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.mutedInk)
                        .strikethrough(todo.isDone, color: AppTheme.mutedInk)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
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
                    Spacer()
                }
            }
            .padding(12)
            .background(AppTheme.rowTint(priority: todo.priority, isOverdue: isOverdue), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isOverdue ? TodoPriority.high.displayColor.opacity(0.22) : AppTheme.border)
            )
            .shadow(color: AppTheme.rowShadow, radius: 8, x: 0, y: 4)
            .animation(AppMotion.smooth, value: todo)
            .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
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

    private var isOverdue: Bool {
        let calendar = Calendar.current
        return todo.progress != .done
            && todo.progress != .waiting
            && calendar.startOfDay(for: todo.date) < calendar.startOfDay(for: Date())
    }

    private var boardDateColor: Color {
        isOverdue ? TodoPriority.high.displayColor : AppTheme.mutedInk
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

struct WorkSectionGroup: Identifiable {
    let kind: WorkSectionKind
    let todos: [TodoItem]

    var id: WorkSectionKind { kind }
}

struct DashboardSummaryStrip: View {
    let groups: [WorkSectionGroup]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(groups) { group in
                HStack(spacing: 8) {
                    Image(systemName: group.kind.icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(group.kind.title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(group.todos.count)")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(group.kind.color)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(group.kind.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(group.kind.color.opacity(0.24))
                )
            }
        }
    }
}

struct DailySuggestionCard: View {
    let suggestion: String?
    let error: String?
    let isLoading: Bool
    let onGenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.accent)

                Text("AI 每日建议")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                Button(action: onGenerate) {
                    Label(isLoading ? "生成中" : "生成建议", systemImage: "wand.and.stars")
                        .font(.caption.weight(.semibold))
                        .frame(width: 94, height: 28)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.accent)
                .background(AppTheme.accentSoft, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.accent.opacity(0.20))
                )
                .interactionHitArea()
                .disabled(isLoading)
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在读取当前待办并生成推进顺序")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .transition(.opacity)
            } else if let error {
                Text("生成失败：\(error)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TodoPriority.high.displayColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            } else if let suggestion, !suggestion.isEmpty {
                Text(suggestion)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("用当前未完成事项生成今天的推进顺序。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(12)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.18))
        )
        .shadow(color: AppTheme.rowShadow, radius: 8, x: 0, y: 4)
        .animation(AppMotion.reveal, value: suggestion)
        .animation(AppMotion.reveal, value: error)
        .animation(AppMotion.reveal, value: isLoading)
    }
}

struct WorkSection<Content: View>: View {
    let group: WorkSectionGroup
    let row: (TodoItem) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Image(systemName: group.kind.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(group.kind.color)
                Text(group.kind.title)
                    .font(.system(size: 12, weight: .semibold))
                Text(group.kind.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.mutedInk)
                Spacer()
                Text("\(group.todos.count) 项")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 2)

            ForEach(group.todos) { todo in
                row(todo)
            }
        }
    }
}

struct TodoDateGroupHeader: View {
    let date: Date
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Text(date.formatted(.dateTime.year().month().day().weekday(.wide)))
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            Spacer()
            Text("\(count) 项")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInTomorrow(date) { return "明天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.month(.wide).day())
    }
}

struct TodoTableHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            tableHeaderText("状态")
                .frame(width: statusColumnWidth, alignment: .leading)
            tableHeaderText("待办")
                .frame(minWidth: 190, maxWidth: .infinity, alignment: .leading)
            tableHeaderText("进度")
                .frame(width: progressColumnWidth, alignment: .leading)
            tableHeaderText("优先级")
                .frame(width: priorityColumnWidth, alignment: .leading)
            tableHeaderText("跟进日")
                .frame(width: followUpColumnWidth, alignment: .leading)
            Color.clear
                .frame(width: todoActionColumnWidth)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func tableHeaderText(_ value: String) -> some View {
        Text(value)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.mutedInk)
    }
}

struct QuickCaptureBar: View {
    @Binding var title: String
    @Binding var priority: TodoPriority
    @Binding var progress: TodoProgress
    @Binding var date: Date
    @Binding var notes: String
    @Binding var isWeekly: Bool
    @Binding var isExpanded: Bool
    var focusedField: FocusState<FocusField?>.Binding
    let onCreate: () -> Void
    let onClear: () -> Void
    let isCreating: Bool
    let aiStatusMessage: String?
    let isAIEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 9 : 5) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentSoft)
                    Image(systemName: "command")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(width: 24, height: 24)

                TextField("快速记录：要推进什么？", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .focused(focusedField, equals: .newTitle)
                    .submitLabel(.done)
                    .onSubmit(submitQuickRecord)
                    .onTapGesture {
                        withAnimation(AppMotion.reveal) {
                            isExpanded = true
                        }
                    }
                    .frame(minWidth: 190, maxWidth: .infinity, alignment: .leading)

                Button {
                    withAnimation(AppMotion.reveal) {
                        isExpanded.toggle()
                    }
                    if isExpanded {
                        focusedField.wrappedValue = .newTitle
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .interactionHitArea()
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .help(isExpanded ? "收起记录字段" : "展开记录字段")

                Button(action: onCreate) {
                    Label(isCreating ? "解析" : "记录", systemImage: isCreating ? "sparkles" : "arrow.down.to.line.compact")
                        .font(.caption.weight(.semibold))
                        .frame(width: 68, height: 28)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(.white)
                .background(canCreate && !isCreating ? AppTheme.accent : Color.black.opacity(0.28), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(canCreate && !isCreating ? Color.white.opacity(0.52) : Color.black.opacity(0.05))
                )
                .shadow(color: canCreate && !isCreating ? AppTheme.accent.opacity(0.20) : .clear, radius: 10, x: 0, y: 6)
                .interactionHitArea()
                .disabled(!canCreate || isCreating)
                .help("记录新的待办")

                if isExpanded || hasDraft {
                    Button(action: onClear) {
                        Image(systemName: "xmark")
                            .interactionHitArea()
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(AppTheme.mutedInk)
                    .help("清空记录")
                    .disabled(isCreating)
                }
            }

            if hasDraft {
                QuickCapturePreview(
                    title: parsedPreview.title,
                    notes: parsedPreview.notes,
                    priority: parsedPreview.priority,
                    progress: parsedPreview.progress,
                    date: parsedPreview.date,
                    isWeekly: parsedPreview.isWeekly
                )
                .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.985, anchor: .top)))
            }

            if let aiStatusMessage {
                HStack(spacing: 6) {
                    Image(systemName: aiStatusMessage.contains("失败") ? "exclamationmark.triangle" : "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text(aiStatusMessage)
                        .font(.system(size: 11, weight: .semibold))
                    if isCreating {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .foregroundStyle(aiStatusMessage.contains("失败") ? TodoPriority.high.displayColor : AppTheme.accent)
                .padding(.leading, 32)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if isAIEnabled && hasDraft {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("提交时使用 AI 解析")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.leading, 32)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if isExpanded {
                HStack(alignment: .center, spacing: 8) {
                    PriorityPicker(priority: $priority)
                        .frame(width: 78, alignment: .leading)

                    ProgressPicker(progress: $progress)
                        .frame(width: 104, alignment: .leading)

                    DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(width: 150, alignment: .leading)

                    Toggle(isOn: $isWeekly) {
                        Label("每周固定", systemImage: "repeat")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                    .toggleStyle(.checkbox)
                    .help("完成后自动生成下周同一天")

                    CompactNotesField(text: $notes, onSubmit: submitQuickRecord)
                        .frame(maxWidth: .infinity)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isExpanded ? AppTheme.accent.opacity(0.22) : AppTheme.border)
        )
        .shadow(color: AppTheme.rowShadow, radius: hasDraft ? 14 : 8, x: 0, y: hasDraft ? 7 : 4)
        .animation(AppMotion.reveal, value: isExpanded)
        .animation(AppMotion.capture, value: hasDraft)
        .animation(AppMotion.capture, value: isCreating)
        .animation(AppMotion.capture, value: aiStatusMessage)
    }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasDraft: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || priority != .medium
            || progress != .pending
            || isWeekly
    }

    private var parsedPreview: ParsedTodoInput {
        TodoQuickInputParser.parse(
            title: title,
            notes: notes,
            priority: priority,
            date: date,
            progress: progress,
            isWeekly: isWeekly
        )
    }

    private func submitQuickRecord() {
        guard canCreate else { return }
        onCreate()
    }
}

struct QuickCapturePreview: View {
    let title: String
    let notes: String
    let priority: TodoPriority
    let progress: TodoProgress
    let date: Date
    let isWeekly: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title.isEmpty ? "待识别事项" : title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                PreviewChip(text: priority.label, color: priority.displayColor, systemImage: "flag.fill")
                PreviewChip(text: progress.shortLabel, color: progress.displayColor, systemImage: progress.previewIcon)
                PreviewChip(text: previewDateText, color: dateColor, systemImage: "calendar")
                if isWeekly {
                    PreviewChip(text: "固定", color: AppTheme.mutedInk, systemImage: "repeat")
                }
                if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    PreviewChip(text: notes.trimmingCharacters(in: .whitespacesAndNewlines), color: AppTheme.mutedInk, systemImage: "text.alignleft")
                        .frame(maxWidth: 190)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 32)
        .padding(.trailing, 4)
    }

    private var previewDateText: String {
        let calendar = Calendar.current
        let timeText = timeSuffix(for: date, calendar: calendar)
        if calendar.isDateInToday(date) { return "今天\(timeText)" }
        if calendar.isDateInTomorrow(date) { return "明天\(timeText)" }
        if calendar.isDateInYesterday(date) { return "昨天\(timeText)" }
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)/\(day)\(timeText)"
    }

    private var dateColor: Color {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
            ? TodoPriority.high.displayColor
            : AppTheme.mutedInk
    }
}

struct PreviewChip: View {
    let text: String
    let color: Color
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.08), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.18), lineWidth: 1)
            )
    }
}

struct EditableTodoRow: View {
    let todo: TodoItem
    let onToggle: () -> Void
    let onUpdate: (TodoDraft) -> Void
    let onDelete: () -> Void
    let startsEditing: Bool
    let onExitEditing: (() -> Void)?

    @State private var title: String
    @State private var notes: String
    @State private var priority: TodoPriority
    @State private var progress: TodoProgress
    @State private var date: Date
    @State private var isWeekly: Bool
    @State private var isEditing = false

    init(
        todo: TodoItem,
        onToggle: @escaping () -> Void,
        onUpdate: @escaping (TodoDraft) -> Void,
        onDelete: @escaping () -> Void,
        startsEditing: Bool = false,
        onExitEditing: (() -> Void)? = nil
    ) {
        self.todo = todo
        self.onToggle = onToggle
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.startsEditing = startsEditing
        self.onExitEditing = onExitEditing
        _title = State(initialValue: todo.title)
        _notes = State(initialValue: todo.notes)
        _priority = State(initialValue: todo.priority)
        _progress = State(initialValue: todo.progress)
        _date = State(initialValue: todo.date)
        _isWeekly = State(initialValue: todo.isWeekly)
        _isEditing = State(initialValue: startsEditing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggle) {
                    HStack(spacing: 6) {
                        Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17))
                        Text(todo.isDone ? "完成" : "待办")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(todo.isDone ? TodoProgress.done.displayColor : AppTheme.mutedInk)
                    .padding(.top, 7)
                    .frame(width: statusColumnWidth, alignment: .leading)
                }
                .buttonStyle(.tactilePlain)
                .interactionHitArea()

                if isEditing {
                    InlineTextField("待办", text: $title, isEmphasized: true)
                        .strikethrough(todo.isDone, color: AppTheme.mutedInk)
                        .frame(minWidth: 190, maxWidth: .infinity, alignment: .leading)

                    ProgressPicker(progress: $progress)
                        .frame(width: progressColumnWidth, alignment: .leading)

                    PriorityPicker(priority: $priority)
                        .frame(width: priorityColumnWidth, alignment: .leading)

                    DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(width: followUpColumnWidth, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title.isEmpty ? "未命名待办" : title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(todo.isDone ? AppTheme.mutedInk : AppTheme.ink)
                            .strikethrough(todo.isDone, color: AppTheme.mutedInk)
                            .lineLimit(3)

                        if todo.isWeekly {
                            Label("每周固定", systemImage: "repeat")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.mutedInk)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .frame(minWidth: 190, maxWidth: .infinity, alignment: .leading)

                    ProgressBadge(progress: progress)
                        .frame(width: progressColumnWidth, alignment: .leading)

                    PriorityBadge(priority: priority)
                        .frame(width: priorityColumnWidth, alignment: .leading)

                    Text(formatFullFollowUpDate(date))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.mutedInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .frame(width: followUpColumnWidth, alignment: .leading)
                }

                HStack(spacing: 8) {
                    if isEditing {
                        Button(action: submitEdit) {
                            Label("提交", systemImage: "checkmark")
                                .font(.caption.weight(.semibold))
                                .frame(width: 64, height: 30)
                        }
                        .buttonStyle(.tactilePlain)
                        .foregroundStyle(.white)
                        .background(canSubmit ? Color(red: 0.16, green: 0.50, blue: 0.34) : Color.black.opacity(0.28), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(canSubmit ? Color.white.opacity(0.22) : Color.black.opacity(0.05))
                        )
                        .interactionHitArea()
                        .disabled(!canSubmit)
                        .help("提交修改")

                        Button(action: cancelEdit) {
                            Image(systemName: "xmark")
                                .interactionHitArea()
                        }
                        .help("取消编辑")
                        .buttonStyle(.tactilePlain)
                        .foregroundStyle(AppTheme.mutedInk)
                    } else {
                        Button {
                            withAnimation(AppMotion.quick) {
                                isEditing = true
                            }
                        } label: {
                            Image(systemName: "pencil")
                                .interactionHitArea()
                        }
                        .help("编辑")
                        .buttonStyle(.tactilePlain)
                        .foregroundStyle(AppTheme.mutedInk)
                    }
                }
                .frame(width: todoActionColumnWidth, alignment: .trailing)
            }

            if isEditing {
                Toggle(isOn: $isWeekly) {
                    Label("每周固定，完成后自动生成下周同一天", systemImage: "repeat")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .toggleStyle(.checkbox)
                .padding(.leading, statusColumnWidth + 12)

                NotesRowLabelEditor("备注", placeholder: "添加备注", text: $notes, reservesActionColumn: true)

                HStack {
                    Spacer()

                    Button(role: .destructive, action: onDelete) {
                        Label("删除待办", systemImage: "trash")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(AppTheme.mutedInk)
                    .interactionHitArea()
                }
                .padding(.trailing, 2)
            } else if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                NotesReadOnlyRow(title: title, notes: notes, isDone: todo.isDone)
            }
        }
        .padding(14)
        .background(AppTheme.rowTint(priority: priority, isOverdue: false), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border)
        )
        .shadow(color: AppTheme.rowShadow, radius: 9, x: 0, y: 5)
        .onChange(of: todo) { _, newTodo in
            if !isEditing {
                withAnimation(AppMotion.smooth) {
                    syncFromTodo(newTodo)
                }
            }
        }
        .onAppear {
            if startsEditing {
                isEditing = true
            }
        }
        .animation(AppMotion.smooth, value: todo)
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitEdit() {
        let draft = TodoDraft(
            title: title,
            notes: notes,
            priority: priority,
            progress: progress,
            date: date,
            isWeekly: isWeekly
        )
        guard draft != TodoDraft(
            title: todo.title,
            notes: todo.notes,
            priority: todo.priority,
            progress: todo.progress,
            date: todo.date,
            isWeekly: todo.isWeekly
        ) else {
            withAnimation(AppMotion.quick) {
                isEditing = false
            }
            onExitEditing?()
            return
        }
        guard canSubmit else { return }
        onUpdate(draft)
        withAnimation(AppMotion.quick) {
            isEditing = false
        }
        onExitEditing?()
    }

    private func cancelEdit() {
        syncFromTodo(todo)
        withAnimation(AppMotion.quick) {
            isEditing = false
        }
        onExitEditing?()
    }

    private func syncFromTodo(_ todo: TodoItem) {
        title = todo.title
        notes = todo.notes
        priority = todo.priority
        progress = todo.progress
        date = todo.date
        isWeekly = todo.isWeekly
    }
}

enum TodoFlowRowEditStyle {
    case full
    case compact
}

struct TodoFlowRow: View {
    let todo: TodoItem
    let onToggle: () -> Void
    let onProgressChange: (TodoProgress) -> Void
    let onUpdate: (TodoDraft) -> Void
    let onDelete: () -> Void
    var editStyle: TodoFlowRowEditStyle = .full

    @State private var isEditing = false

    var body: some View {
        if isEditing {
            switch editStyle {
            case .full:
                EditableTodoRow(
                    todo: todo,
                    onToggle: onToggle,
                    onUpdate: onUpdate,
                    onDelete: onDelete,
                    startsEditing: true,
                    onExitEditing: {
                        isEditing = false
                    }
                )
                .id("\(todo.id)-editing")
                .transition(.opacity.combined(with: .scale(scale: 0.988, anchor: .top)))

            case .compact:
                TodoBoardEditCard(
                    todo: todo,
                    onUpdate: onUpdate,
                    onDelete: onDelete,
                    onExitEditing: {
                        isEditing = false
                    }
                )
                .id("\(todo.id)-compact-editing")
                .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
            }
        } else {
            HStack(alignment: hasNotes ? .top : .center, spacing: 8) {
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .fill(todo.isDone ? TodoProgress.done.displayColor.opacity(0.14) : Color.white.opacity(0.70))
                            .frame(width: 24, height: 24)
                        Image(systemName: todo.isDone ? "checkmark" : "circle")
                            .font(.system(size: todo.isDone ? 11 : 12, weight: .bold))
                    }
                    .interactionHitArea()
                }
                .help(todo.isDone ? "标记为待处理" : "标记为完成")
                .buttonStyle(.tactilePlain)
                .foregroundStyle(todo.isDone ? TodoProgress.done.displayColor : AppTheme.mutedInk)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        PriorityOutlineTag(priority: todo.priority)
                            .fixedSize()

                        Text(titleText)
                            .font(.system(size: 13, weight: todo.isDone ? .regular : .semibold))
                            .foregroundStyle(todo.isDone ? AppTheme.mutedInk : AppTheme.ink)
                            .strikethrough(todo.isDone, color: AppTheme.mutedInk)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if todo.isWeekly {
                            Image(systemName: "repeat")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.mutedInk)
                                .help("每周固定")
                        }
                    }

                    if hasNotes {
                        Text(todo.trimmedNotes)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.mutedInk)
                            .strikethrough(todo.isDone, color: AppTheme.mutedInk)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, hasNotes ? 2 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 7) {
                    ProgressMenuTag(progress: todo.progress, onSelect: onProgressChange)
                        .frame(width: 52, alignment: .leading)

                    Text(followUpText)
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(dateColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .frame(width: 72, alignment: .leading)

                    Button {
                        withAnimation(AppMotion.reveal) {
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
                .padding(.top, hasNotes ? -3 : 0)
                .fixedSize()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(rowStroke)
            )
            .shadow(color: AppTheme.rowShadow, radius: isOverdue ? 7 : 3, x: 0, y: isOverdue ? 4 : 2)
            .opacity(todo.isDone ? 0.72 : 1)
            .animation(AppMotion.status, value: todo.progress)
            .animation(AppMotion.complete, value: todo.isDone)
            .animation(AppMotion.smooth, value: todo)
            .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.992, anchor: .top)))
        }
    }

    private var titleText: String {
        todo.trimmedTitle.isEmpty ? "未命名待办" : todo.trimmedTitle
    }

    private var hasNotes: Bool {
        !todo.trimmedNotes.isEmpty
    }

    private var followUpText: String {
        let calendar = Calendar.current
        let timeText = timeSuffix(for: todo.date, calendar: calendar)
        if calendar.isDateInToday(todo.date) { return "今天\(timeText)" }
        if calendar.isDateInTomorrow(todo.date) { return "明天\(timeText)" }
        if calendar.isDateInYesterday(todo.date) { return "昨天\(timeText)" }
        let month = calendar.component(.month, from: todo.date)
        let day = calendar.component(.day, from: todo.date)
        let year = calendar.component(.year, from: todo.date)
        let currentYear = calendar.component(.year, from: Date())
        if year == currentYear {
            return "\(month)/\(day)\(timeText)"
        }
        return "\(year % 100)/\(month)/\(day)\(timeText)"
    }

    private var isOverdue: Bool {
        let calendar = Calendar.current
        return todo.progress != .done
            && todo.progress != .waiting
            && calendar.startOfDay(for: todo.date) < calendar.startOfDay(for: Date())
    }

    private var dateColor: Color {
        isOverdue ? TodoPriority.high.displayColor : AppTheme.mutedInk
    }

    private var rowBackground: Color {
        AppTheme.rowTint(priority: todo.priority, isOverdue: isOverdue)
    }

    private var rowStroke: Color {
        if isOverdue {
            return TodoPriority.high.displayColor.opacity(0.22)
        }
        return AppTheme.border
    }
}

struct TodoBoardEditCard: View {
    let todo: TodoItem
    let onUpdate: (TodoDraft) -> Void
    let onDelete: () -> Void
    let onExitEditing: () -> Void

    @State private var title: String
    @State private var notes: String
    @State private var priority: TodoPriority
    @State private var progress: TodoProgress
    @State private var date: Date
    @State private var isWeekly: Bool

    init(
        todo: TodoItem,
        onUpdate: @escaping (TodoDraft) -> Void,
        onDelete: @escaping () -> Void,
        onExitEditing: @escaping () -> Void
    ) {
        self.todo = todo
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onExitEditing = onExitEditing
        _title = State(initialValue: todo.title)
        _notes = State(initialValue: todo.notes)
        _priority = State(initialValue: todo.priority)
        _progress = State(initialValue: todo.progress)
        _date = State(initialValue: todo.date)
        _isWeekly = State(initialValue: todo.isWeekly)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("编辑事项")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)

                Spacer()

                Button(action: cancelEdit) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .interactionHitArea()
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .help("取消编辑")
            }

            InlineTextField("待办", text: $title, isEmphasized: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ProgressPicker(progress: $progress)
                    .frame(maxWidth: .infinity, alignment: .leading)

                PriorityPicker(priority: $priority)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(isOn: $isWeekly) {
                Label("每周固定", systemImage: "repeat")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .toggleStyle(.checkbox)
            .help("完成后自动生成下周同一天")

            NotesRowLabelEditor(
                "备注",
                placeholder: "添加备注",
                text: $notes,
                labelWidth: 44,
                reservesActionColumn: false
            )

            HStack(spacing: 8) {
                Button(role: .destructive, action: deleteAndExit) {
                    Label("删除", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                        .frame(height: 30)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .interactionHitArea()

                Spacer()

                Button(action: submitEdit) {
                    Label("提交", systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .frame(width: 72, height: 30)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(.white)
                .background(canSubmit ? Color(red: 0.16, green: 0.50, blue: 0.34) : Color.black.opacity(0.28), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(canSubmit ? Color.white.opacity(0.22) : Color.black.opacity(0.05))
                )
                .interactionHitArea()
                .disabled(!canSubmit)
                .help("提交修改")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.rowTint(priority: priority, isOverdue: isOverdue), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.24))
        )
        .shadow(color: AppTheme.rowShadow, radius: 8, x: 0, y: 4)
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isOverdue: Bool {
        let calendar = Calendar.current
        return progress != .done
            && progress != .waiting
            && calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
    }

    private func submitEdit() {
        guard canSubmit else { return }
        let draft = TodoDraft(
            title: title,
            notes: notes,
            priority: priority,
            progress: progress,
            date: date,
            isWeekly: isWeekly
        )
        if draft != TodoDraft(
            title: todo.title,
            notes: todo.notes,
            priority: todo.priority,
            progress: todo.progress,
            date: todo.date,
            isWeekly: todo.isWeekly
        ) {
            onUpdate(draft)
        }
        withAnimation(AppMotion.quick) {
            onExitEditing()
        }
    }

    private func cancelEdit() {
        withAnimation(AppMotion.quick) {
            onExitEditing()
        }
    }

    private func deleteAndExit() {
        onDelete()
        withAnimation(AppMotion.quick) {
            onExitEditing()
        }
    }
}

struct EmptyTodoHint: View {
    let isAllScope: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 34))
                .foregroundStyle(AppTheme.mutedInk)
            Text(isAllScope ? "还没有任何待办" : "这一天还没有待办")
                .font(.headline)
            Text("在上方快速记录一条事项，然后点击记录。")
                .font(.callout)
                .foregroundStyle(AppTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private func formatFullFollowUpDate(_ date: Date, calendar: Calendar = .current) -> String {
    let dateText = date.formatted(.dateTime.year().month().day())
    let suffix = timeSuffix(for: date, calendar: calendar)
    return suffix.isEmpty ? dateText : "\(dateText) \(suffix)"
}

private func timeSuffix(for date: Date, calendar: Calendar = .current) -> String {
    guard !calendar.isDate(date, equalTo: calendar.startOfDay(for: date), toGranularity: .minute) else {
        return ""
    }
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    return String(format: " %02d:%02d", hour, minute)
}

struct InlineTextField: View {
    let placeholder: String
    @Binding var text: String
    var isEmphasized = false

    init(_ placeholder: String, text: Binding<String>, isEmphasized: Bool = false) {
        self.placeholder = placeholder
        _text = text
        self.isEmphasized = isEmphasized
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: isEmphasized ? .semibold : .regular))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.border)
            )
    }
}

struct CompactNotesField: View {
    @Binding var text: String
    var onSubmit: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 16)

            TextField("备注（可选，添加背景、链接、判断依据）", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .submitLabel(.done)
                .onSubmit {
                    onSubmit?()
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: 30)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border)
        )
    }
}

struct PriorityBadge: View {
    let priority: TodoPriority

    var body: some View {
        Text(priority.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(priorityColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(priorityColor.opacity(0.10), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(priorityColor.opacity(0.58), lineWidth: 1)
            )
    }

    private var priorityColor: Color {
        priority.displayColor
    }
}

struct ProgressBadge: View {
    let progress: TodoProgress

    var body: some View {
        Text(progress.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(progress.displayColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(progress.displayColor.opacity(0.10), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(progress.displayColor.opacity(0.50), lineWidth: 1)
            )
    }
}

struct PriorityOutlineTag: View {
    let priority: TodoPriority

    var body: some View {
        Text(priority.label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(priorityColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor.opacity(0.12), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(priorityColor.opacity(0.62), lineWidth: 1)
            )
    }

    private var priorityColor: Color {
        priority.displayColor
    }
}

struct ProgressMenuTag: View {
    let progress: TodoProgress
    let onSelect: (TodoProgress) -> Void

    var body: some View {
        Menu {
            ForEach(TodoProgress.allCases) { option in
                Button(option.label) {
                    onSelect(option)
                }
            }
        } label: {
            Text(progress.shortLabel)
                .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(progress.displayColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .background(progress.displayColor.opacity(0.08), in: Capsule())
            .interactionHitArea()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("切换推进状态")
    }
}

private extension TodoProgress {
    var previewIcon: String {
        switch self {
        case .pending: "circle"
        case .inProgress: "bolt.fill"
        case .waiting: "person.2.fill"
        case .done: "checkmark.circle.fill"
        }
    }

    var boardTitle: String {
        switch self {
        case .pending: "待处理"
        case .inProgress: "推进中"
        case .waiting: "等待反馈"
        case .done: "已完成"
        }
    }

    var boardIcon: String {
        switch self {
        case .pending: "circle"
        case .inProgress: "bolt.fill"
        case .waiting: "person.2.fill"
        case .done: "checkmark.circle.fill"
        }
    }

    var displayColor: Color {
        switch AppSkin.current {
        case .ocean:
            switch self {
            case .pending: return Color(red: 0.38, green: 0.45, blue: 0.56)
            case .inProgress: return AppTheme.accent
            case .waiting: return Color(red: 0.48, green: 0.44, blue: 0.96)
            case .done: return Color(red: 0.12, green: 0.62, blue: 0.42)
            }
        case .aurora:
            switch self {
            case .pending: return Color(red: 0.47, green: 0.43, blue: 0.56)
            case .inProgress: return Color(red: 0.35, green: 0.34, blue: 0.92)
            case .waiting: return Color(red: 0.93, green: 0.36, blue: 0.73)
            case .done: return Color(red: 0.18, green: 0.64, blue: 0.52)
            }
        case .board:
            switch self {
            case .pending: return Color(red: 0.25, green: 0.25, blue: 0.28)
            case .inProgress: return Color(red: 0.24, green: 0.42, blue: 0.78)
            case .waiting: return Color(red: 0.82, green: 0.34, blue: 0.72)
            case .done: return Color(red: 0.14, green: 0.58, blue: 0.34)
            }
        case .leafcutter:
            switch self {
            case .pending: return Color(red: 0.48, green: 0.36, blue: 0.24)
            case .inProgress: return AppTheme.accent
            case .waiting: return Color(red: 0.86, green: 0.44, blue: 0.16)
            case .done: return Color(red: 0.28, green: 0.62, blue: 0.24)
            }
        }
    }
}

private extension TodoPriority {
    var displayColor: Color {
        switch AppSkin.current {
        case .ocean:
            switch self {
            case .low: return Color(red: 0.13, green: 0.67, blue: 0.52)
            case .medium: return AppTheme.accent
            case .high: return Color(red: 0.93, green: 0.18, blue: 0.24)
            }
        case .aurora:
            switch self {
            case .low: return Color(red: 0.16, green: 0.68, blue: 0.55)
            case .medium: return Color(red: 0.37, green: 0.34, blue: 0.92)
            case .high: return Color(red: 0.95, green: 0.30, blue: 0.55)
            }
        case .board:
            switch self {
            case .low: return Color(red: 0.15, green: 0.60, blue: 0.34)
            case .medium: return Color(red: 0.24, green: 0.42, blue: 0.78)
            case .high: return Color(red: 0.88, green: 0.28, blue: 0.30)
            }
        case .leafcutter:
            switch self {
            case .low: return Color(red: 0.32, green: 0.64, blue: 0.22)
            case .medium: return Color(red: 0.78, green: 0.42, blue: 0.16)
            case .high: return Color(red: 0.86, green: 0.16, blue: 0.10)
            }
        }
    }
}

struct NotesReadOnlyRow: View {
    @EnvironmentObject private var aiSettings: AISettingsStore

    let title: String
    let notes: String
    let isDone: Bool

    @State private var summary: String?
    @State private var summaryError: String?
    @State private var isSummarizing = false

    init(title: String = "", notes: String, isDone: Bool = false) {
        self.title = title
        self.notes = notes
        self.isDone = isDone
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Label("备注", systemImage: "text.alignleft")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .labelStyle(.titleAndIcon)
                .padding(.top, 8)
                .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                Text(displayText)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.mutedInk)
                    .strikethrough(isDone, color: AppTheme.mutedInk)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let summary, !summary.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.top, 2)
                        Text(summary)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let summaryError {
                    Text("摘要失败：\(summaryError)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TodoPriority.high.displayColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.border)
            )

            VStack(spacing: 6) {
                if aiSettings.canUseAI {
                    Button(action: summarizeNotes) {
                        Label(isSummarizing ? "摘要中" : "摘要", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .frame(width: 74, height: 28)
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(AppTheme.accent)
                    .background(AppTheme.accentSoft, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.accent.opacity(0.18))
                    )
                    .interactionHitArea()
                    .disabled(isSummarizing)

                    if isSummarizing {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
            }
            .frame(width: todoActionColumnWidth, alignment: .topTrailing)
        }
        .animation(AppMotion.reveal, value: summary)
        .animation(AppMotion.reveal, value: summaryError)
        .animation(AppMotion.reveal, value: isSummarizing)
    }

    private var displayText: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func summarizeNotes() {
        guard aiSettings.canUseAI, !isSummarizing else { return }
        isSummarizing = true
        summaryError = nil
        let configuration = aiSettings.configuration
        let apiKey = aiSettings.apiKey
        let sourceTitle = title
        let sourceNotes = displayText
        Task {
            do {
                let value = try await AIClient.shared.summarizeNotes(
                    title: sourceTitle,
                    notes: sourceNotes,
                    configuration: configuration,
                    apiKey: apiKey
                )
                await MainActor.run {
                    summary = value
                    isSummarizing = false
                }
            } catch {
                await MainActor.run {
                    summaryError = error.localizedDescription
                    isSummarizing = false
                }
            }
        }
    }
}

struct NotesRowLabelEditor: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let labelWidth: CGFloat
    let reservesActionColumn: Bool

    init(
        _ label: String,
        placeholder: String,
        text: Binding<String>,
        labelWidth: CGFloat = 58,
        reservesActionColumn: Bool = false
    ) {
        self.label = label
        self.placeholder = placeholder
        _text = text
        self.labelWidth = labelWidth
        self.reservesActionColumn = reservesActionColumn
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if labelWidth > 0 {
                Label(label, systemImage: "text.alignleft")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .labelStyle(.titleAndIcon)
                    .padding(.top, 8)
                    .frame(width: labelWidth, alignment: .leading)
            }

            InlineNotesEditor(placeholder, text: $text)
                .frame(maxWidth: .infinity, alignment: .leading)

            if reservesActionColumn {
                Color.clear
                    .frame(width: todoActionColumnWidth)
            }
        }
    }
}

struct InlineNotesEditor: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(minHeight: editorHeight, maxHeight: editorHeight)

            if text.isEmpty {
                Text(placeholder)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.mutedInk.opacity(0.82))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
        }
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border)
        )
    }

    private var editorHeight: CGFloat {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return 46
        }

        let estimatedLines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { partialResult, line in
                partialResult + max(1, (line.count + 53) / 54)
            }
        return min(220, max(74, CGFloat(estimatedLines) * 20 + 26))
    }
}

struct PriorityPicker: View {
    @Binding var priority: TodoPriority

    var body: some View {
        Picker("优先级", selection: $priority) {
            ForEach(TodoPriority.allCases) { priority in
                Text(priority.label).tag(priority)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 82)
    }
}

struct ProgressPicker: View {
    @Binding var progress: TodoProgress

    var body: some View {
        Picker("推进状态", selection: $progress) {
            ForEach(TodoProgress.allCases) { progress in
                Text(progress.label).tag(progress)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 96)
    }
}
