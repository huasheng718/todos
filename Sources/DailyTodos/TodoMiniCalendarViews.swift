import SwiftUI

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
            }

            calendarNavigation

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.workspaceTokens.textSecondary)
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
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    private var calendarNavigation: some View {
        HStack(spacing: 4) {
            calendarStepButton(systemImage: "chevron.left", help: "上个月") {
                shiftMonth(-1)
            }

            Menu {
                Section("月份") {
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
                }

                Section("年份") {
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
                }
            } label: {
                dropdownLabel(
                    title: "\(yearTitle) \(monthTitle)",
                    font: .system(size: 12, weight: .semibold)
                )
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.plain)
            .help("选择年月")

            calendarStepButton(systemImage: "chevron.right", help: "下个月") {
                shiftMonth(1)
            }
        }
        .foregroundStyle(AppTheme.workspaceTokens.textSecondary)
    }

    private func dropdownLabel(title: String, font: Font) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(font)
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .monospacedDigit()

            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .contentShape(Rectangle())
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
        var days: [MiniCalendarDay] = []
        for index in 0..<leadingBlanks {
            days.append(MiniCalendarDay(id: "blank-leading-\(index)", date: nil, isInCurrentMonth: false))
        }

        for day in monthRange {
            var components = calendar.dateComponents([.year, .month], from: visibleMonth)
            components.day = day
            days.append(MiniCalendarDay(id: "day-\(day)", date: calendar.date(from: components), isInCurrentMonth: true))
        }

        var trailingIndex = 0
        while days.count % 7 != 0 {
            days.append(MiniCalendarDay(id: "blank-trailing-\(trailingIndex)", date: nil, isInCurrentMonth: false))
            trailingIndex += 1
        }
        return days
    }
}

struct MiniCalendarDay: Identifiable {
    let id: String
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

    @State private var isHovered = false

    private let calendar = Calendar.current

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
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
        .onHover { isHovered = $0 }
        .animation(AppMotion.smooth, value: isSelected)
        .animation(AppMotion.hover, value: isHovered)
        .animation(AppMotion.smooth, value: totalCount)
        .animation(AppMotion.smooth, value: pendingCount)
    }

    private var markerColor: Color {
        pendingCount > 0
            ? AppTheme.workspaceTokens.accent
            : AppTheme.workspaceTokens.success
    }

    @ViewBuilder
    private var markerStrip: some View {
        if totalCount > 0 {
            HStack(spacing: 2) {
                Circle()
                    .fill(markerColor)
                    .frame(width: 4, height: 4)
                if pendingCount > 0 && pendingCount != totalCount {
                    Circle()
                        .fill(AppTheme.workspaceTokens.success)
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
        if isSelected { return AppTheme.workspaceTokens.accent }
        if !isInCurrentMonth { return AppTheme.workspaceTokens.textMuted }
        if isToday { return AppTheme.workspaceTokens.accent }
        return AppTheme.workspaceTokens.textPrimary
    }

    private var background: Color {
        if isSelected { return AppTheme.workspaceTokens.accentSoft }
        if isHovered { return AppTheme.workspaceTokens.listRowHover }
        return Color.clear
    }

    private var stroke: Color {
        if isSelected { return AppTheme.workspaceTokens.accent.opacity(0.32) }
        if isToday { return AppTheme.workspaceTokens.hairline }
        return Color.clear
    }
}
