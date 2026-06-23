import SwiftUI
import AppKit
import UniformTypeIdentifiers

private let statusColumnWidth: CGFloat = 82
private let progressColumnWidth: CGFloat = 104
private let priorityColumnWidth: CGFloat = 78
private let followUpColumnWidth: CGFloat = 154
private let todoActionColumnWidth: CGFloat = 128
private let compactHitTargetSize: CGFloat = 38
private let primarySidebarWidth: CGFloat = 76
private let secondarySidebarWidth: CGFloat = 250
private let collapsedSecondarySidebarWidth: CGFloat = 0

private enum AppMotion {
    static let press = Animation.easeOut(duration: 0.12)
    static let quick = Animation.easeInOut(duration: 0.14)
    static let hover = Animation.easeOut(duration: 0.12)
    static let smooth = Animation.easeInOut(duration: 0.18)
    static let reveal = Animation.easeInOut(duration: 0.16)
    static let list = Animation.easeInOut(duration: 0.16)
    static let capture = Animation.easeInOut(duration: 0.14)
    static let status = Animation.easeInOut(duration: 0.16)
    static let complete = Animation.easeInOut(duration: 0.16)
    static let modeSwitch = Animation.easeInOut(duration: 0.18)

    static var rowTransition: AnyTransition {
        .opacity
    }

    static var viewTransition: AnyTransition {
        .opacity
    }

    static var inlineTransition: AnyTransition {
        .opacity
    }
}

private struct TactilePlainButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(buttonFill(isPressed: configuration.isPressed))
            }
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.46)
            .animation(AppMotion.press, value: configuration.isPressed)
            .animation(AppMotion.hover, value: isHovered)
            .onHover { hovered in
                isHovered = hovered
            }
    }

    private func buttonFill(isPressed: Bool) -> Color {
        guard isEnabled else {
            return Color.clear
        }
        if isPressed {
            return AppTheme.accentSoft.opacity(0.82)
        }
        if isHovered {
            return Color.white.opacity(0.68)
        }
        return Color.clear
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
        case .ocean: Color(red: 0.972, green: 0.985, blue: 0.995)
        case .aurora: Color(red: 0.987, green: 0.984, blue: 0.996)
        case .board: Color(red: 0.984, green: 0.984, blue: 0.978)
        case .leafcutter: Color(red: 0.982, green: 0.968, blue: 0.928)
        }
    }

    static var sidebar: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.918, green: 0.950, blue: 0.982)
        case .aurora: Color(red: 0.952, green: 0.928, blue: 0.985)
        case .board: Color(red: 0.935, green: 0.932, blue: 0.952)
        case .leafcutter: Color(red: 0.938, green: 0.910, blue: 0.805)
        }
    }

    static var sidebarSelected: Color {
        switch AppSkin.current {
        case .ocean: Color.white.opacity(0.74)
        case .aurora: Color.white.opacity(0.72)
        case .board: Color.white.opacity(0.68)
        case .leafcutter: Color.white.opacity(0.64)
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
        case .ocean: Color(red: 0.245, green: 0.310, blue: 0.410)
        case .aurora: Color(red: 0.315, green: 0.300, blue: 0.405)
        case .board: Color(red: 0.245, green: 0.240, blue: 0.270)
        case .leafcutter: Color(red: 0.315, green: 0.245, blue: 0.165)
        }
    }

    static var panel: Color {
        switch AppSkin.current {
        case .ocean, .aurora: Color.white.opacity(0.985)
        case .board: Color.white.opacity(0.970)
        case .leafcutter: Color(red: 1.0, green: 0.988, blue: 0.950).opacity(0.985)
        }
    }

    static var row: Color {
        switch AppSkin.current {
        case .ocean: Color.white
        case .aurora: Color(red: 0.990, green: 0.982, blue: 1.0)
        case .board: Color(red: 0.980, green: 0.988, blue: 0.998)
        case .leafcutter: Color(red: 1.0, green: 0.986, blue: 0.942)
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
        case .ocean: Color(red: 0.705, green: 0.785, blue: 0.875)
        case .aurora: Color(red: 0.760, green: 0.705, blue: 0.880)
        case .board: Color(red: 0.745, green: 0.740, blue: 0.765)
        case .leafcutter: Color(red: 0.720, green: 0.640, blue: 0.500)
        }
    }

    static var hairline: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.780, green: 0.845, blue: 0.920)
        case .aurora: Color(red: 0.825, green: 0.770, blue: 0.925)
        case .board: Color(red: 0.805, green: 0.800, blue: 0.820)
        case .leafcutter: Color(red: 0.780, green: 0.700, blue: 0.560)
        }
    }

    static var accent: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.050, green: 0.520, blue: 0.490)
        case .aurora: Color(red: 0.430, green: 0.300, blue: 0.850)
        case .board: Color(red: 0.075, green: 0.070, blue: 0.080)
        case .leafcutter: Color(red: 0.705, green: 0.210, blue: 0.090)
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
        case .ocean: Color(red: 0.160, green: 0.300, blue: 0.500).opacity(0.12)
        case .aurora: Color(red: 0.420, green: 0.300, blue: 0.620).opacity(0.12)
        case .board: Color.black.opacity(0.10)
        case .leafcutter: Color(red: 0.360, green: 0.220, blue: 0.110).opacity(0.13)
        }
    }

    static var rowShadow: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.160, green: 0.300, blue: 0.500).opacity(0.07)
        case .aurora: Color(red: 0.420, green: 0.300, blue: 0.620).opacity(0.07)
        case .board: Color.black.opacity(0.05)
        case .leafcutter: Color(red: 0.360, green: 0.220, blue: 0.110).opacity(0.07)
        }
    }

    static var accentWarm: Color {
        switch AppSkin.current {
        case .ocean: Color(red: 0.918, green: 0.345, blue: 0.047)
        case .aurora: Color(red: 0.905, green: 0.300, blue: 0.520)
        case .board: Color(red: 0.790, green: 0.310, blue: 0.130)
        case .leafcutter: Color(red: 0.920, green: 0.395, blue: 0.085)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: TodoStore
    @EnvironmentObject private var aiSettings: AISettingsStore
    @EnvironmentObject private var updateController: UpdateController
    @AppStorage(AppSkin.storageKey) private var selectedSkinRawValue = AppSkin.ocean.rawValue
    @State private var activeSection: AppSection = .todos
    @State private var scope: TodoScope = .all
    @State private var handbookCategory: HandbookCategory? = nil
    @State private var handbookFolder: String? = nil
    @State private var searchText = ""
    @State private var handbookSearchText = ""
    @State private var newTitle = ""
    @State private var newPriority: TodoPriority = .medium
    @State private var newProgress: TodoProgress = .pending
    @State private var newDate = Date()
    @State private var newNotes = ""
    @State private var newIsWeekly = false
    @State private var isQuickCaptureExpanded = false
    @State private var isCreatingTodo = false
    @State private var aiStatusMessage: String?
    @State private var quickCaptureAITrace: AITrace?
    @State private var quickCaptureAIResultSummary: String?
    @State private var isAISettingsPresented = false
    @State private var isAppSettingsPresented = false
    @State private var isSecondarySidebarCollapsed = false
    @State private var isHandbookContentReady = false
    @State private var allTodosViewMode: AllTodosViewMode = .compact
    @FocusState private var focusedField: FocusField?

    private let calendar = Calendar.current

    var body: some View {
        ZStack(alignment: .leading) {
            PrimarySidebarView(
                activeSection: $activeSection,
                hasUpdate: updateController.hasAvailableUpdate,
                onOpenSettings: { isAppSettingsPresented = true }
            )
            .frame(width: primarySidebarWidth)
            .frame(maxHeight: .infinity)
            .zIndex(2)

            HStack(spacing: 0) {
                secondarySidebarContainer
                    .frame(
                        minWidth: currentSecondarySidebarWidth,
                        idealWidth: currentSecondarySidebarWidth,
                        maxWidth: currentSecondarySidebarWidth,
                        maxHeight: .infinity
                    )

                VStack(spacing: 0) {
                    AppTopBar(
                        title: contentTitle,
                        subtitle: contentSubtitle,
                        isSecondarySidebarCollapsed: $isSecondarySidebarCollapsed,
                        isAIEnabled: aiSettings.canUseAI,
                        onOpenAISettings: { isAISettingsPresented = true }
                    )
                    .frame(height: 48)

                    Divider()
                        .overlay(AppTheme.hairline)

                    contentColumn
                        .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    AppTheme.workSurface
                        .ignoresSafeArea(.container, edges: [.top, .bottom, .trailing])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.leading, primarySidebarWidth)
            .layoutPriority(1)
        }
        .background(AppTheme.sidebar.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .top)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(width: 1)
                .offset(x: primarySidebarWidth)
                .ignoresSafeArea(.container, edges: .vertical)
        }
        .overlay(alignment: .leading) {
            if !isSecondarySidebarCollapsed {
                Rectangle()
                    .fill(AppTheme.hairline)
                    .frame(width: 1)
                    .offset(x: primarySidebarWidth + currentSecondarySidebarWidth)
                    .ignoresSafeArea(.container, edges: .vertical)
            }
        }
        .foregroundStyle(AppTheme.ink)
        .font(.system(size: 13, weight: .regular, design: .default))
        .id(selectedSkinRawValue)
        .onAppear {
            activeAppSkin = AppSkin(rawValue: selectedSkinRawValue) ?? .ocean
        }
        .onChange(of: selectedSkinRawValue) { _, newValue in
            activeAppSkin = AppSkin(rawValue: newValue) ?? .ocean
        }
        .onChange(of: activeSection) { _, newValue in
            guard newValue == .handbook else {
                isHandbookContentReady = false
                return
            }

            isHandbookContentReady = false
            DispatchQueue.main.async {
                isHandbookContentReady = true
            }
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
        .sheet(isPresented: $isAISettingsPresented) {
            AISettingsSheet()
                .environmentObject(aiSettings)
        }
        .sheet(isPresented: $isAppSettingsPresented) {
            AppSettingsSheet(selectedSkinRawValue: $selectedSkinRawValue)
                .environmentObject(updateController)
        }
    }

    @ViewBuilder
    private var secondarySidebar: some View {
        switch activeSection {
        case .todos:
            TodoSidebarView(scope: $scope)
        case .handbook:
            HandbookSidebarView(
                selectedCategory: $handbookCategory,
                selectedFolder: $handbookFolder,
                searchText: $handbookSearchText
            )
        }
    }

    private var secondarySidebarContainer: some View {
        secondarySidebar
            .opacity(isSecondarySidebarCollapsed ? 0 : 1)
            .allowsHitTesting(!isSecondarySidebarCollapsed)
            .background(AppTheme.sidebar)
            .clipped()
            .animation(AppMotion.modeSwitch, value: isSecondarySidebarCollapsed)
    }

    private var currentSecondarySidebarWidth: CGFloat {
        isSecondarySidebarCollapsed ? collapsedSecondarySidebarWidth : secondarySidebarWidth
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch activeSection {
        case .todos:
            taskColumn
                .transition(AppMotion.viewTransition)
        case .handbook:
            handbookColumn
                .transition(AppMotion.viewTransition)
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
                notes: $newNotes,
                isWeekly: $newIsWeekly,
                isExpanded: $isQuickCaptureExpanded,
                focusedField: $focusedField,
                onCreate: createTodo,
                onClear: cancelCreate,
                isCreating: isCreatingTodo,
                aiStatusMessage: aiStatusMessage,
                aiTrace: quickCaptureAITrace,
                aiResultSummary: quickCaptureAIResultSummary,
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

    private var handbookColumn: some View {
        HandbookContentView(
            allItems: store.handbookItems,
            isReady: isHandbookContentReady,
            selectedCategory: handbookCategory,
            selectedFolder: handbookFolder,
            searchText: handbookSearchText,
            onCreate: createHandbookItem,
            onUpdate: updateHandbookItem,
            onDelete: deleteHandbookItem
        )
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AppTheme.workSurface)
        .animation(AppMotion.list, value: store.handbookItems.count)
        .animation(AppMotion.smooth, value: handbookCategory)
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

    private var contentTitle: String {
        switch activeSection {
        case .todos:
            return dayTitle
        case .handbook:
            return handbookCategory?.title ?? "手记"
        }
    }

    private var contentSubtitle: String {
        switch activeSection {
        case .todos:
            return daySubtitle
        case .handbook:
            if let handbookCategory {
                return "\(handbookCategory.subtitle)，用于沉淀可复用信息"
            }
            return "收集业务规则、调研、会议和灵感"
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

    private func createHandbookItem(
        category: HandbookCategory,
        folder: String,
        title: String,
        body: String,
        attachments: [HandbookAttachment]
    ) {
        withAnimation(AppMotion.capture) {
            store.addHandbookItem(category: category, folder: folder, title: title, body: body, attachments: attachments)
            handbookCategory = category
            handbookFolder = folder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : folder.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func updateHandbookItem(
        _ item: HandbookItem,
        category: HandbookCategory,
        folder: String,
        title: String,
        body: String,
        attachments: [HandbookAttachment]
    ) {
        withAnimation(AppMotion.smooth) {
            store.update(item, category: category, folder: folder, title: title, body: body, attachments: attachments)
            handbookCategory = category
            handbookFolder = folder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : folder.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func deleteHandbookItem(_ item: HandbookItem) {
        withAnimation(AppMotion.quick) {
            store.delete(item)
        }
    }

    private func focusQuickCapture() {
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
        newDate = Date()
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

enum AppSection: String, CaseIterable, Identifiable {
    case todos
    case handbook

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todos: "待办"
        case .handbook: "手记"
        }
    }

    var icon: String {
        switch self {
        case .todos: "checklist"
        case .handbook: "book.closed"
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

    var icon: String {
        switch self {
        case .compact: "text.alignleft"
        case .grouped: "calendar"
        case .board: "rectangle.3.group"
        case .matrix: "square.grid.2x2"
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
            .interactionHitArea()
        }
        .menuStyle(.borderlessButton)
        .help("切换皮肤")
    }
}

struct AppTopBar: View {
    let title: String
    let subtitle: String
    @Binding var isSecondarySidebarCollapsed: Bool
    let isAIEnabled: Bool
    let onOpenAISettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 24)

            HStack(spacing: 8) {
                SecondarySidebarCollapseButton(isCollapsed: $isSecondarySidebarCollapsed)
                AISettingsButton(isEnabled: isAIEnabled, action: onOpenAISettings)
            }
            .padding(.trailing, 16)
        }
        .padding(.leading, 20)
        .background(topBarBackground)
    }

    private var topBarBackground: some View {
        Color.clear
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
            .interactionHitArea()
        }
        .buttonStyle(.tactilePlain)
        .help("AI 设置")
    }
}

struct AppSettingsSheet: View {
    @EnvironmentObject private var updateController: UpdateController
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSkinRawValue: String

    private var selectedSkin: AppSkin {
        AppSkin(rawValue: selectedSkinRawValue) ?? .ocean
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("应用设置")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    Text("外观、版本与更新")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .interactionHitArea()
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .help("关闭")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()
                .overlay(AppTheme.hairline)

            VStack(alignment: .leading, spacing: 14) {
                settingsSection(title: "外观", icon: "paintpalette.fill") {
                    VStack(spacing: 7) {
                        ForEach(AppSkin.allCases) { skin in
                            Button {
                                withAnimation(AppMotion.smooth) {
                                    activeAppSkin = skin
                                    selectedSkinRawValue = skin.rawValue
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: skin.icon)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(skin == selectedSkin ? AppTheme.accent : AppTheme.mutedInk)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(skin.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(AppTheme.ink)
                                        Text(skin.shortTitle)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(AppTheme.mutedInk)
                                    }

                                    Spacer()

                                    if skin == selectedSkin {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(skin == selectedSkin ? AppTheme.accentSoft : Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(skin == selectedSkin ? AppTheme.accent.opacity(0.24) : AppTheme.hairline)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.tactilePlain)
                        }
                    }
                }

                settingsSection(title: "更新", icon: "arrow.triangle.2.circlepath") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 7) {
                                    Circle()
                                        .fill(updateStatusColor)
                                        .frame(width: 7, height: 7)
                                    Text(AppVersion.displayText)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(AppTheme.ink)
                                }

                                Text(updateStatusText)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(updateController.isChecking ? AppTheme.ink : AppTheme.mutedInk)
                                    .lineLimit(2)

                                if let lastCheckedAt = updateController.lastCheckedAt {
                                    Text("上次检查 \(lastCheckedAt.formatted(date: .omitted, time: .shortened))")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(AppTheme.mutedInk)
                                }
                            }

                            Spacer()

                            if updateController.availableUpdate != nil {
                                Button {
                                    updateController.downloadAvailableUpdate()
                                } label: {
                                    Label("下载", systemImage: "arrow.down.to.line")
                                        .font(.system(size: 12, weight: .semibold))
                                        .frame(width: 78, height: 32)
                                }
                                .buttonStyle(.tactilePlain)
                                .foregroundStyle(.white)
                                .background(AppTheme.accentWarm, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.white.opacity(0.28))
                                )
                                .help("下载当前发现的新版本")
                            }

                            Button {
                                updateController.checkForUpdates()
                            } label: {
                                Label(updateController.isChecking ? "检查中" : "检查更新", systemImage: updateController.isChecking ? "clock.arrow.circlepath" : "arrow.down.circle")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(width: 104, height: 32)
                            }
                            .buttonStyle(.tactilePlain)
                            .foregroundStyle(updateController.isChecking ? AppTheme.accent : .white)
                            .background(updateController.isChecking ? AppTheme.accentSoft : AppTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(updateController.isChecking ? AppTheme.accent.opacity(0.24) : Color.white.opacity(0.26))
                            )
                            .disabled(updateController.isChecking)
                            .help("检查更新")
                        }

                        updateReminderNote
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 460)
        .background(AppTheme.workSurface)
    }

    private var updateStatusText: String {
        if updateController.isChecking {
            return "正在检查远程版本..."
        }
        if let update = updateController.availableUpdate {
            return "可更新到 v\(update.version) (\(update.build))，设置入口会持续显示红点。"
        }
        return updateController.statusMessage ?? "每天自动检查一次，也可以手动检查。"
    }

    private var updateStatusColor: Color {
        if updateController.isChecking {
            return AppTheme.accentWarm
        }
        if updateController.availableUpdate != nil {
            return AppTheme.accent
        }
        if let message = updateController.statusMessage, message.contains("失败") || message.contains("没有发布") || message.contains("无效") {
            return TodoPriority.medium.displayColor
        }
        return Color(red: 0.18, green: 0.62, blue: 0.38)
    }

    private var updateReminderNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bell.badge")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(updateController.availableUpdate == nil ? AppTheme.mutedInk : TodoPriority.high.displayColor)
                .frame(width: 16)

            Text("提醒机制：启动和回到前台会自动检查；应用长期打开时每小时轮询一次，最多每天检查一次远端版本。发现新版本后，设置入口显示红点；自动弹窗按版本与时间节流，手动检查始终反馈结果。")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.72))
        )
    }

    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
            }

            content()
        }
        .padding(12)
        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border.opacity(0.78))
        )
    }
}

