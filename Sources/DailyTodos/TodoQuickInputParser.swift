import Foundation

struct ParsedTodoInput: Equatable {
    var title: String
    var notes: String
    var priority: TodoPriority
    var date: Date
    var progress: TodoProgress
    var isWeekly: Bool
}

enum TodoQuickInputParser {
    static func parse(
        title rawTitle: String,
        notes rawNotes: String,
        priority fallbackPriority: TodoPriority,
        date fallbackDate: Date,
        progress fallbackProgress: TodoProgress,
        isWeekly fallbackIsWeekly: Bool,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> ParsedTodoInput {
        let originalTitle = normalize(rawTitle)
        let originalNotes = normalize(rawNotes)
        var working = originalTitle

        let dateResult = parseDate(in: working, fallbackDate: fallbackDate, calendar: calendar, now: now)
        working = dateResult.remaining

        let priorityResult = parsePriority(in: working, fallback: fallbackPriority)
        working = priorityResult.remaining

        let progressResult = parseProgress(in: working, fallback: fallbackProgress)
        working = progressResult.remaining

        let weeklyResult = parseWeekly(in: working, fallback: fallbackIsWeekly)
        working = weeklyResult.remaining

        let noteResult = parseNotes(in: working)
        working = noteResult.remaining

        let parsedNotes = [noteResult.notes, originalNotes]
            .map(normalize)
            .filter { !$0.isEmpty }
            .joined(separator: "；")

        return ParsedTodoInput(
            title: originalTitle,
            notes: parsedNotes,
            priority: priorityResult.priority,
            date: dateResult.date,
            progress: progressResult.progress,
            isWeekly: weeklyResult.isWeekly
        )
    }

    private static func parseDate(
        in text: String,
        fallbackDate: Date,
        calendar: Calendar,
        now: Date
    ) -> (date: Date, remaining: String) {
        var remaining = text
        var date = fallbackDate
        var consumedDate = false

        let datePatterns: [(String, (NSTextCheckingResult, String) -> Date?)] = [
            (#"(今天|今日)"#, { _, _ in now }),
            (#"(明天|明日)"#, { _, _ in calendar.date(byAdding: .day, value: 1, to: now) }),
            (#"(后天)"#, { _, _ in calendar.date(byAdding: .day, value: 2, to: now) }),
            (#"(昨天|昨日)"#, { _, _ in calendar.date(byAdding: .day, value: -1, to: now) }),
            (#"(\d{1,2})[月/.-](\d{1,2})[日号]?"#, { match, source in
                guard let month = intCapture(match, in: source, at: 1),
                      let day = intCapture(match, in: source, at: 2) else { return nil }
                var components = calendar.dateComponents([.year], from: now)
                components.month = month
                components.day = day
                return calendar.date(from: components)
            })
        ]

        for (pattern, resolver) in datePatterns {
            guard let match = firstMatch(pattern, in: remaining),
                  let resolvedDate = resolver(match, remaining) else {
                continue
            }
            date = resolvedDate
            remaining = remove(match, from: remaining)
            consumedDate = true
            break
        }

        if !consumedDate {
            date = fallbackDate
        }

        if let timeResult = parseTime(in: remaining, baseDate: date, calendar: calendar) {
            date = timeResult.date
            remaining = timeResult.remaining
        } else if consumedDate {
            date = preserveTime(from: fallbackDate, on: date, calendar: calendar)
        }

        return (date, normalize(remaining))
    }

    private static func parseTime(
        in text: String,
        baseDate: Date,
        calendar: Calendar
    ) -> (date: Date, remaining: String)? {
        let patterns = [
            #"(?:(上午|早上|早晨|中午|下午|晚上|今晚|夜里)\s*)?(\d{1,2})\s*点\s*半"#,
            #"(?:(上午|早上|早晨|中午|下午|晚上|今晚|夜里)\s*)?(\d{1,2})\s*[点:：]\s*(\d{1,2})?\s*(?:分)?(?:钟)?"#,
            #"(?:(上午|早上|早晨|中午|下午|晚上|今晚|夜里)\s*)?(\d{1,2})[:：](\d{1,2})"#
        ]

        for pattern in patterns {
            guard let match = firstMatch(pattern, in: text),
                  var hour = intCapture(match, in: text, at: 2) else {
                continue
            }
            let minute = intCapture(match, in: text, at: 3) ?? (matchedText(match, in: text).contains("半") ? 30 : 0)
            guard (0...23).contains(hour), (0...59).contains(minute) else {
                continue
            }

            let period = stringCapture(match, in: text, at: 1)
            if let period {
                if ["下午", "晚上", "今晚", "夜里"].contains(period), hour < 12 {
                    hour += 12
                } else if period == "中午", hour < 11 {
                    hour += 12
                } else if ["上午", "早上", "早晨"].contains(period), hour == 12 {
                    hour = 0
                }
            }

            var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
            components.hour = hour
            components.minute = minute
            components.second = 0
            guard let date = calendar.date(from: components) else {
                continue
            }
            return (date, normalize(remove(match, from: text)))
        }

        return nil
    }

    private static func parsePriority(in text: String, fallback: TodoPriority) -> (priority: TodoPriority, remaining: String) {
        let patterns: [(TodoPriority, String)] = [
            (.high, #"(高优先级|高优|优先级高|紧急|重要)"#),
            (.medium, #"(中优先级|中优|优先级中|普通|一般)"#),
            (.low, #"(低优先级|低优|优先级低|不急)"#)
        ]

        for (priority, pattern) in patterns {
            guard let match = firstMatch(pattern, in: text) else { continue }
            return (priority, normalize(remove(match, from: text)))
        }

        return (fallback, text)
    }

    private static func parseProgress(in text: String, fallback: TodoProgress) -> (progress: TodoProgress, remaining: String) {
        let patterns: [(TodoProgress, String)] = [
            (.inProgress, #"(推进中|处理中|进行中)"#),
            (.waiting, #"(等反馈|等待反馈|等待他人|等别人|待反馈)"#),
            (.done, #"(已完成|完成了|完成)"#),
            (.pending, #"(待处理|待办)"#)
        ]

        for (progress, pattern) in patterns {
            guard let match = firstMatch(pattern, in: text) else { continue }
            return (progress, normalize(remove(match, from: text)))
        }

        return (fallback, text)
    }

    private static func parseWeekly(in text: String, fallback: Bool) -> (isWeekly: Bool, remaining: String) {
        guard let match = firstMatch(#"(每周\s*(?:一次|一回|固定)?|每星期\s*(?:一次|一回|固定)?|每礼拜\s*(?:一次|一回|固定)?|周固定|固定每周|每周固定)"#, in: text) else {
            return (fallback, text)
        }
        return (true, normalize(remove(match, from: text)))
    }

    private static func parseNotes(in text: String) -> (notes: String, remaining: String) {
        let patterns = [
            #"(?:，|,|；|;)?\s*(?:备注|注|说明|要带|带上|带|准备|待|记得|需|需要)\s*[:：]?\s*(.+)$"#,
            #"(?:，|,|；|;)\s*(.+)$"#
        ]

        for pattern in patterns {
            guard let match = firstMatch(pattern, in: text),
                  let note = stringCapture(match, in: text, at: 1) else {
                continue
            }
            let remaining = normalize(remove(match, from: text))
            return (normalizeNote(note), remaining)
        }

        return ("", text)
    }

    private static func normalizeNote(_ text: String) -> String {
        let cleaned = normalize(text)
            .trimmingCharacters(in: CharacterSet(charactersIn: "，,；;。 "))
        guard !cleaned.isEmpty else { return "" }
        if cleaned.hasPrefix("要带") {
            return "待\(cleaned.dropFirst(2))"
        }
        if cleaned.hasPrefix("带上") {
            return "待\(cleaned.dropFirst(2))"
        }
        if cleaned.hasPrefix("带") {
            return "待\(cleaned.dropFirst())"
        }
        if cleaned.hasPrefix("待") || cleaned.hasPrefix("备注") {
            return cleaned
        }
        return "待\(cleaned)"
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "　", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func preserveTime(from source: Date, on target: Date, calendar: Calendar) -> Date {
        var targetComponents = calendar.dateComponents([.year, .month, .day], from: target)
        let sourceComponents = calendar.dateComponents([.hour, .minute, .second], from: source)
        targetComponents.hour = sourceComponents.hour
        targetComponents.minute = sourceComponents.minute
        targetComponents.second = sourceComponents.second
        return calendar.date(from: targetComponents) ?? target
    }

    private static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range)
    }

    private static func remove(_ match: NSTextCheckingResult, from text: String) -> String {
        guard let range = Range(match.range, in: text) else {
            return text
        }
        return String(text[..<range.lowerBound] + " " + text[range.upperBound...])
    }

    private static func matchedText(_ match: NSTextCheckingResult, in text: String) -> String {
        guard let range = Range(match.range, in: text) else {
            return ""
        }
        return String(text[range])
    }

    private static func intCapture(_ match: NSTextCheckingResult, in text: String, at index: Int) -> Int? {
        guard let value = stringCapture(match, in: text, at: index) else {
            return nil
        }
        return Int(value)
    }

    private static func stringCapture(_ match: NSTextCheckingResult, in text: String, at index: Int) -> String? {
        guard index < match.numberOfRanges else {
            return nil
        }
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else {
            return nil
        }
        let value = String(text[swiftRange])
        return value.isEmpty ? nil : value
    }
}
