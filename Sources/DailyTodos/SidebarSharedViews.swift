import SwiftUI

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
            .background(isSelected ? AppTheme.accent : AppTheme.adaptiveWhite(0.74), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.34) : AppTheme.hairline)
            )
        }
        .buttonStyle(.tactilePlain)
        .help("\(date.formatted(.dateTime.year().month().day()))：\(count) 个未完成")
        .animation(AppMotion.smooth, value: isSelected)
    }

    private var label: String {
        if calendar.isDateInToday(date) { return "今" }
        if calendar.isDateInTomorrow(date) { return "明" }
        return date.formatted(.dateTime.weekday(.narrow))
    }
}