struct AISettingsSheet: View {
    @EnvironmentObject private var aiSettings: AISettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

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
        .frame(width: 720, height: 560)
        .background(AppTheme.workSurface)
        .foregroundStyle(AppTheme.ink)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentSoft)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text("AI 设置")
                    .font(.system(size: 25, weight: .semibold))
                Text("DeepSeek 负责智能解析、推进建议和备注摘要；密钥只保存在本机私有配置文件。")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(2)
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
    }

    private var settingsCard: some View {
        HStack(alignment: .top, spacing: 16) {
            statusPanel

            VStack(alignment: .leading, spacing: 12) {
                Text("连接配置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)

                LabeledContent("供应商") {
                    providerPill
                }

                LabeledContent("API 地址") {
                    AISettingsTextField("https://api.deepseek.com", text: $aiSettings.configuration.baseURL)
                }

                LabeledContent("模型") {
                    VStack(alignment: .leading, spacing: 5) {
                        DeepSeekModelPicker(model: $aiSettings.configuration.model)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(currentModelSubtitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                LabeledContent("API Key") {
                    SecureField("sk-...", text: $aiSettings.apiKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(aiSettings.hasAPIKey ? Color(red: 0.18, green: 0.62, blue: 0.38).opacity(0.36) : AppTheme.border)
                        )
                }

                securityNote

                if let trace = aiSettings.lastTrace {
                    AITraceDisclosure(trace: trace, isExpanded: .constant(true))
                }
            }
            .labeledContentStyle(AISettingsLabeledContentStyle())
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.border)
        )
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(aiSettings.configuration.isEnabled ? AppTheme.accent : AppTheme.mutedInk.opacity(0.22))
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(aiSettings.configuration.isEnabled ? "AI 已启用" : "AI 未启用")
                        .font(.system(size: 16, weight: .semibold))
                    Text(statusSubtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle(isOn: $aiSettings.configuration.isEnabled) {
                Text("启用 DeepSeek")
                    .font(.system(size: 13, weight: .semibold))
            }
            .toggleStyle(.switch)

            connectionControls
        }
        .padding(14)
        .frame(width: 210, alignment: .topLeading)
        .background(statusBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(statusStroke)
        )
    }

    private var statusSubtitle: String {
        if !aiSettings.configuration.isEnabled {
            return "填写密钥并打开开关后，快记和建议会调用 DeepSeek。"
        }
        if !aiSettings.hasAPIKey {
            return "还缺 API Key，当前不会发起 AI 请求。"
        }
        return aiSettings.connectionSucceeded ? "连接已验证，可用于当前工作流。" : "配置已就绪，建议先测试连接。"
    }

    private var statusBackground: Color {
        if aiSettings.connectionSucceeded {
            return Color(red: 0.90, green: 0.97, blue: 0.91)
        }
        return aiSettings.configuration.isEnabled ? AppTheme.accentSoft : Color.white.opacity(0.78)
    }

    private var statusStroke: Color {
        if aiSettings.connectionSucceeded {
            return Color(red: 0.18, green: 0.62, blue: 0.38).opacity(0.30)
        }
        return aiSettings.configuration.isEnabled ? AppTheme.accent.opacity(0.24) : AppTheme.hairline
    }

    private var providerPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text(aiSettings.configuration.provider.title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("HTTPS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 0.14, green: 0.58, blue: 0.34))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(red: 0.14, green: 0.58, blue: 0.34).opacity(0.10), in: Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.90), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline)
        )
    }

    private var securityNote: some View {
        Label("API Key 保存到本机用户目录的私有文件，权限 600，不写入源码或 Git 仓库；这不是 Keychain 加密。", systemImage: "lock.shield")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppTheme.accentSoft.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var currentModelSubtitle: String {
        DeepSeekModel(rawValue: aiSettings.configuration.model)?.subtitle ?? "自定义模型名，请确认该模型兼容 Chat Completions。"
    }

    private var connectionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task {
                    await aiSettings.testConnection()
                }
            } label: {
                Label(aiSettings.isTestingConnection ? "测试中" : "测试连接", systemImage: "network")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.tactilePlain)
            .foregroundStyle(.white)
            .background(aiSettings.configuration.hasEndpoint && aiSettings.hasAPIKey ? AppTheme.accent : Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .interactionHitArea()
            .disabled(aiSettings.isTestingConnection || !aiSettings.configuration.hasEndpoint || !aiSettings.hasAPIKey)

            if let message = aiSettings.connectionMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: aiSettings.connectionSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.top, 1)
                    Text(message)
                        .font(.system(size: 11, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(aiSettings.connectionSucceeded ? Color(red: 0.14, green: 0.58, blue: 0.34) : TodoPriority.high.displayColor)
            } else if aiSettings.isTestingConnection {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在请求 DeepSeek")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }
        }
    }

    private var usageSection: some View {
        HStack(spacing: 10) {
            AIUsageRow(icon: "command", title: "快记解析", detail: "自动拆出时间、优先级、状态、备注和固定周期。")
            AIUsageRow(icon: "sun.max", title: "每日建议", detail: "按当前未完成事项生成 1-3 条推进建议。")
            AIUsageRow(icon: "text.alignleft", title: "备注摘要", detail: "长备注压缩成适合扫读的一句话。")
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

struct AISettingsTextField: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.border)
            )
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
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 22, height: 22)
                .background(AppTheme.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.hairline)
        )
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

struct PrimarySidebarView: View {
    @Binding var activeSection: AppSection
    let hasUpdate: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                ForEach(AppSection.allCases) { section in
                    PrimarySidebarButton(
                        section: section,
                        isSelected: activeSection == section
                    ) {
                        withAnimation(AppMotion.modeSwitch) {
                            activeSection = section
                        }
                    }
                }
            }
            .padding(.top, 52)

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                AppLogoImage()
                    .frame(width: 42, height: 42)

                Text("蚁序")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                Button(action: onOpenSettings) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .semibold))
                            .interactionHitArea()

                        if hasUpdate {
                            UpdateDot(size: 8)
                                .offset(x: -6, y: 7)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(hasUpdate ? AppTheme.accent : AppTheme.mutedInk)
                .help(hasUpdate ? "有新版本，打开设置查看" : "应用设置")
            }
            .padding(.bottom, 14)
        }
        .frame(width: primarySidebarWidth)
        .frame(maxHeight: .infinity)
        .background(AppTheme.sidebar)
    }
}

