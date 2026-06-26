import SwiftUI

struct TodoSidebarView: View {
    @EnvironmentObject private var store: TodoStore
    @Binding var scope: TodoScope
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("待办")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text("今日、等待、固定、全部")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if metrics.overdueCount > 0 {
                Text("\(metrics.overdueCount)")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(minWidth: 22, minHeight: 20)
                    .background(TodoPriority.high.displayColor, in: Capsule())
                    .help("逾期未完成")
            } else {
                Text("\(metrics.activeCount)")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.accent)
                    .frame(minWidth: 22, minHeight: 20)
                    .background(AppTheme.accentSoft, in: Capsule())
                    .help("未完成事项")
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .frame(height: 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var navigationGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            DateButton(
                title: "今日推进",
                subtitle: "风险优先，推进今天",
                systemImage: "target",
                count: metrics.dashboardCount,
                alertCount: metrics.overdueCount,
                isSelected: scope == .dashboard
            ) {
                scope = .dashboard
            }

            DateButton(
                title: "等待反馈",
                subtitle: "需要别人推进",
                systemImage: "person.2.fill",
                count: metrics.waitingCount,
                isSelected: scope == .waiting
            ) {
                scope = .waiting
            }

            DateButton(
                title: "本周固定",
                subtitle: "重复管理动作",
                systemImage: "repeat",
                count: metrics.weeklyCount,
                isSelected: scope == .weekly
            ) {
                scope = .weekly
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

    private var sidebarSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("待办")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Text("未完成 \(metrics.activeCount) · 逾期 \(metrics.overdueCount)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 13)
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
