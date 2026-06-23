import Foundation

enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): message
        }
    }
}

@main
struct DailyTodosChecks {
    static func main() async {
        do {
            try await MainActor.run {
                try checkQuickInputParser()
                try checkTodoStore()
            }
            print("DailyTodosChecks passed")
        } catch {
            FileHandle.standardError.write(Data("DailyTodosChecks failed: \(error)\n".utf8))
            exit(1)
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw CheckFailure.failed(message)
    }
}

func makeCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
    return calendar
}

func makeDate(_ components: DateComponents, calendar: Calendar) throws -> Date {
    guard let date = calendar.date(from: components) else {
        throw CheckFailure.failed("无法创建测试日期：\(components)")
    }
    return date
}

func checkQuickInputParser() throws {
    let calendar = makeCalendar()
    let now = try makeDate(DateComponents(year: 2026, month: 6, day: 23, hour: 9), calendar: calendar)
    let fallback = try makeDate(DateComponents(year: 2026, month: 6, day: 23, hour: 10), calendar: calendar)

    let halfHour = TodoQuickInputParser.parse(
        title: "19点半 参加供应商对接会，要带笔记本",
        notes: "",
        priority: .medium,
        date: fallback,
        progress: .pending,
        isWeekly: false,
        calendar: calendar,
        now: now
    )
    let halfHourComponents = calendar.dateComponents([.hour, .minute], from: halfHour.date)
    try expect(halfHourComponents.hour == 19, "19点半应解析为 19 点")
    try expect(halfHourComponents.minute == 30, "19点半应解析为 30 分")
    try expect(halfHour.title == "19点半 参加供应商对接会，要带笔记本", "解析不应切割原始标题")
    try expect(halfHour.notes == "待笔记本", "要带笔记本应解析为备注")

    let weekly = TodoQuickInputParser.parse(
        title: "明天下午4点 高优 每周一次 推进中 复盘部门例会",
        notes: "同步给团队",
        priority: .low,
        date: fallback,
        progress: .pending,
        isWeekly: false,
        calendar: calendar,
        now: now
    )
    let weeklyComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: weekly.date)
    try expect(weeklyComponents.year == 2026, "明天年份解析错误")
    try expect(weeklyComponents.month == 6, "明天月份解析错误")
    try expect(weeklyComponents.day == 24, "明天日期解析错误")
    try expect(weeklyComponents.hour == 16, "下午4点应解析为 16 点")
    try expect(weeklyComponents.minute == 0, "下午4点分钟应为 0")
    try expect(weekly.priority == .high, "高优应解析为高优先级")
    try expect(weekly.progress == .inProgress, "推进中应解析为推进中状态")
    try expect(weekly.isWeekly, "每周一次应解析为固定周期")
    try expect(weekly.notes == "同步给团队", "外部备注应被保留")
}

@MainActor
func checkTodoStore() throws {
    let calendar = makeCalendar()
    let (store, databaseURL) = try makeStore()
    let todoDate = try makeDate(DateComponents(year: 2026, month: 6, day: 23, hour: 16), calendar: calendar)

    store.load()
    store.add(
        title: "  参加供应商对接会  ",
        notes: "  带笔记本  ",
        priority: .high,
        date: todoDate,
        progress: .inProgress,
        isWeekly: false
    )

    guard let todo = store.todos.first else {
        throw CheckFailure.failed("新增待办后未找到数据")
    }
    try expect(todo.title == "参加供应商对接会", "待办标题应去除首尾空白")
    try expect(todo.notes == "带笔记本", "待办备注应去除首尾空白")
    try expect(todo.priority == .high, "待办优先级应持久化")
    try expect(todo.progress == .inProgress, "待办状态应持久化")

    let reloadedStore = TodoStore(storageURL: databaseURL)
    reloadedStore.load()
    guard let reloadedTodo = reloadedStore.todos.first else {
        throw CheckFailure.failed("重载 SQLite 后未找到待办")
    }
    try expect(reloadedTodo.title == "参加供应商对接会", "SQLite 重载后标题错误")
    try expect(reloadedTodo.notes == "带笔记本", "SQLite 重载后备注错误")
    try expect(reloadedTodo.priority == .high, "SQLite 重载后优先级错误")
    try expect(reloadedTodo.progress == .inProgress, "SQLite 重载后状态错误")

    let weeklyDate = try makeDate(DateComponents(year: 2026, month: 6, day: 30, hour: 9, minute: 30), calendar: calendar)
    store.add(
        title: "周例会复盘",
        notes: "同步行动项",
        priority: .medium,
        date: weeklyDate,
        progress: .pending,
        isWeekly: true
    )

    guard let originalWeekly = store.todos.first(where: { $0.title == "周例会复盘" }) else {
        throw CheckFailure.failed("新增周期待办后未找到数据")
    }
    store.update(
        originalWeekly,
        title: originalWeekly.title,
        notes: originalWeekly.notes,
        priority: originalWeekly.priority,
        date: originalWeekly.date,
        progress: .done,
        isWeekly: true
    )
    store.update(
        originalWeekly,
        title: originalWeekly.title,
        notes: originalWeekly.notes,
        priority: originalWeekly.priority,
        date: originalWeekly.date,
        progress: .done,
        isWeekly: true
    )

    let weeklyTodos = store.todos.filter { $0.title == "周例会复盘" }
    try expect(weeklyTodos.count == 2, "周期待办完成后应只生成一次下周事项")
    try expect(weeklyTodos.contains { $0.progress == .done }, "周期待办原事项应完成")
    try expect(weeklyTodos.contains { todo in
        todo.progress == .pending
            && todo.isWeekly
            && calendar.isDate(todo.date, inSameDayAs: weeklyDate.addingTimeInterval(7 * 24 * 60 * 60))
    }, "周期待办应生成下周待处理事项")

    let attachment = HandbookAttachment(kind: .image, name: "现场照片.png", path: "/tmp/photo.png")
    store.addHandbookItem(
        category: .meeting,
        folder: "供应商",
        title: "供应商对接",
        body: "会议纪要",
        attachments: [attachment]
    )

    guard let item = store.handbookItems.first else {
        throw CheckFailure.failed("新增手记后未找到数据")
    }
    try expect(item.category == .meeting, "手记分类应持久化")
    try expect(item.trimmedFolder == "供应商", "手记二级目录应持久化")
    try expect(item.attachments == [attachment], "手记附件应持久化")
}

@MainActor
func makeStore() throws -> (TodoStore, URL) {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("DailyTodosChecks-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("todos.sqlite")
    try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    return (TodoStore(storageURL: databaseURL), databaseURL)
}