struct UpdateDot: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(TodoPriority.high.displayColor)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.92), lineWidth: max(1, size * 0.18))
            )
            .shadow(color: TodoPriority.high.displayColor.opacity(0.35), radius: 4, x: 0, y: 1)
            .accessibilityLabel("有可用更新")
    }
}

struct SecondarySidebarCollapseButton: View {
    @Binding var isCollapsed: Bool
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(AppMotion.modeSwitch) {
                isCollapsed.toggle()
            }
        } label: {
            Image(systemName: isCollapsed ? "sidebar.leading" : "sidebar.left")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isCollapsed ? AppTheme.accent : AppTheme.mutedInk)
                .frame(width: 34, height: 30)
                .background(buttonBackground, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.hairline.opacity(isHovered || isCollapsed ? 0.92 : 0.56))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.tactilePlain)
        .interactionHitArea()
        .help(isCollapsed ? "展开辅导航" : "收起辅导航")
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
    }

    private var buttonBackground: Color {
        if isCollapsed {
            return AppTheme.panel.opacity(0.96)
        }
        if isHovered {
            return Color.white.opacity(0.82)
        }
        return Color.white.opacity(0.58)
    }
}

struct PrimarySidebarButton: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: section.icon)
                    .font(.system(size: 18, weight: .bold))
                Text(section.title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk)
            .frame(width: 58, height: 56)
            .background(buttonBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.22) : Color.white.opacity(isHovered ? 0.38 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.tactilePlain)
        .help(section.title)
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
    }

    private var buttonBackground: Color {
        if isSelected {
            return AppTheme.sidebarSelected
        }
        if isHovered {
            return Color.white.opacity(0.44)
        }
        return Color.clear
    }
}

struct TodoSidebarView: View {
    @EnvironmentObject private var store: TodoStore
    @Binding var scope: TodoScope
    @State private var calendarMonth = Date()

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    navigationGroup
                    quickDateGroup
                    miniCalendarGroup
                }
                .padding(.horizontal, 17)
                .padding(.top, 48)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)

            Divider()
                .overlay(AppTheme.hairline.opacity(0.7))

            sidebarSummary
        }
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

    private var navigationGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            DateButton(
                title: "今日推进",
                subtitle: "风险优先，推进今天",
                systemImage: "target",
                count: dashboardCount,
                alertCount: overdueCount,
                isSelected: scope == .dashboard
            ) {
                scope = .dashboard
            }

            DateButton(
                title: "等待反馈",
                subtitle: "需要别人推进",
                systemImage: "person.2.fill",
                count: waitingCount,
                isSelected: scope == .waiting
            ) {
                scope = .waiting
            }

            DateButton(
                title: "本周固定",
                subtitle: "重复管理动作",
                systemImage: "repeat",
                count: weeklyCount,
                isSelected: scope == .weekly
            ) {
                scope = .weekly
            }

            DateButton(
                title: "全部待办",
                subtitle: "完整任务池",
                systemImage: "tray.full.fill",
                count: activeCount,
                isSelected: scope == .all
            ) {
                scope = .all
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickDateGroup: some View {
        VStack(alignment: .leading, spacing: 7) {
            SidebarSectionLabel("快速日期")

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
    }

    private var miniCalendarGroup: some View {
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
    }

    private var sidebarSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("待办")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Text("未完成 \(activeCount) · 逾期 \(overdueCount)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 13)
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
    let systemImage: String
    let count: Int
    var alertCount: Int = 0
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

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

                if count > 0 || alertCount > 0 {
                    Text(countText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isSelected ? .white : countColor)
                        .frame(minWidth: 24, minHeight: 20)
                        .background(isSelected ? countColor : countColor.opacity(0.11), in: Capsule())
                        .help(countHelp)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(navBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.24) : Color.white.opacity(isHovered ? 0.36 : 0.0))
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
            return Color.white.opacity(0.46)
        }
        return Color.clear
    }

    private var countText: String {
        if alertCount > 0 {
            return "\(alertCount)"
        }
        return "\(count)"
    }

    private var countColor: Color {
        alertCount > 0 ? TodoPriority.high.displayColor : AppTheme.accent
    }

    private var countHelp: String {
        alertCount > 0 ? "逾期未完成" : "未完成事项"
    }
}

struct HandbookSidebarView: View {
    @EnvironmentObject private var store: TodoStore
    @Binding var selectedCategory: HandbookCategory?
    @Binding var selectedFolder: String?
    @Binding var searchText: String

    var body: some View {
        let metrics = HandbookSidebarMetrics(items: store.handbookItems, selectedCategory: selectedCategory)

        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    SearchField(text: $searchText)
                    categoryList(metrics: metrics)
                    folderList(metrics: metrics)
                }
                .padding(.horizontal, 17)
                .padding(.top, 48)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)

            Divider()
                .overlay(AppTheme.hairline.opacity(0.7))

            VStack(alignment: .leading, spacing: 4) {
                Text("手记")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("共 \(metrics.totalCount) 条沉淀")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 13)
        }
        .background(AppTheme.sidebar)
        .foregroundStyle(AppTheme.ink)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("手记")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Text("业务规则、调研、会议、灵感")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
    }

    private func categoryList(metrics: HandbookSidebarMetrics) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SidebarSectionLabel("分类")

            HandbookCategoryButton(
                title: "全部手记",
                subtitle: "完整知识池",
                systemImage: "tray.full",
                count: metrics.totalCount,
                isSelected: selectedCategory == nil
            ) {
                selectedCategory = nil
                selectedFolder = nil
            }

            ForEach(HandbookCategory.allCases) { category in
                HandbookCategoryButton(
                    title: category.title,
                    subtitle: category.subtitle,
                    systemImage: category.icon,
                    count: metrics.categoryCounts[category, default: 0],
                    isSelected: selectedCategory == category
                ) {
                    selectedCategory = category
                    selectedFolder = nil
                }
            }
        }
    }

    private func folderList(metrics: HandbookSidebarMetrics) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SidebarSectionLabel("二级目录")

            HandbookCategoryButton(
                title: "全部目录",
                subtitle: "不按目录过滤",
                systemImage: "folder",
                count: metrics.scopedCount,
                isSelected: selectedFolder == nil
            ) {
                selectedFolder = nil
            }

            if metrics.folders.isEmpty {
                Text("在快记或编辑中填写目录后自动归类")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.34), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                ForEach(metrics.folders, id: \.self) { folder in
                    HandbookCategoryButton(
                        title: folder,
                        subtitle: "自定义归类",
                        systemImage: "folder.fill",
                        count: metrics.folderCounts[folder, default: 0],
                        isSelected: selectedFolder == folder
                    ) {
                        selectedFolder = folder
                    }
                }
            }
        }
    }
}

private struct HandbookSidebarMetrics {
    let totalCount: Int
    let scopedCount: Int
    let categoryCounts: [HandbookCategory: Int]
    let folderCounts: [String: Int]
    let folders: [String]

    init(items: [HandbookItem], selectedCategory: HandbookCategory?) {
        var categoryCounts: [HandbookCategory: Int] = [:]
        var folderCounts: [String: Int] = [:]
        var scopedCount = 0

        for item in items {
            categoryCounts[item.category, default: 0] += 1
            guard selectedCategory == nil || item.category == selectedCategory else { continue }
            scopedCount += 1

            let folder = item.trimmedFolder
            if !folder.isEmpty {
                folderCounts[folder, default: 0] += 1
            }
        }

        self.totalCount = items.count
        self.scopedCount = scopedCount
        self.categoryCounts = categoryCounts
        self.folderCounts = folderCounts
        self.folders = folderCounts.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}

struct HandbookCategoryButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

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

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isSelected ? .white : AppTheme.accent)
                        .frame(minWidth: 24, minHeight: 20)
                        .background(isSelected ? AppTheme.accent : AppTheme.accent.opacity(0.11), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(navBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.24) : Color.white.opacity(isHovered ? 0.36 : 0.0))
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
            return Color.white.opacity(0.46)
        }
        return Color.clear
    }
}

