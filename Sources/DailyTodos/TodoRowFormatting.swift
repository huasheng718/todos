import Foundation

// 性能优化:缓存 DateFormatter 实例,避免在 body 内每次调用 .formatted() 时
// 重新构造 DateFormatter(每次构造约 0.02ms,1000 行列表累积 20ms)。
// setLocalizedDateFormatFromTemplate 会根据 locale 自动调整字段顺序和符号。
enum CachedDateFormatter {
    // "6月26日" 风格(TodoFlowRow.followUpText 同年分支)
    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f
    }()

    // "26年6月26日" 风格(TodoFlowRow.followUpText 跨年分支)
    static let yearMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("yyMMMd")
        return f
    }()

    // "6月26日 14:30" 风格(HandbookViews item.updatedAt)
    static let monthDayHourMinute: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMdHHmm")
        return f
    }()

    // "2026年6月26日 星期五" 风格(TodoSectionViews section header)
    static let yearMonthDayWeekday: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("yMMMdEEEE")
        return f
    }()

    // "6月26日" 宽月份风格(TodoSectionViews title)
    static let monthWideDay: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMMd")
        return f
    }()
}

func formatFullFollowUpDate(_ date: Date, calendar: Calendar = .current) -> String {
    let dateText = CachedDateFormatter.yearMonthDay.string(from: date)
    let suffix = timeSuffix(for: date, calendar: calendar)
    return suffix.isEmpty ? dateText : "\(dateText) \(suffix)"
}

func timeSuffix(for date: Date, calendar: Calendar = .current) -> String {
    guard !calendar.isDate(date, equalTo: calendar.startOfDay(for: date), toGranularity: .minute) else {
        return ""
    }
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    return String(format: " %02d:%02d", hour, minute)
}
