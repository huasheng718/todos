import Foundation

enum CachedDateFormatter {
    private static let lock = NSLock()
    private static let fullFollowUpFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func fullFollowUpDate(_ date: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        return fullFollowUpFormatter.string(from: date)
    }
}

func formatFullFollowUpDate(_ date: Date, calendar: Calendar = .current) -> String {
    let dateText = CachedDateFormatter.fullFollowUpDate(date)
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