struct SidebarSectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.mutedInk)
            .textCase(.none)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct QuickDateStrip: View {
    let dates: [Date]
    let selectedDate: Date?
    let pendingCount: (Date) -> Int
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let calendar = Calendar.current

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
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
            .background(isSelected ? AppTheme.accent : Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)
    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]
    private let monthOptions = Array(1...12)

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                SidebarSectionLabel("有记录")
                Spacer()
                yearStepper
            }

            monthStepper

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
                            .frame(height: 30)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(AppTheme.hairline)
            )
        }
    }

    private var yearStepper: some View {
        HStack(spacing: 2) {
            calendarStepButton(systemImage: "chevron.left.2", help: "上一年") {
                shiftYear(-1)
            }

            Menu {
                ForEach(yearOptions, id: \.self) { year in
                    Button {
                        setYear(year)
                    } label: {
                        HStack {
                            Text("\(year) 年")
                            if year == currentYear {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(yearTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                        .monospacedDigit()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .frame(minWidth: 62, minHeight: 28)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help("选择年份")

            calendarStepButton(systemImage: "chevron.right.2", help: "下一年") {
                shiftYear(1)
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.68), in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.hairline.opacity(0.78))
        )
    }

    private var monthStepper: some View {
        HStack(spacing: 4) {
            calendarStepButton(systemImage: "chevron.left", help: "上个月") {
                shiftMonth(-1)
            }

            Menu {
                ForEach(monthOptions, id: \.self) { month in
                    Button {
                        setMonth(month)
                    } label: {
                        HStack {
                            Text(monthName(for: month))
                            if month == currentMonth {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(monthTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: 28)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help("选择月份")

            calendarStepButton(systemImage: "chevron.right", help: "下个月") {
                shiftMonth(1)
            }
        }
        .foregroundStyle(AppTheme.mutedInk)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.78))
        )
    }

    private func calendarStepButton(systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 8, weight: .bold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.tactilePlain)
        .help(help)
    }

    private var yearTitle: String {
        visibleMonth.formatted(.dateTime.year())
    }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide))
    }

    private var currentYear: Int {
        calendar.component(.year, from: visibleMonth)
    }

    private var currentMonth: Int {
        calendar.component(.month, from: visibleMonth)
    }

    private var yearOptions: [Int] {
        let base = currentYear
        return Array((base - 5)...(base + 5))
    }

    private func shiftMonth(_ value: Int) {
        if let nextMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) {
            withAnimation(AppMotion.quick) {
                visibleMonth = nextMonth
            }
        }
    }

    private func shiftYear(_ value: Int) {
        if let nextYear = calendar.date(byAdding: .year, value: value, to: visibleMonth) {
            withAnimation(AppMotion.quick) {
                visibleMonth = nextYear
            }
        }
    }

    private func setYear(_ year: Int) {
        var components = calendar.dateComponents([.year, .month], from: visibleMonth)
        components.year = year
        components.day = 1
        if let nextDate = calendar.date(from: components) {
            withAnimation(AppMotion.quick) {
                visibleMonth = nextDate
            }
        }
    }

    private func setMonth(_ month: Int) {
        var components = calendar.dateComponents([.year, .month], from: visibleMonth)
        components.month = month
        components.day = 1
        if let nextDate = calendar.date(from: components) {
            withAnimation(AppMotion.quick) {
                visibleMonth = nextDate
            }
        }
    }

    private func monthName(for month: Int) -> String {
        var components = DateComponents()
        components.year = currentYear
        components.month = month
        components.day = 1
        guard let date = calendar.date(from: components) else {
            return "\(month) 月"
        }
        return date.formatted(.dateTime.month(.wide))
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
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(stroke)
                    )
                    .frame(width: 24, height: 30)

                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 12, weight: isToday || isSelected ? .bold : .semibold))
                        .monospacedDigit()
                    markerStrip
                }
                .foregroundStyle(foreground)
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .contentShape(Rectangle())
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

    @ViewBuilder
    private var markerStrip: some View {
        if totalCount > 0 {
            HStack(spacing: 2) {
                Circle()
                    .fill(isSelected ? Color.white : markerColor)
                    .frame(width: 4, height: 4)
                if pendingCount > 0 && pendingCount != totalCount {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.72) : AppTheme.accentWarm.opacity(0.82))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 5)
        } else {
            Color.clear
                .frame(height: 5)
        }
    }

    private var foreground: Color {
        if isSelected { return .white }
        if !isInCurrentMonth { return AppTheme.mutedInk.opacity(0.45) }
        if isToday { return AppTheme.accent }
        return AppTheme.ink
    }

    private var background: Color {
        if isSelected { return AppTheme.accent }
        if isToday { return AppTheme.accentSoft.opacity(0.92) }
        return Color.white.opacity(totalCount > 0 ? 0.60 : 0.0)
    }

    private var stroke: Color {
        if isSelected { return AppTheme.accent.opacity(0.36) }
        if isToday { return AppTheme.accent.opacity(0.22) }
        return totalCount > 0 ? AppTheme.hairline : Color.clear
    }
}

struct SearchField: View {
    @Binding var text: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(text.isEmpty ? AppTheme.mutedInk : AppTheme.accent)
            TextField("搜索标题或备注", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.ink)
            if !text.isEmpty {
                Button {
                    withAnimation(AppMotion.quick) {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .interactionHitArea()
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(isHovered ? 0.96 : 0.86), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(text.isEmpty ? AppTheme.hairline.opacity(0.75) : AppTheme.accent.opacity(0.22))
        )
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
        .animation(AppMotion.quick, value: text.isEmpty)
    }
}

struct AllTodosViewModePicker: View {
    @Binding var selection: AllTodosViewMode

    var body: some View {
        HStack(spacing: 3) {
            ForEach(AllTodosViewMode.allCases) { mode in
                Button {
                    withAnimation(AppMotion.modeSwitch) {
                        selection = mode
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(mode.label)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(selection == mode ? .white : AppTheme.mutedInk)
                    .frame(height: 30)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selection == mode ? AppTheme.accent : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selection == mode ? Color.white.opacity(0.24) : Color.clear, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.tactilePlain)
                .help("\(mode.label)视图")
            }
        }
        .padding(3)
        .frame(width: 318)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.82))
        )
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
        .padding(5)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
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

    @State private var dailySuggestion: String?
    @State private var dailySuggestionError: String?
    @State private var dailySuggestionTrace: AITrace?
    @State private var dailySuggestionStep: String?
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
                        onDelete: { onDelete(todo) }
                    )
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
                            onDelete: { onDelete(todo) }
                        )
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
                        onDelete: { onDelete(todo) }
                    )
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
    }
}

struct TodoBoardCard: View {
    let todo: TodoItem
    let onToggle: () -> Void
    let onProgressChange: (TodoProgress) -> Void
    let onUpdate: (TodoDraft) -> Void
    let onDelete: () -> Void

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
                                .fill(todo.isDone ? TodoProgress.done.displayColor.opacity(0.17) : Color.white.opacity(0.72))
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
            .shadow(color: isHovered ? AppTheme.rowShadow.opacity(0.95) : AppTheme.rowShadow.opacity(0.62), radius: isHovered ? 10 : 6, x: 0, y: isHovered ? 5 : 3)
            .onHover { hovered in
                withAnimation(AppMotion.hover) {
                    isHovered = hovered
                }
            }
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
        AppTheme.rowTint(priority: todo.priority, isOverdue: isOverdue)
    }

    private var cardBorderColor: Color {
        if isOverdue {
            return TodoPriority.high.displayColor.opacity(isHovered ? 0.42 : 0.26)
        }
        return isHovered ? todo.priority.displayColor.opacity(0.36) : AppTheme.border
    }

    private var priorityRailColor: Color {
        if todo.isDone {
            return TodoProgress.done.displayColor.opacity(0.48)
        }
        return isOverdue ? TodoPriority.high.displayColor : todo.priority.displayColor.opacity(0.78)
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

struct HandbookContentView: View {
    let allItems: [HandbookItem]
    let isReady: Bool
    let selectedCategory: HandbookCategory?
    let selectedFolder: String?
    let searchText: String
    let onCreate: (HandbookCategory, String, String, String, [HandbookAttachment]) -> Void
    let onUpdate: (HandbookItem, HandbookCategory, String, String, String, [HandbookAttachment]) -> Void
    let onDelete: (HandbookItem) -> Void

    @State private var draftTitle = ""
    @State private var draftBody = ""
    @State private var selectedItemID: UUID?
    @State private var shouldSelectLatestAfterCreate = false
    @State private var activeFilter: HandbookListFilter = .all
    @State private var isDetailReady = false
    @FocusState private var focusedField: HandbookFocusField?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HandbookCaptureBar(
                title: $draftTitle,
                content: $draftBody,
                focusedField: $focusedField,
                suggestedCategory: selectedCategory,
                suggestedFolder: selectedFolder,
                onCreate: submit
            )

            contentArea
        }
        .animation(AppMotion.list, value: selectedItemID)
        .onChange(of: allItems) { _, newItems in
            syncSelection(with: visibleItems(from: newItems))
        }
        .onChange(of: selectedCategory) { _, _ in
            syncSelection(with: visibleItems(from: allItems))
        }
        .onChange(of: selectedFolder) { _, _ in
            syncSelection(with: visibleItems(from: allItems))
        }
        .onChange(of: searchText) { _, _ in
            syncSelection(with: visibleItems(from: allItems))
        }
        .onChange(of: activeFilter) { _, _ in
            syncSelection(with: visibleItems(from: allItems))
        }
        .onAppear {
            if isReady {
                syncSelection(with: visibleItems(from: allItems))
            }
        }
        .onChange(of: isReady) { _, newValue in
            guard newValue else {
                isDetailReady = false
                return
            }
            syncSelection(with: visibleItems(from: allItems))
            DispatchQueue.main.async {
                isDetailReady = true
            }
        }
    }

    private func submit() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = draftBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !body.isEmpty else {
            focusedField = .title
            return
        }
        let category = selectedCategory ?? HandbookCategory.infer(from: "\(title)\n\(body)")
        let folder = (selectedFolder ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        onCreate(category, folder, title, body, [])
        shouldSelectLatestAfterCreate = true
        activeFilter = .all
        draftTitle = ""
        draftBody = ""
        focusedField = .title
    }

    private func selectedItem(in visibleItems: [HandbookItem]) -> HandbookItem? {
        guard let selectedItemID else {
            return visibleItems.first
        }
        return visibleItems.first { $0.id == selectedItemID } ?? visibleItems.first
    }

    private func scopedItems(from sourceItems: [HandbookItem]) -> [HandbookItem] {
        let cleanedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return sourceItems.filter { item in
            (selectedCategory == nil || item.category == selectedCategory)
                && matchesFolder(item)
                && matchesSearch(item, query: cleanedQuery)
        }
    }

    private func visibleItems(from sourceItems: [HandbookItem]) -> [HandbookItem] {
        activeFilter.filter(scopedItems(from: sourceItems))
    }

    private func matchesFolder(_ item: HandbookItem) -> Bool {
        guard let selectedFolder, !selectedFolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        return item.trimmedFolder == selectedFolder.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchesSearch(_ item: HandbookItem, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return item.title.localizedCaseInsensitiveContains(query)
            || item.body.localizedCaseInsensitiveContains(query)
            || item.folder.localizedCaseInsensitiveContains(query)
            || item.category.title.localizedCaseInsensitiveContains(query)
            || item.attachments.contains { $0.name.localizedCaseInsensitiveContains(query) }
    }

    @ViewBuilder
    private var contentArea: some View {
        if !isReady {
            handbookLoadingShell
                .transition(AppMotion.inlineTransition)
        } else {
            let items = scopedItems(from: allItems)
            let visibleItems = activeFilter.filter(items)
            let selectedItem = selectedItem(in: visibleItems)

            if items.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    handbookListCard(itemsCount: items.count, visibleItems: visibleItems, selectedItem: selectedItem)
                        .frame(minWidth: 230, idealWidth: 260, maxWidth: 300, maxHeight: .infinity)

                    HandbookEmptyState(category: selectedCategory)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(AppMotion.viewTransition)
            } else if visibleItems.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    handbookListCard(itemsCount: items.count, visibleItems: visibleItems, selectedItem: selectedItem)
                        .frame(minWidth: 230, idealWidth: 260, maxWidth: 300, maxHeight: .infinity)

                    HandbookFilteredEmptyState(filter: activeFilter)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(AppMotion.viewTransition)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    handbookListCard(itemsCount: items.count, visibleItems: visibleItems, selectedItem: selectedItem)
                        .frame(minWidth: 230, idealWidth: 260, maxWidth: 300, maxHeight: .infinity)

                    if isDetailReady {
                        HandbookDetailPanel(
                            item: selectedItem,
                            onUpdate: onUpdate,
                            onDelete: { item in
                                onDelete(item)
                                if selectedItemID == item.id {
                                    selectedItemID = nil
                                }
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(AppMotion.inlineTransition)
                    } else {
                        handbookDetailLoadingPanel
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(AppMotion.inlineTransition)
                    }
                }
                .transition(AppMotion.viewTransition)
            }
        }
    }

    private var handbookLoadingShell: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                HandbookListCardHeader(
                    selectedCategory: selectedCategory,
                    selectedFolder: selectedFolder,
                    totalCount: allItems.count,
                    visibleCount: 0,
                    activeFilter: $activeFilter
                )

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(AppTheme.hairline.opacity(index == 0 ? 0.58 : 0.34))
                            .frame(height: index == 0 ? 72 : 58)
                    }
                }
                .padding(7)
            }
            .frame(minWidth: 230, idealWidth: 260, maxWidth: 300, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.panel.opacity(0.66), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(AppTheme.hairline.opacity(0.62))
            )

            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(AppTheme.panel.opacity(0.58))
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppTheme.hairline.opacity(0.48))
                            .frame(width: 220, height: 18)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppTheme.hairline.opacity(0.28))
                            .frame(width: 340, height: 12)
                    }
                    .padding(20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel("正在加载手记")
    }

    private var handbookDetailLoadingPanel: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(AppTheme.panel.opacity(0.68))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.hairline.opacity(0.48))
                        .frame(width: 220, height: 18)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.hairline.opacity(0.28))
                        .frame(width: 340, height: 12)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.hairline.opacity(0.22))
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .padding(.top, 12)
                }
                .padding(20)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(AppTheme.hairline.opacity(0.60))
            )
            .accessibilityLabel("正在准备手记详情")
    }

    private func handbookListCard(itemsCount: Int, visibleItems: [HandbookItem], selectedItem: HandbookItem?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HandbookListCardHeader(
                selectedCategory: selectedCategory,
                selectedFolder: selectedFolder,
                totalCount: itemsCount,
                visibleCount: visibleItems.count,
                activeFilter: $activeFilter
            )

            Divider()
                .overlay(AppTheme.hairline.opacity(0.56))

            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(visibleItems) { item in
                        HandbookRow(
                            item: item,
                            isSelected: selectedItem?.id == item.id,
                            onSelect: {
                                withAnimation(AppMotion.smooth) {
                                    selectedItemID = item.id
                                }
                            }
                        )
                        .transition(AppMotion.rowTransition)
                    }
                }
                .padding(7)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppTheme.panel.opacity(0.74), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.72))
        )
        .shadow(color: AppTheme.rowShadow.opacity(0.22), radius: 5, x: 0, y: 2)
    }

    private func syncSelection(with currentItems: [HandbookItem]) {
        if shouldSelectLatestAfterCreate {
            selectedItemID = currentItems.first?.id
            shouldSelectLatestAfterCreate = false
            return
        }

        guard !currentItems.isEmpty else {
            selectedItemID = nil
            return
        }

        if let selectedItemID, currentItems.contains(where: { $0.id == selectedItemID }) {
            return
        }

        selectedItemID = currentItems.first?.id
    }
}

