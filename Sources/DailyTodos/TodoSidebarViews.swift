import SwiftUI

struct TodoSidebarView: View {
    @EnvironmentObject private var store: TodoStore
    @Binding var scope: TodoScope
    @Binding var isCollapsed: Bool
    @State private var calendarMonth = Date()
    @State private var metrics = TodoSidebarMetrics.empty

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader

            Divider()
                .overlay(AppTheme.hairline)

            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    navigationGroup
                    quickDateGroup
                    miniCalendarGroup
                }
                .padding(.horizontal, 17)
                .padding(.top, 14)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppTheme.workspaceTokens.contextSidebar)
        .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
        .onAppear {
            if let selectedDate {
                calendarMonth = selectedDate
            }
            rebuildMetrics()
        }
        .onChange(of: selectedDate) { _, newValue in
            if let newValue {
                calendarMonth = newValue
            }
        }
        .onChange(of: store.todos) { _, _ in
            rebuildMetrics()
        }
    }

    private var sidebarHeader: some View {
        WorkspaceContextHeader(
            title: "待办",
            subtitle: "推进、反馈、固定、全部",
            isCollapsed: $isCollapsed
        )
    }

    private var navigationGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            DateButton(
                title: "今日推进",
                subtitle: "风险优先，推进今天",
                systemImage: "scope",
                count: metrics.dashboardCount,
                alertCount: metrics.overdueCount,
                isSelected: scope == .dashboard
            ) {
                scope = .dashboard
            }

            DateButton(
                title: "未完成",
                subtitle: "所有尚未关闭的事项",
                systemImage: "circle.dashed",
                count: metrics.activeCount,
                alertCount: metrics.overdueCount,
                isSelected: scope == .unfinished
            ) {
                scope = .unfinished
            }

            DateButton(
                title: "等待反馈",
                subtitle: "需要别人推进",
                systemImage: "hourglass",
                count: metrics.waitingCount,
                isSelected: scope == .waiting
            ) {
                scope = .waiting
            }

            DateButton(
                title: "本周固定",
                subtitle: "重复管理动作",
                systemImage: "repeat.circle",
                count: metrics.weeklyCount,
                isSelected: scope == .weekly
            ) {
                scope = .weekly
            }

            DateButton(
                title: "已完成",
                subtitle: "已经关闭的事项",
                systemImage: "checkmark.circle.fill",
                count: metrics.completedCount,
                isSelected: scope == .completed
            ) {
                scope = .completed
            }

            DateButton(
                title: "全部待办",
                subtitle: "完整任务池",
                systemImage: "tray.full.fill",
                count: metrics.activeCount,
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
                pendingCount: { metrics.pendingCount(on: $0, calendar: calendar) },
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
            datesWithTodos: metrics.datesWithTodos,
            selectedDate: selectedDate,
            todoCount: { metrics.todoCount(on: $0, calendar: calendar) },
            pendingCount: { metrics.pendingCount(on: $0, calendar: calendar) },
            onSelect: { date in
                calendarMonth = date
                scope = .day(date)
            }
        )
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

    private func rebuildMetrics() {
        metrics = PerformanceMonitor.measure("TodoSidebar.metrics") {
            TodoSidebarMetrics(todos: store.todos, calendar: calendar, now: Date())
        }
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
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.workspaceTokens.selectedContent : AppTheme.workspaceTokens.textSecondary)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.workspaceTokens.selectedContent : AppTheme.workspaceTokens.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppTheme.workspaceTokens.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if count > 0 || alertCount > 0 {
                    Text(countText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(countForeground)
                        .frame(minWidth: 24, minHeight: 20)
                        .background(countBackground, in: Capsule())
                        .help(countHelp)
                }
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .contentShape(Rectangle())
            .background(navBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
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
            return AppTheme.workspaceTokens.accentSoft
        }
        if isHovered {
            return AppTheme.workspaceTokens.listRowHover
        }
        return Color.clear
    }

    private var countText: String {
        if alertCount > 0 {
            return "\(alertCount)"
        }
        return "\(count)"
    }

    private var countForeground: Color {
        if isSelected {
            return AppTheme.workspaceTokens.selectedContent
        }
        return alertCount > 0
            ? AppTheme.workspaceTokens.danger
            : AppTheme.workspaceTokens.textSecondary
    }

    private var countBackground: Color {
        if isSelected {
            return AppTheme.workspaceTokens.selectedContent.opacity(0.08)
        }
        return countForeground.opacity(0.10)
    }

    private var countHelp: String {
        alertCount > 0 ? "逾期未完成" : "未完成事项"
    }
}
