import Foundation

func formatFullFollowUpDate(_ date: Date, calendar: Calendar = .current) -> String {
    let dateText = date.formatted(.dateTime.year().month().day())
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