enum HandbookFocusField: Hashable {
    case title
    case body
}

enum HandbookListFilter: String, CaseIterable, Identifiable {
    case all
    case recent
    case attached
    case longform

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .recent: "最近"
        case .attached: "附件"
        case .longform: "沉淀"
        }
    }

    var icon: String {
        switch self {
        case .all: "tray.full"
        case .recent: "clock"
        case .attached: "paperclip"
        case .longform: "doc.richtext"
        }
    }

    var emptyText: String {
        switch self {
        case .all: "当前没有手记"
        case .recent: "最近 7 天没有更新的手记"
        case .attached: "当前范围没有带附件的手记"
        case .longform: "当前范围还没有中篇或文章"
        }
    }

    func filter(_ items: [HandbookItem]) -> [HandbookItem] {
        switch self {
        case .all:
            return items
        case .recent:
            let threshold = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
            return items.filter { $0.updatedAt >= threshold }
        case .attached:
            return items.filter { !$0.attachments.isEmpty }
        case .longform:
            return items.filter { $0.lengthKind == .medium || $0.lengthKind == .article }
        }
    }
}

struct HandbookListCardHeader: View {
    let selectedCategory: HandbookCategory?
    let selectedFolder: String?
    let totalCount: Int
    let visibleCount: Int
    @Binding var activeFilter: HandbookListFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(contextTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                Text(contextSubtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                ForEach(HandbookListFilter.allCases) { filter in
                    HandbookFilterChip(
                        filter: filter,
                        isActive: activeFilter == filter,
                        onSelect: {
                            withAnimation(AppMotion.modeSwitch) {
                                activeFilter = filter
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 11)
        .padding(.top, 10)
        .padding(.bottom, 9)
        .background(AppTheme.panel.opacity(0.84))
    }

    private var contextTitle: String {
        if let selectedFolder, !selectedFolder.isEmpty {
            return selectedFolder
        }
        return selectedCategory?.title ?? "手记工作台"
    }

    private var contextSubtitle: String {
        let scope = selectedCategory?.subtitle ?? "规则、调研、会议与灵感的收集沉淀"
        if activeFilter == .all {
            return "\(scope) · \(totalCount) 条沉淀"
        }
        return "\(scope) · \(activeFilter.title) \(visibleCount)/\(totalCount)"
    }
}

struct HandbookFilterChip: View {
    let filter: HandbookListFilter
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 5) {
                Image(systemName: filter.icon)
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 15)

                if isActive {
                    Text(filter.title)
                        .font(.system(size: 11, weight: .bold))
                        .transition(AppMotion.inlineTransition)
                }
            }
            .padding(.horizontal, isActive ? 8 : 6)
            .frame(minWidth: isActive ? 58 : 30, minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.tactilePlain)
        .foregroundStyle(isActive ? AppTheme.accent : AppTheme.mutedInk)
        .background(isActive ? AppTheme.accentSoft.opacity(0.92) : Color.white.opacity(0.48), in: Capsule())
        .overlay(
            Capsule()
                .stroke(isActive ? AppTheme.accent.opacity(0.22) : AppTheme.hairline.opacity(0.56))
        )
        .help(filter.title)
    }
}

struct HandbookCaptureBar: View {
    @Binding var title: String
    @Binding var content: String
    var focusedField: FocusState<HandbookFocusField?>.Binding
    let suggestedCategory: HandbookCategory?
    let suggestedFolder: String?
    let onCreate: () -> Void
    @State private var isHovered = false
    @State private var isExpanded = false

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var inferredCategory: HandbookCategory {
        suggestedCategory ?? HandbookCategory.infer(from: "\(title)\n\(content)")
    }

    private var categoryTone: HandbookCategory {
        inferredCategory
    }

    private var hasInput: Bool {
        canCreate
    }

    private var shouldShowContextLine: Bool {
        isExpanded || !content.isEmpty || suggestedFolder?.isEmpty == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded || !content.isEmpty ? 8 : 6) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(categoryTone.accentColor)
                    .frame(width: 28, height: 28)
                    .background(categoryTone.softColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                if hasInput || suggestedCategory != nil {
                    HandbookInferenceBadge(category: inferredCategory, isLocked: suggestedCategory != nil)
                        .transition(AppMotion.inlineTransition)
                }

                TextField("快速收集：会议结论、业务规则、调研发现或灵感", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .focused(focusedField, equals: .title)
                    .submitLabel(.done)
                    .onSubmit {
                        submitIfReady()
                    }

                Button {
                    withAnimation(AppMotion.reveal) {
                        isExpanded.toggle()
                        if isExpanded {
                            focusedField.wrappedValue = .body
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "text.alignleft")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .help(isExpanded ? "收起正文" : "展开正文")

                Button {
                    onCreate()
                    if canCreate {
                        withAnimation(AppMotion.capture) {
                            isExpanded = false
                        }
                    }
                } label: {
                    Label("收集", systemImage: "tray.and.arrow.down")
                        .font(.caption.weight(.semibold))
                        .frame(width: 72, height: 30)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(.white)
                .background(canCreate ? AppTheme.accentWarm : Color.black.opacity(0.28), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(canCreate ? Color.white.opacity(0.42) : Color.black.opacity(0.05))
                )
                .interactionHitArea()
                .disabled(!canCreate)
            }

            if shouldShowContextLine {
                captureContextLine
                    .padding(.leading, 36)
                    .padding(.trailing, 2)
                    .transition(AppMotion.inlineTransition)
            }

            if isExpanded || !content.isEmpty {
                HandbookBodyEditor(
                    "补充正文：记录背景、证据、结论或可复用口径",
                    text: $content,
                    minHeight: 66,
                    maxHeight: 150
                )
                    .focused(focusedField, equals: .body)
                    .transition(AppMotion.inlineTransition)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, isExpanded || !content.isEmpty ? 9 : 7)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(AppTheme.panel)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(canCreate ? categoryTone.accentColor : AppTheme.accent)
                        .frame(width: 3)
                        .opacity(canCreate ? 0.95 : 0.34)
                        .padding(.vertical, 9)
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(isHovered ? categoryTone.accentColor.opacity(0.30) : AppTheme.border.opacity(0.70))
        )
        .shadow(color: AppTheme.rowShadow.opacity(isHovered ? 0.72 : 0.42), radius: isHovered ? 10 : 5, x: 0, y: isHovered ? 5 : 2)
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
        .animation(AppMotion.reveal, value: isExpanded)
        .animation(AppMotion.quick, value: hasInput)
    }

    private var captureContextLine: some View {
        HStack(spacing: 6) {
            Label("输入后自动判断主类型", systemImage: "wand.and.sparkles")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.mutedInk)

            if let suggestedFolder, !suggestedFolder.isEmpty {
                Text("· 将归入 \(suggestedFolder)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            } else {
                Text("· 二级目录可在整理时补充")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private func submitIfReady() {
        guard canCreate else { return }
        onCreate()
        withAnimation(AppMotion.capture) {
            isExpanded = false
        }
    }

}

struct HandbookInferenceBadge: View {
    let category: HandbookCategory
    let isLocked: Bool

    var body: some View {
        Label(isLocked ? category.title : "推断：\(category.title)", systemImage: isLocked ? "pin.fill" : category.icon)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(category.accentColor)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(category.softColor, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(category.accentColor.opacity(0.22))
            )
            .help(isLocked ? "当前由左侧分类决定" : "根据输入内容自动判断，后续可在编辑中调整")
    }
}

struct HandbookRow: View {
    let item: HandbookItem
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        let lengthKind = item.lengthKind
        let characterCount = item.bodyCharacterCount

        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(item.category.accentColor)
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: item.category.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(item.category.accentColor)
                        .frame(width: 16)

                    Text(item.category.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(item.category.accentColor)

                    Spacer(minLength: 8)

                    Text(item.updatedAt.formatted(.dateTime.month().day().hour().minute()))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Text(item.displayTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineSpacing(1)
                    .lineLimit(2)

                if let summary = item.cardSummary {
                    Text(summary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineSpacing(2)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 6) {
                    if !item.trimmedFolder.isEmpty {
                        Image(systemName: "folder")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                        Text(item.trimmedFolder)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                            .lineLimit(1)
                    }

                    Text(lengthKind.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(lengthKind.color)

                    if !item.attachments.isEmpty {
                        Image(systemName: "paperclip")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                        Text("\(item.attachments.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                    }

                    Text("\(characterCount) 字")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.mutedInk)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? item.category.accentColor.opacity(0.42) : AppTheme.hairline.opacity(isHovered ? 0.92 : 0.62))
        )
        .shadow(color: AppTheme.rowShadow.opacity(isSelected ? 0.70 : (isHovered ? 0.56 : 0.24)), radius: isSelected ? 8 : (isHovered ? 6 : 2), x: 0, y: isSelected ? 3 : 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
        .animation(AppMotion.hover, value: isHovered)
        .animation(AppMotion.smooth, value: isSelected)
    }

    private var rowBackground: Color {
        if isSelected {
            return item.category.softColor.opacity(0.92)
        }
        if isHovered {
            return AppTheme.panel
        }
        return AppTheme.panel.opacity(0.82)
    }
}

struct HandbookCategoryTag: View {
    let category: HandbookCategory

    var body: some View {
        Label(category.title, systemImage: category.icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(category.accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(category.softColor, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(category.accentColor.opacity(0.22))
            )
    }
}

struct HandbookFolderTag: View {
    let folder: String

    var body: some View {
        Label(folder, systemImage: "folder")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(AppTheme.ink.opacity(0.82))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.68), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.border.opacity(0.82))
            )
    }
}

struct HandbookLengthTag: View {
    let kind: HandbookLengthKind

    var body: some View {
        Label(kind.title, systemImage: kind.icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(kind.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(kind.softColor, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(kind.color.opacity(0.22))
            )
    }
}

struct HandbookAttachmentCountTag: View {
    let count: Int

    var body: some View {
        Label("\(count)", systemImage: "paperclip")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(AppTheme.accentSoft.opacity(0.72), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.accent.opacity(0.20))
            )
    }
}

private extension HandbookCategory {
    static func infer(from text: String) -> HandbookCategory {
        let normalized = text.lowercased()
        let scores: [(category: HandbookCategory, score: Int)] = HandbookCategory.allCases.map { category in
            (category, category.inferenceKeywords.reduce(0) { score, keyword in
                normalized.contains(keyword) ? score + 1 : score
            })
        }
        return scores.max { lhs, rhs in lhs.score < rhs.score }?.score == 0
            ? .businessRule
            : scores.max { lhs, rhs in lhs.score < rhs.score }?.category ?? .businessRule
    }

    private var inferenceKeywords: [String] {
        switch self {
        case .businessRule:
            ["规则", "口径", "流程", "审批", "规范", "要求", "制度", "边界", "权限", "配置", "字段", "规则"]
        case .research:
            ["调研", "竞品", "用户", "访谈", "观察", "数据", "资料", "摘录", "报告", "分析", "样本"]
        case .meeting:
            ["会议", "纪要", "对接", "同步", "讨论", "结论", "行动项", "参会", "复盘", "评审", "会"]
        case .inspiration:
            ["灵感", "想法", "机会", "假设", "创意", "可以", "尝试", "也许", "思路", "idea", "验证"]
        }
    }

    var accentColor: Color {
        switch self {
        case .businessRule:
            Color(red: 0.18, green: 0.48, blue: 0.35)
        case .research:
            Color(red: 0.22, green: 0.40, blue: 0.74)
        case .meeting:
            Color(red: 0.76, green: 0.42, blue: 0.16)
        case .inspiration:
            Color(red: 0.50, green: 0.34, blue: 0.78)
        }
    }

    var softColor: Color {
        switch self {
        case .businessRule:
            Color(red: 0.90, green: 0.96, blue: 0.92)
        case .research:
            Color(red: 0.90, green: 0.94, blue: 1.0)
        case .meeting:
            Color(red: 1.0, green: 0.94, blue: 0.86)
        case .inspiration:
            Color(red: 0.95, green: 0.91, blue: 1.0)
        }
    }
}

private extension HandbookLengthKind {
    var color: Color {
        switch self {
        case .snippet:
            Color(red: 0.36, green: 0.46, blue: 0.58)
        case .medium:
            Color(red: 0.16, green: 0.50, blue: 0.52)
        case .article:
            Color(red: 0.64, green: 0.34, blue: 0.16)
        }
    }

    var softColor: Color {
        switch self {
        case .snippet:
            Color(red: 0.92, green: 0.95, blue: 0.98)
        case .medium:
            Color(red: 0.88, green: 0.96, blue: 0.95)
        case .article:
            Color(red: 0.99, green: 0.92, blue: 0.85)
        }
    }
}

struct HandbookDetailPanel: View {
    let item: HandbookItem?
    let onUpdate: (HandbookItem, HandbookCategory, String, String, String, [HandbookAttachment]) -> Void
    let onDelete: (HandbookItem) -> Void

    @State private var category: HandbookCategory = .businessRule
    @State private var folder = ""
    @State private var title = ""
    @State private var bodyText = ""
    @State private var attachments: [HandbookAttachment] = []
    @State private var outline: [MarkdownOutlineEntry] = []
    @FocusState private var canvasFocus: HandbookCanvasFocus?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let item {
                canvasPanel(for: item)
                    .transition(AppMotion.inlineTransition)
            } else {
                detailPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(item?.category.accentColor.opacity(0.22) ?? AppTheme.hairline)
        )
        .shadow(color: AppTheme.rowShadow.opacity(0.30), radius: 6, x: 0, y: 2)
        .onChange(of: item) { _, newValue in
            syncDraft(with: newValue)
        }
        .onAppear {
            syncDraft(with: item)
        }
    }

    private func canvasPanel(for item: HandbookItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HandbookCanvasToolbar(
                accentColor: category.accentColor,
                isDirty: isDirty(comparedTo: item),
                onDelete: { onDelete(item) },
                onCopyTitle: { copyToPasteboard(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.displayTitle : title) },
                onCopyBody: { copyToPasteboard(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? title : bodyText) },
                onSave: { submitEdit(for: item) }
            )

            Divider()
                .overlay(AppTheme.hairline.opacity(0.56))

            ScrollView {
                HandbookEditableCanvas(
                    category: $category,
                    folder: $folder,
                    title: $title,
                    bodyText: $bodyText,
                    focusedField: $canvasFocus,
                    lengthKind: draftLengthKind,
                    updatedAt: item.updatedAt,
                    attachmentCount: attachments.count
                )
                .padding(.bottom, 16)

                if !outline.isEmpty {
                    HandbookOutlineStrip(entries: outline)
                        .padding(.bottom, 16)
                }

                HandbookAttachmentStrip(attachments: $attachments, isEditing: true)
                    .padding(.top, 8)
                    .onChange(of: attachments) { _, _ in
                        submitEdit(for: item)
                    }
            }
            .onChange(of: category) { _, _ in
                submitEdit(for: item)
            }
            .onChange(of: folder) { _, _ in
                submitEdit(for: item)
            }
            .onChange(of: canvasFocus) { oldValue, newValue in
                if oldValue != nil && newValue == nil {
                    submitEdit(for: item)
                }
            }
            .onChange(of: bodyText) { _, newValue in
                scheduleOutlineUpdate(for: newValue)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 22)
        }
    }

    private var detailPlaceholder: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: "book.closed")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 38, height: 38)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("选择一条手记阅读")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            Text("左侧列表用于扫描，右侧用于完整阅读和编辑。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(18)
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitEdit(for item: HandbookItem) {
        guard canSubmit else { return }
        onUpdate(item, category, folder, title, bodyText, attachments)
    }

    private func syncDraft(with item: HandbookItem?) {
        guard let item else { return }
        category = item.category
        folder = item.folder
        title = item.title
        bodyText = item.body
        attachments = item.attachments
        outline = []
        scheduleOutlineUpdate(for: item.body)
    }

    private func scheduleOutlineUpdate(for text: String) {
        let snapshot = text
        DispatchQueue.main.async {
            guard snapshot == bodyText else { return }
            outline = MarkdownOutlineEntry.extract(from: snapshot.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private var draftLengthKind: HandbookLengthKind {
        HandbookItem(category: category, folder: folder, title: title, body: bodyText).lengthKind
    }

    private func isDirty(comparedTo item: HandbookItem) -> Bool {
        category != item.category
            || folder.trimmingCharacters(in: .whitespacesAndNewlines) != item.trimmedFolder
            || title.trimmingCharacters(in: .whitespacesAndNewlines) != item.trimmedTitle
            || bodyText.trimmingCharacters(in: .whitespacesAndNewlines) != item.trimmedBody
            || attachments != item.attachments
    }
}

enum HandbookCanvasFocus: Hashable {
    case title
    case body
}

struct HandbookCanvasToolbar: View {
    let accentColor: Color
    let isDirty: Bool
    let onDelete: () -> Void
    let onCopyTitle: () -> Void
    let onCopyBody: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
                    .font(.system(size: 12, weight: .bold))
                    .frame(height: 30)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.tactilePlain)
            .foregroundStyle(TodoPriority.high.displayColor)
            .interactionHitArea()
            .help("删除手记")

            Text("直接编辑，离开输入框或点击保存后写入")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(-1)

            Spacer(minLength: 0)

            Label(isDirty ? "未保存" : "已保存", systemImage: isDirty ? "circle.dotted" : "checkmark.circle")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isDirty ? AppTheme.accentWarm : AppTheme.mutedInk)
                .lineLimit(1)

            Menu {
                Button(action: onCopyTitle) {
                    Label("复制标题", systemImage: "doc.on.doc")
                }

                Button(action: onCopyBody) {
                    Label("复制正文", systemImage: "text.page")
                }
            } label: {
                Label("复制", systemImage: "doc.on.doc")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 62, height: 30)
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.tactilePlain)
            .foregroundStyle(AppTheme.mutedInk)
            .help("复制标题或正文")

            Button(action: onSave) {
                Label("保存", systemImage: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 64, height: 30)
            }
            .buttonStyle(.tactilePlain)
            .foregroundStyle(.white)
            .background(isDirty ? accentColor : Color.black.opacity(0.28), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isDirty ? Color.white.opacity(0.34) : Color.black.opacity(0.05))
            )
            .disabled(!isDirty)
            .interactionHitArea()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(AppTheme.panel.opacity(0.96))
    }
}

struct HandbookEditableCanvas: View {
    @Binding var category: HandbookCategory
    @Binding var folder: String
    @Binding var title: String
    @Binding var bodyText: String
    var focusedField: FocusState<HandbookCanvasFocus?>.Binding
    let lengthKind: HandbookLengthKind
    let updatedAt: Date
    let attachmentCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("手记标题", text: $title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1...3)
                .focused(focusedField, equals: .title)

            HandbookDetailMetaBar(
                category: $category,
                folder: $folder,
                lengthKind: lengthKind,
                characterCount: bodyText.trimmingCharacters(in: .whitespacesAndNewlines).count,
                updatedAt: updatedAt,
                attachmentCount: attachmentCount
            )

            ZStack(alignment: .topLeading) {
                TextEditor(text: $bodyText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(AppTheme.ink)
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, -4)
                    .frame(minHeight: max(360, editorHeight), maxHeight: max(360, editorHeight))
                    .focused(focusedField, equals: .body)

                if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("从这里开始写手记，支持 Markdown。")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.mutedInk)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editorHeight: CGFloat {
        let estimatedLines = bodyText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { partialResult, line in
                partialResult + max(1, (line.count + 58) / 59)
            }
        return CGFloat(max(12, estimatedLines)) * 24 + 32
    }
}

struct HandbookDetailMetaBar: View {
    @Binding var category: HandbookCategory
    @Binding var folder: String
    let lengthKind: HandbookLengthKind
    let characterCount: Int
    let updatedAt: Date
    let attachmentCount: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                editableTags
                HandbookMetaDot()
                passiveMeta
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 7) {
                editableTags
                passiveMeta
            }
        }
    }

    private var editableTags: some View {
        HStack(spacing: 7) {
            HandbookCategoryInlineTag(category: $category)
            HandbookFolderInlineTag(folder: $folder)
        }
    }

    private var passiveMeta: some View {
        HStack(spacing: 8) {
            HandbookMetaText(icon: lengthKind.icon, text: lengthKind.title)
            HandbookMetaDot()
            HandbookMetaText(icon: "character.cursor.ibeam", text: "\(characterCount) 字")
            HandbookMetaDot()
            HandbookMetaText(icon: "calendar", text: updatedAt.formatted(.dateTime.year().month().day().hour().minute()))
            if attachmentCount > 0 {
                HandbookMetaDot()
                HandbookMetaText(icon: "paperclip", text: "\(attachmentCount) 个附件")
            }
        }
    }
}

struct HandbookCategoryInlineTag: View {
    @Binding var category: HandbookCategory

    var body: some View {
        Menu {
            Picker("分类", selection: $category) {
                ForEach(HandbookCategory.allCases) { option in
                    Label(option.title, systemImage: option.icon).tag(option)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .bold))

                Text(category.title)
                    .font(.system(size: 12, weight: .bold))

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(category.accentColor.opacity(0.72))
            }
            .foregroundStyle(category.accentColor)
            .padding(.horizontal, 9)
            .frame(height: 25)
            .background(category.softColor, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(category.accentColor.opacity(0.24))
            )
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .fixedSize()
        .help("点击修改分类")
    }
}

struct HandbookFolderInlineTag: View {
    @Binding var folder: String

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isDraftFocused: Bool

    var body: some View {
        Button {
            draft = trimmedFolder
            withAnimation(AppMotion.quick) {
                isEditing = true
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: trimmedFolder.isEmpty ? "folder.badge.plus" : "folder")
                    .font(.system(size: 11, weight: .bold))

                Text(trimmedFolder.isEmpty ? "未归档" : trimmedFolder)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .frame(maxWidth: 160, alignment: .leading)

                Image(systemName: "pencil")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(AppTheme.mutedInk.opacity(0.78))
            }
            .foregroundStyle(trimmedFolder.isEmpty ? AppTheme.mutedInk : AppTheme.ink.opacity(0.84))
            .padding(.horizontal, 9)
            .frame(height: 25)
            .background(Color.white.opacity(0.70), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.border.opacity(trimmedFolder.isEmpty ? 0.62 : 0.90))
            )
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .help("点击修改二级目录")
        .popover(isPresented: $isEditing, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("二级目录")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                TextField("例如：审批流", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.border)
                    )
                    .focused($isDraftFocused)
                    .onSubmit(commit)

                HStack(spacing: 8) {
                    Button("清空") {
                        draft = ""
                        commit()
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(AppTheme.mutedInk)

                    Spacer(minLength: 0)

                    Button("取消") {
                        isEditing = false
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(AppTheme.mutedInk)

                    Button("完成") {
                        commit()
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .background(AppTheme.accent, in: Capsule())
                }
                .font(.system(size: 12, weight: .bold))
            }
            .padding(12)
            .frame(width: 256)
            .background(AppTheme.panel.opacity(0.98))
            .onAppear {
                draft = trimmedFolder
                isDraftFocused = true
            }
        }
    }

    private var trimmedFolder: String {
        folder.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commit() {
        folder = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(AppMotion.quick) {
            isEditing = false
        }
    }
}

struct HandbookMetaText: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(AppTheme.mutedInk)
            .lineLimit(1)
    }
}

struct HandbookMetaDot: View {
    var body: some View {
        Circle()
            .fill(AppTheme.hairline)
            .frame(width: 4, height: 4)
    }
}

struct MarkdownOutlineEntry: Identifiable, Equatable {
    let id = UUID()
    let level: Int
    let title: String

    static func extract(from text: String) -> [MarkdownOutlineEntry] {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> MarkdownOutlineEntry? in
                let rawLine = String(line).trimmingCharacters(in: .whitespaces)
                guard rawLine.hasPrefix("#") else { return nil }
                let level = rawLine.prefix(while: { $0 == "#" }).count
                guard (1...3).contains(level) else { return nil }
                let title = rawLine
                    .dropFirst(level)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                return MarkdownOutlineEntry(level: level, title: title)
            }
    }
}

struct HandbookOutlineStrip: View {
    let entries: [MarkdownOutlineEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("结构", systemImage: "list.bullet.indent")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(entries.prefix(8)) { entry in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(AppTheme.accent.opacity(entry.level == 1 ? 0.88 : 0.48))
                            .frame(width: entry.level == 1 ? 6 : 4, height: entry.level == 1 ? 6 : 4)

                        Text(entry.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.mutedInk)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(Color.white.opacity(0.62), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.hairline.opacity(0.52))
                    )
                }
            }
        }
        .padding(10)
        .background(AppTheme.workSurface.opacity(0.56), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.62))
        )
    }
}

struct HandbookBodyEditor: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat

    init(_ placeholder: String, text: Binding<String>, minHeight: CGFloat, maxHeight: CGFloat) {
        self.placeholder = placeholder
        _text = text
        self.minHeight = minHeight
        self.maxHeight = maxHeight
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 13, weight: .medium))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(minHeight: editorHeight, maxHeight: editorHeight)

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.mutedInk)
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
            return minHeight
        }

        let estimatedLines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { partialResult, line in
                partialResult + max(1, (line.count + 58) / 59)
            }
        return min(maxHeight, max(minHeight, CGFloat(estimatedLines) * 20 + 28))
    }
}

struct HandbookFolderEditor: View {
    @Binding var folder: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "folder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 14)

            TextField("二级目录", text: $folder)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 9)
        .frame(height: 31)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border)
        )
    }
}

struct MarkdownHandbookEditor: View {
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat

    @State private var showsPreview = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                MarkdownToolbarButton(title: "H2", help: "二级标题") {
                    apply(prefix: "## ")
                }
                MarkdownToolbarButton(title: "B", help: "加粗") {
                    wrap(prefix: "**", suffix: "**", sample: "重点")
                }
                MarkdownToolbarButton(systemImage: "list.bullet", help: "列表") {
                    apply(prefix: "- ")
                }
                MarkdownToolbarButton(systemImage: "quote.opening", help: "引用") {
                    apply(prefix: "> ")
                }
                MarkdownToolbarButton(systemImage: "curlybraces", help: "代码块") {
                    wrap(prefix: "```\n", suffix: "\n```", sample: "code")
                }
                MarkdownToolbarButton(systemImage: "link", help: "链接") {
                    appendSnippet("[标题](https://)")
                }

                Spacer()

                Button {
                    withAnimation(AppMotion.reveal) {
                        showsPreview.toggle()
                    }
                } label: {
                    Label(showsPreview ? "编辑" : "预览", systemImage: showsPreview ? "pencil" : "eye")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 66, height: 28)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.accent)
                .background(AppTheme.accentSoft.opacity(0.64), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.accent.opacity(0.18))
                )
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.72))

            Divider()
                .overlay(AppTheme.hairline.opacity(0.62))

            if showsPreview {
                ScrollView {
                    MarkdownPreview(text: text.isEmpty ? "在左侧编辑 Markdown 后，这里预览正文。" : text)
                        .padding(12)
                }
                .frame(minHeight: editorHeight, maxHeight: editorHeight)
                .transition(AppMotion.inlineTransition)
            } else {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .frame(minHeight: editorHeight, maxHeight: editorHeight)

                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("支持 Markdown：## 标题、- 列表、> 引用、**重点**、链接和代码块")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.mutedInk)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 13)
                            .allowsHitTesting(false)
                    }
                }
                .transition(AppMotion.inlineTransition)
            }
        }
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(AppTheme.border)
        )
        .animation(AppMotion.reveal, value: showsPreview)
    }

    private var editorHeight: CGFloat {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return minHeight
        }

        let estimatedLines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { partialResult, line in
                partialResult + max(1, (line.count + 54) / 55)
            }
        return min(maxHeight, max(minHeight, CGFloat(estimatedLines) * 20 + 44))
    }

    private func apply(prefix: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            text = prefix
        } else {
            text += "\n\(prefix)"
        }
    }

    private func wrap(prefix: String, suffix: String, sample: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let snippet = "\(prefix)\(sample)\(suffix)"
        text = trimmed.isEmpty ? snippet : "\(text)\n\(snippet)"
    }

    private func appendSnippet(_ snippet: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = trimmed.isEmpty ? snippet : "\(text)\n\(snippet)"
    }
}

struct MarkdownToolbarButton: View {
    var title: String?
    var systemImage: String?
    let help: String
    let action: () -> Void

    init(title: String, help: String, action: @escaping () -> Void) {
        self.title = title
        self.help = help
        self.action = action
    }

    init(systemImage: String, help: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let title {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .frame(width: 28, height: 26)
        }
        .buttonStyle(.tactilePlain)
        .foregroundStyle(AppTheme.ink.opacity(0.84))
        .help(help)
    }
}

struct MarkdownPreview: View {
    let text: String

    var body: some View {
        Text(markdown)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(AppTheme.ink)
            .lineSpacing(5)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var markdown: AttributedString {
        (try? AttributedString(markdown: text))
            ?? AttributedString(text)
    }
}

struct HandbookAttachmentStrip: View {
    @Binding var attachments: [HandbookAttachment]
    let isEditing: Bool

    init(attachments: Binding<[HandbookAttachment]>, isEditing: Bool) {
        _attachments = attachments
        self.isEditing = isEditing
    }

    init(attachments: [HandbookAttachment], isEditing: Bool) {
        _attachments = .constant(attachments)
        self.isEditing = isEditing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Label("附件", systemImage: "paperclip")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                if !attachments.isEmpty {
                    Text("\(attachments.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(AppTheme.accentSoft, in: Capsule())
                }

                Spacer()

                if isEditing {
                    Button {
                        addAttachments()
                    } label: {
                        Label("添加", systemImage: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 62, height: 28)
                    }
                    .buttonStyle(.tactilePlain)
                    .foregroundStyle(AppTheme.accent)
                    .background(AppTheme.accentSoft.opacity(0.62), in: Capsule())
                }
            }

            if attachments.isEmpty {
                if isEditing {
                    Text("可添加文件、图片或视频；当前仅记录本地路径，便于后续工程化扩展。")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 7)], alignment: .leading, spacing: 7) {
                    ForEach(attachments) { attachment in
                        HandbookAttachmentChip(
                            attachment: attachment,
                            isEditing: isEditing,
                            onOpen: { open(attachment) },
                            onDelete: { remove(attachment) }
                        )
                    }
                }
            }
        }
        .padding(10)
        .background(AppTheme.workSurface.opacity(0.56), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.70))
        )
    }

    private func addAttachments() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.item]
        panel.prompt = "添加"

        guard panel.runModal() == .OK else { return }

        let newAttachments = panel.urls.map { url in
            HandbookAttachment(
                kind: HandbookAttachmentKind(fileURL: url),
                name: url.lastPathComponent,
                path: url.path
            )
        }
        attachments.append(contentsOf: newAttachments)
    }

    private func open(_ attachment: HandbookAttachment) {
        let url = URL(fileURLWithPath: attachment.path)
        NSWorkspace.shared.open(url)
    }

    private func remove(_ attachment: HandbookAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }
}

struct HandbookAttachmentChip: View {
    let attachment: HandbookAttachment
    let isEditing: Bool
    let onOpen: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.kind.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(attachment.kind.color)
                .frame(width: 24, height: 24)
                .background(attachment.kind.softColor, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text(attachment.kind.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer(minLength: 0)

            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .help("移除附件")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.white.opacity(isHovered ? 0.92 : 0.74), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border.opacity(isHovered ? 0.96 : 0.66))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
    }
}

private extension HandbookAttachmentKind {
    init(fileURL url: URL) {
        let pathExtension = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp"].contains(pathExtension) {
            self = .image
        } else if ["mov", "mp4", "m4v", "avi", "mkv", "webm"].contains(pathExtension) {
            self = .video
        } else {
            self = .file
        }
    }

    var color: Color {
        switch self {
        case .file:
            Color(red: 0.30, green: 0.40, blue: 0.54)
        case .image:
            Color(red: 0.18, green: 0.52, blue: 0.38)
        case .video:
            Color(red: 0.62, green: 0.30, blue: 0.68)
        }
    }

    var softColor: Color {
        switch self {
        case .file:
            Color(red: 0.91, green: 0.94, blue: 0.98)
        case .image:
            Color(red: 0.88, green: 0.96, blue: 0.91)
        case .video:
            Color(red: 0.96, green: 0.90, blue: 0.98)
        }
    }
}

struct HandbookEmptyState: View {
    let category: HandbookCategory?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: category?.icon ?? "book.closed")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 54, height: 54)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(category == nil ? "还没有手记" : "还没有\(category?.title ?? "")")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            Text("在上方输入标题和内容，沉淀可复用的信息。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 62)
    }
}

struct HandbookFilteredEmptyState: View {
    let filter: HandbookListFilter

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: filter.icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 52, height: 52)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 17, style: .continuous))

            Text(filter.emptyText)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            Text("切回全部，或在上方继续收集新的手记。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 62)
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
    let trace: AITrace?
    let step: String?
    let isLoading: Bool
    let onGenerate: () -> Void

    @State private var showsTrace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
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

            if let step {
                HStack(spacing: 6) {
                    Image(systemName: isLoading ? "arrow.triangle.2.circlepath" : (error == nil ? "checkmark.circle" : "exclamationmark.triangle"))
                        .font(.system(size: 10, weight: .bold))
                    Text(step)
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    if let trace {
                        Text("\(trace.model) · \(trace.durationText)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .foregroundStyle(error == nil ? AppTheme.mutedInk : TodoPriority.high.displayColor)
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在读取当前待办并生成推进顺序")
                        .font(.system(size: 12, weight: .semibold))
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
                    .transition(AppMotion.inlineTransition)
            } else {
                Text("用当前未完成事项生成今天的推进顺序。")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            if let trace {
                AITraceDisclosure(trace: trace, isExpanded: $showsTrace)
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
        .animation(AppMotion.reveal, value: showsTrace)
    }
}

struct AITraceCompactView: View {
    let trace: AITrace

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 10, weight: .bold))
            Text("AI 已调用")
                .font(.system(size: 11, weight: .semibold))
            Text("\(trace.model) · \(trace.durationText) · 输入 \(trace.inputCharacters) 字 / 输出 \(trace.outputCharacters) 字")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppTheme.accent)
    }
}

struct AITraceDisclosure: View {
    let trace: AITrace
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                withAnimation(AppMotion.reveal) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("查看 AI 调用详情")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("\(trace.statusCode) · \(trace.startedAtText)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
                .foregroundStyle(AppTheme.accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.tactilePlain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 5) {
                    AITraceLine(label: "场景", value: trace.scenario)
                    AITraceLine(label: "模型", value: trace.model)
                    AITraceLine(label: "接口", value: trace.endpoint)
                    AITraceLine(label: "耗时", value: trace.durationText)
                    AITraceLine(label: "规模", value: "输入 \(trace.inputCharacters) 字，输出 \(trace.outputCharacters) 字")
                    AITraceLine(label: "返回", value: trace.responsePreview.isEmpty ? "空返回" : trace.responsePreview)
                }
                .padding(9)
                .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.hairline)
                )
                .transition(AppMotion.inlineTransition)
            }
        }
    }
}

struct AITraceLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 30, alignment: .leading)
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
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
                    .font(.system(size: 11, weight: .medium))
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
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
            Text(date.formatted(.dateTime.year().month().day().weekday(.wide)))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.mutedInk)
            Spacer()
            Text("\(count) 项")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(.horizontal, 8)
        .padding(.top, 9)
        .padding(.bottom, 1)
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
    let aiTrace: AITrace?
    let aiResultSummary: String?
    let isAIEnabled: Bool
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 9 : 5) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.accent.opacity(0.16),
                                    AppTheme.accentWarm.opacity(0.13)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(AppTheme.accent.opacity(0.16), lineWidth: 1)
                        )
                    Image(systemName: "command")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(width: 28, height: 28)

                TextField("快速记录：要推进什么？", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .focused(focusedField, equals: .newTitle)
                    .submitLabel(.done)
                    .onSubmit(submitQuickRecord)
                    .disabled(isCreating)
                    .onTapGesture {
                        withAnimation(AppMotion.reveal) {
                            isExpanded = true
                        }
                    }
                    .frame(minWidth: 190, maxWidth: .infinity, alignment: .leading)

                Button {
                    guard !isCreating else { return }
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
                .disabled(isCreating)

                Button(action: onCreate) {
                    Label(isCreating ? "解析" : "记录", systemImage: isCreating ? "sparkles" : "arrow.down.to.line.compact")
                        .font(.caption.weight(.semibold))
                        .frame(width: 70, height: 30)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(.white)
                .background(canCreate && !isCreating ? AppTheme.accentWarm : Color.black.opacity(0.28), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(canCreate && !isCreating ? Color.white.opacity(0.52) : Color.black.opacity(0.05))
                )
                .shadow(color: canCreate && !isCreating ? AppTheme.accentWarm.opacity(0.20) : .clear, radius: 10, x: 0, y: 6)
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
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isCreating else { return }
                withAnimation(AppMotion.reveal) {
                    isExpanded = true
                }
                focusedField.wrappedValue = .newTitle
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
                .transition(AppMotion.inlineTransition)
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
                .transition(AppMotion.inlineTransition)
            } else if isAIEnabled && hasDraft {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("提交时使用 AI 解析")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.leading, 32)
                .transition(AppMotion.inlineTransition)
            }

            if let aiTrace {
                VStack(alignment: .leading, spacing: 4) {
                    if let aiResultSummary {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 10, weight: .bold))
                            Text(aiResultSummary)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(AppTheme.accent)
                    }
                    AITraceCompactView(trace: aiTrace)
                }
                .padding(.leading, 32)
                .transition(AppMotion.inlineTransition)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        PriorityPicker(priority: $priority)
                            .frame(width: 78, alignment: .leading)
                            .disabled(isCreating)

                        ProgressPicker(progress: $progress)
                            .frame(width: 104, alignment: .leading)
                            .disabled(isCreating)

                        DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .frame(width: 150, alignment: .leading)
                            .disabled(isCreating)

                        Toggle(isOn: $isWeekly) {
                            Label("每周固定", systemImage: "repeat")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.mutedInk)
                        }
                        .toggleStyle(.checkbox)
                        .help("完成后自动生成下周同一天")
                        .disabled(isCreating)

                        Spacer(minLength: 0)
                    }

                    CompactNotesField(text: $notes, onSubmit: submitQuickRecord)
                        .frame(maxWidth: .infinity)
                        .disabled(isCreating)
                }
                .padding(.leading, 32)
                .transition(AppMotion.inlineTransition)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.panel)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(canCreate ? AppTheme.accentWarm : AppTheme.accent)
                        .frame(width: 3)
                        .opacity(canCreate || isExpanded ? 0.95 : 0.34)
                        .padding(.vertical, 10)
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isExpanded || isHovered ? AppTheme.accent.opacity(0.24) : AppTheme.border.opacity(0.86))
        )
        .shadow(color: AppTheme.rowShadow, radius: hasDraft || isHovered ? 14 : 8, x: 0, y: hasDraft || isHovered ? 7 : 4)
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
        .animation(AppMotion.reveal, value: isExpanded)
        .animation(AppMotion.capture, value: hasDraft)
        .animation(AppMotion.capture, value: isCreating)
        .animation(AppMotion.capture, value: aiStatusMessage)
        .animation(AppMotion.capture, value: aiTrace)
        .animation(AppMotion.hover, value: isHovered)
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
                        .background(canSubmit ? AppTheme.accent : Color.black.opacity(0.28), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(canSubmit ? Color.white.opacity(0.34) : Color.black.opacity(0.05))
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
        .background(AppTheme.rowTint(priority: priority, isOverdue: isOverdue), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
    @State private var isHovered = false

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
                .transition(AppMotion.inlineTransition)

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
                .transition(AppMotion.inlineTransition)
            }
        } else {
            HStack(alignment: hasNotes ? .top : .center, spacing: 8) {
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .fill(todo.isDone ? TodoProgress.done.displayColor.opacity(0.17) : Color.white.opacity(isHovered ? 0.96 : 0.70))
                            .overlay(
                                Circle()
                                    .stroke(todo.isDone ? TodoProgress.done.displayColor.opacity(0.32) : AppTheme.hairline, lineWidth: 1)
                            )
                            .frame(width: 24, height: 24)
                        Image(systemName: todo.isDone ? "checkmark" : "circle")
                            .font(.system(size: todo.isDone ? 11 : 11, weight: .bold))
                    }
                    .frame(width: 38, height: 34)
                    .contentShape(Rectangle())
                }
                .help(todo.isDone ? "标记为待处理" : "标记为完成")
                .buttonStyle(.tactilePlain)
                .foregroundStyle(todo.isDone ? TodoProgress.done.displayColor : AppTheme.mutedInk)
                .padding(.top, hasNotes ? 1 : 0)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        PriorityOutlineTag(priority: todo.priority, isCompact: true)
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
                            .font(.system(size: 12, weight: .medium))
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
                        .minimumScaleFactor(0.82)
                        .frame(width: 88, alignment: .leading)

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
            .padding(.horizontal, 8)
            .padding(.vertical, hasNotes ? 7 : 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(rowBackground)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(sideRailColor)
                            .frame(width: 2.5)
                            .opacity(sideRailOpacity)
                            .padding(.vertical, 8)
                    }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(rowStroke)
            )
            .shadow(color: (isOverdue || isHovered) ? AppTheme.rowShadow : .clear, radius: (isOverdue || isHovered) ? 7 : 0, x: 0, y: (isOverdue || isHovered) ? 3 : 0)
            .opacity(todo.isDone ? 0.72 : 1)
            .onHover { hovered in
                withAnimation(AppMotion.hover) {
                    isHovered = hovered
                }
            }
            .animation(AppMotion.status, value: todo.progress)
            .animation(AppMotion.complete, value: todo.isDone)
            .animation(AppMotion.hover, value: isHovered)
            .transition(AppMotion.inlineTransition)
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
        if isOverdue {
            return AppTheme.rowTint(priority: todo.priority, isOverdue: true)
        }
        if isHovered {
            return AppTheme.panel.opacity(todo.isDone ? 0.82 : 1)
        }
        return AppTheme.panel.opacity(todo.isDone ? 0.74 : 0.94)
    }

    private var rowStroke: Color {
        if isOverdue {
            return TodoPriority.high.displayColor.opacity(0.22)
        }
        if isHovered {
            return AppTheme.accent.opacity(0.18)
        }
        return AppTheme.hairline.opacity(todo.isDone ? 0.55 : 0.82)
    }

    private var sideRailColor: Color {
        if isOverdue {
            return TodoPriority.high.displayColor
        }
        return todo.priority.displayColor
    }

    private var sideRailOpacity: Double {
        if todo.isDone {
            return 0.18
        }
        if isOverdue || isHovered {
            return 0.82
        }
        return todo.priority == .high ? 0.46 : 0.0
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
                .background(canSubmit ? AppTheme.accent : Color.black.opacity(0.28), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(canSubmit ? Color.white.opacity(0.34) : Color.black.opacity(0.05))
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
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.accentSoft.opacity(0.95),
                                AppTheme.accentWarm.opacity(0.11)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.accent.opacity(0.16), lineWidth: 1)
                    )
                Image(systemName: "leaf.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .rotationEffect(.degrees(-18))
                    .offset(x: -3, y: -2)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(AppTheme.accentWarm)
                    .offset(x: 13, y: 12)
            }
            .frame(width: 54, height: 54)

            Text(isAllScope ? "还没有任何待办" : "这一天还没有待办")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            Text("顶部快记可直接写下一条推进。")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
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
                .font(.system(size: 13, weight: .medium))
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
    var isCompact = false

    var body: some View {
        Text(priority.label)
            .font(.system(size: isCompact ? 10 : 11, weight: .bold))
            .foregroundStyle(priorityColor)
            .frame(minWidth: isCompact ? 22 : 0)
            .padding(.horizontal, isCompact ? 4 : 6)
            .padding(.vertical, isCompact ? 1 : 2)
            .background(priorityColor.opacity(isCompact ? 0.08 : 0.12), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(priorityColor.opacity(isCompact ? 0.82 : 0.62), lineWidth: 1)
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
            HStack(spacing: 3) {
                Text(progress.shortLabel)
                    .font(.system(size: 11, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .imageScale(.small)
            }
            .foregroundStyle(progress.displayColor)
            .frame(minWidth: 58, minHeight: 28)
            .background(progress.displayColor.opacity(0.08), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(progress.displayColor.opacity(0.18), lineWidth: 1)
            )
            .contentShape(Capsule())
            .interactionHitArea()
        }
        .menuIndicator(.hidden)
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
    @State private var summaryTrace: AITrace?
    @State private var showsSummaryTrace = false
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
                    .font(.system(size: 13, weight: .medium))
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
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .transition(AppMotion.inlineTransition)
                }

                if let summaryError {
                    Text("摘要失败：\(summaryError)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TodoPriority.high.displayColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let summaryTrace {
                    AITraceDisclosure(trace: summaryTrace, isExpanded: $showsSummaryTrace)
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
        summaryTrace = nil
        let configuration = aiSettings.configuration
        let apiKey = aiSettings.apiKey
        let sourceTitle = title
        let sourceNotes = displayText
        Task {
            do {
                let result = try await AIClient.shared.summarizeNotes(
                    title: sourceTitle,
                    notes: sourceNotes,
                    configuration: configuration,
                    apiKey: apiKey
                )
                await MainActor.run {
                    summary = result.content
                    summaryTrace = result.trace
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
                .font(.system(size: 13, weight: .medium))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(minHeight: editorHeight, maxHeight: editorHeight)

            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.mutedInk)
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
