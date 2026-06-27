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
                try checkUpdateAvailability()
                try checkUpdateDownloadProgress()
                try checkQuickInputParser()
                try checkHandbookEditorPlaceholderPolicy()
                try checkHandbookEditorSyncPolicy()
                try checkLazyStartupLoading()
                try checkHandbookNotesSnapshotInvalidation()
                try checkTodoStore()
                try checkCredentialBreachChecker()
                try checkCredentialStore()
            }
            try await checkScheduledHandbookLoading()
            try await checkHandbookLoadingStateConflict()
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

func checkCredentialBreachChecker() throws {
    let passwordHash = CredentialBreachChecker.passwordSHA1PrefixSuffix("password")
    try expect(passwordHash.prefix == "5BAA6", "HIBP 密码检查应使用 SHA-1 前 5 位")
    try expect(passwordHash.suffix == "1E4C9B93F3F0682250B6CF8331B7EE68FD8", "HIBP 密码检查应在本地保留 SHA-1 后缀")

    let rangeResponse = """
    003CD215739D7C1B2218670D26F81408237:2
    1E4C9B93F3F0682250B6CF8331B7EE68FD8:3303003
    """
    try expect(
        CredentialBreachChecker.parsePwnedPasswordRangeResponse(rangeResponse, matching: passwordHash.suffix) == 3_303_003,
        "HIBP range 响应应识别匹配后缀出现次数"
    )
    try expect(
        CredentialBreachChecker.parsePwnedPasswordRangeResponse(rangeResponse, matching: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF") == 0,
        "HIBP range 响应未匹配后缀时应返回 0"
    )

    try expect(
        CredentialBreachChecker.emailAddress(in: "账号 user@example.com") == "user@example.com",
        "风险检查应能从账号字段中识别邮箱"
    )
    try expect(
        CredentialBreachChecker.emailAddress(in: "HT008881") == nil,
        "非邮箱账号应跳过邮箱泄露检查"
    )

    let xposedResponse = Data(#"{"breaches":[["Adobe","Dropbox"]]}"#.utf8)
    let emailResult = try CredentialBreachChecker.parseXposedOrNotEmailResponse(xposedResponse, email: "user@example.com")
    if case .exposed(let email, let names) = emailResult {
        try expect(email == "user@example.com", "XposedOrNot 解析应保留被检查邮箱")
        try expect(names == ["Adobe", "Dropbox"], "XposedOrNot 解析应提取泄露名称")
    } else {
        throw CheckFailure.failed("XposedOrNot 命中响应应解析为 exposed")
    }

    let notFoundResponse = Data(#"{"Error":"Not found"}"#.utf8)
    let notFoundResult = try CredentialBreachChecker.parseXposedOrNotEmailResponse(notFoundResponse, email: "safe@example.com")
    try expect(notFoundResult == .notFound(email: "safe@example.com"), "XposedOrNot 未命中响应应解析为 notFound")
}

func checkHandbookEditorPlaceholderPolicy() throws {
    try expect(
        HandbookEditorPlaceholderPolicy.shouldShowBodyPlaceholder(isBodyEmpty: true, isBodyFocused: false),
        "空正文未聚焦时应显示手记输入提示"
    )
    try expect(
        !HandbookEditorPlaceholderPolicy.shouldShowBodyPlaceholder(isBodyEmpty: true, isBodyFocused: true),
        "空正文已聚焦时不应同时显示输入提示和光标"
    )
    try expect(
        !HandbookEditorPlaceholderPolicy.shouldShowBodyPlaceholder(isBodyEmpty: false, isBodyFocused: false),
        "正文已有内容时不应显示手记输入提示"
    )
}

func checkHandbookEditorSyncPolicy() throws {
    try expect(
        HandbookEditorSyncPolicy.preservesLocalTextEditsForSameItemUpdate(isDirty: true, isEditorFocused: false),
        "同一条手记仍有未保存编辑时，应保留本地标题和正文"
    )
    try expect(
        HandbookEditorSyncPolicy.preservesLocalTextEditsForSameItemUpdate(isDirty: false, isEditorFocused: true),
        "同一条手记自动保存回写时，即使已清空 dirty 状态，也应保留当前编辑焦点"
    )
    try expect(
        !HandbookEditorSyncPolicy.preservesLocalTextEditsForSameItemUpdate(isDirty: false, isEditorFocused: false),
        "未聚焦且无本地编辑时，可以用存储层数据同步手记详情"
    )
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

func checkUpdateAvailability() throws {
    try expect(
        AppUpdateAvailability.isAvailable(
            currentVersion: "1.1.16",
            currentBuild: 18,
            manifestVersion: "1.1.17",
            manifestBuild: 18
        ),
        "版本号升高时，即使 build 相同也应允许更新"
    )
    try expect(
        AppUpdateAvailability.isAvailable(
            currentVersion: "1.1.17",
            currentBuild: 18,
            manifestVersion: "1.1.17",
            manifestBuild: 19
        ),
        "同版本 build 升高时应允许更新"
    )
    try expect(
        !AppUpdateAvailability.isAvailable(
            currentVersion: "1.1.17",
            currentBuild: 18,
            manifestVersion: "1.1.17",
            manifestBuild: 18
        ),
        "同版本同 build 不应重复更新"
    )
    try expect(
        !AppUpdateAvailability.isAvailable(
            currentVersion: "1.1.17",
            currentBuild: 19,
            manifestVersion: "1.1.16",
            manifestBuild: 20
        ),
        "远端版本号回退时不应仅因 build 较高触发更新"
    )
    try expect(
        AppUpdateAvailability.compareVersions("1.10.0", "1.2.9") == .orderedDescending,
        "版本号比较应按数字段比较，而不是字符串字典序"
    )
}

func checkUpdateDownloadProgress() throws {
    let progress = AppUpdateDownloadProgress(receivedBytes: 256, expectedBytes: 1_024)
    try expect(progress.fractionCompleted == 0.25, "下载进度应按已下载字节和总字节计算")
    try expect(progress.percentText == "25%", "下载进度应显示整数百分比")
    try expect(progress.detailText.contains("256"), "下载详情应包含已下载大小")

    let unknownSizeProgress = AppUpdateDownloadProgress(receivedBytes: 512, expectedBytes: nil)
    try expect(unknownSizeProgress.fractionCompleted == nil, "未知总大小时不应伪造确定进度")
    try expect(unknownSizeProgress.percentText == nil, "未知总大小时不应显示百分比")
    try expect(unknownSizeProgress.statusText.contains("已下载"), "未知总大小时仍应显示已下载大小")
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

    let nextMonday = TodoQuickInputParser.parse(
        title: "下周一上午10点 召开项目评审",
        notes: "",
        priority: .medium,
        date: fallback,
        progress: .pending,
        isWeekly: false,
        calendar: calendar,
        now: now
    )
    let nextMondayComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextMonday.date)
    try expect(nextMondayComponents.year == 2026, "下周一年份解析错误")
    try expect(nextMondayComponents.month == 6, "下周一月份解析错误")
    try expect(nextMondayComponents.day == 29, "下周一日期解析错误")
    try expect(nextMondayComponents.hour == 10, "下周一上午10点小时解析错误")
    try expect(nextMondayComponents.minute == 0, "下周一上午10点分钟应为 0")

    let weekday = TodoQuickInputParser.parse(
        title: "周五 复核合同台账",
        notes: "",
        priority: .medium,
        date: fallback,
        progress: .pending,
        isWeekly: false,
        calendar: calendar,
        now: now
    )
    let weekdayComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: weekday.date)
    try expect(weekdayComponents.year == 2026, "周五年份解析错误")
    try expect(weekdayComponents.month == 6, "周五月份解析错误")
    try expect(weekdayComponents.day == 26, "周五日期解析错误")
    try expect(weekdayComponents.hour == 10, "解析相对日期未指定时间时应沿用 fallback 时间")
    try expect(weekdayComponents.minute == 0, "解析相对日期未指定时间时分钟应沿用 fallback 时间")

    let threeDaysLater = TodoQuickInputParser.parse(
        title: "大后天 提交月度复盘",
        notes: "",
        priority: .medium,
        date: fallback,
        progress: .pending,
        isWeekly: false,
        calendar: calendar,
        now: now
    )
    let threeDaysLaterComponents = calendar.dateComponents([.year, .month, .day], from: threeDaysLater.date)
    try expect(threeDaysLaterComponents.year == 2026, "大后天年份解析错误")
    try expect(threeDaysLaterComponents.month == 6, "大后天月份解析错误")
    try expect(threeDaysLaterComponents.day == 26, "大后天日期解析错误")

    let noDate = TodoQuickInputParser.parse(
        title: "补充部门周报",
        notes: "",
        priority: .medium,
        date: now,
        progress: .pending,
        isWeekly: false,
        calendar: calendar,
        now: now
    )
    try expect(noDate.date == now, "未指定日期时间时应使用当前时间作为默认时间")

    let weekdayWithCurrentFallback = TodoQuickInputParser.parse(
        title: "后天 复盘客户问题",
        notes: "",
        priority: .medium,
        date: now,
        progress: .pending,
        isWeekly: false,
        calendar: calendar,
        now: now
    )
    let currentFallbackComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: weekdayWithCurrentFallback.date)
    try expect(currentFallbackComponents.year == 2026, "当前 fallback 年份应保留")
    try expect(currentFallbackComponents.month == 6, "当前 fallback 月份应保留")
    try expect(currentFallbackComponents.day == 25, "后天日期解析错误")
    try expect(currentFallbackComponents.hour == 9, "未指定时间时应保留当前 fallback 小时")
    try expect(currentFallbackComponents.minute == 0, "未指定时间时应保留当前 fallback 分钟")
}

@MainActor
func checkLazyStartupLoading() throws {
    let (store, _) = try makeStore()

    store.loadStartupData()
    try expect(store.didLoadTodos, "首屏加载后应标记待办已加载")
    try expect(!store.didLoadHandbookItems, "首屏加载不应同步加载手记")
    try expect(!store.isLoadingHandbookItems, "首屏加载不应进入手记加载状态")
    try expect(store.handbookItems.isEmpty, "首屏加载时手记列表应保持空集合")

    store.loadHandbookItemsIfNeeded()
    try expect(store.didLoadHandbookItems, "按需加载后应标记手记已加载")
}

func checkHandbookNotesSnapshotInvalidation() throws {
    let calendar = makeCalendar()
    let baseDate = try makeDate(DateComponents(year: 2026, month: 6, day: 23, hour: 9), calendar: calendar)
    let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let middleID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let lastID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    let first = HandbookItem(
        id: firstID,
        category: .businessRule,
        folder: "合同",
        title: "租赁合同",
        body: "合同规则",
        createdAt: baseDate.addingTimeInterval(-20),
        updatedAt: baseDate.addingTimeInterval(-20)
    )
    let middle = HandbookItem(
        id: middleID,
        category: .research,
        folder: "竞品",
        title: "竞品调研",
        body: "旧摘要",
        createdAt: baseDate.addingTimeInterval(-10),
        updatedAt: baseDate.addingTimeInterval(-10)
    )
    let last = HandbookItem(
        id: lastID,
        category: .meeting,
        folder: "周会",
        title: "周会纪要",
        body: "会议内容",
        createdAt: baseDate,
        updatedAt: baseDate
    )

    let originalItems = [first, middle, last]
    let originalKey = HandbookNotesListSnapshotKey(
        items: originalItems,
        selectedCategory: nil,
        selectedFolder: nil,
        searchText: ""
    )

    var updatedMiddle = middle
    updatedMiddle.title = "竞品调研更新"
    updatedMiddle.body = "新摘要应立即显示"
    let updatedItems = [first, updatedMiddle, last]
    let updatedKey = HandbookNotesListSnapshotKey(
        items: updatedItems,
        selectedCategory: nil,
        selectedFolder: nil,
        searchText: ""
    )

    try expect(originalKey != updatedKey, "中间手记内容变化必须让列表快照缓存键失效")

    let snapshot = HandbookNotesListSnapshot(
        items: updatedItems,
        selectedCategory: nil,
        selectedFolder: nil,
        searchText: ""
    )
    let rows = snapshot.groups.flatMap(\.rows)
    guard let updatedRow = rows.first(where: { $0.id == middleID }) else {
        throw CheckFailure.failed("更新后的中间手记应出现在列表快照中")
    }
    try expect(updatedRow.title == "竞品调研更新", "列表行标题应读取中间手记的最新标题")
    try expect(updatedRow.preview == "新摘要应立即显示", "列表行摘要应读取中间手记的最新正文")
}

@MainActor
func checkScheduledHandbookLoading() async throws {
    let (seedStore, databaseURL) = try makeStore()
    seedStore.loadStartupData()
    seedStore.addHandbookItem(
        category: .businessRule,
        folder: "合同",
        title: "租赁合同状态",
        body: "切换手记时不应阻塞主线程"
    )

    let store = TodoStore(storageURL: databaseURL)
    store.loadStartupData()
    try expect(!store.didLoadHandbookItems, "异步调度前不应预加载手记")

    store.scheduleLoadHandbookItemsIfNeeded()
    try expect(store.isLoadingHandbookItems, "调度手记加载后应进入 loading 状态")
    try expect(!store.didLoadHandbookItems, "调度手记加载不应同步完成")

    for _ in 0..<50 {
        if store.didLoadHandbookItems {
            break
        }
        try await Task.sleep(for: .milliseconds(20))
    }

    try expect(store.didLoadHandbookItems, "后台手记加载最终应完成")
    try expect(!store.isLoadingHandbookItems, "后台手记加载完成后应退出 loading 状态")
    try expect(store.handbookItems.contains { $0.title == "租赁合同状态" }, "后台手记加载应返回 SQLite 中的数据")
}

@MainActor
func checkHandbookLoadingStateConflict() async throws {
    let (seedStore, databaseURL) = try makeStore()
    seedStore.loadStartupData()
    seedStore.addHandbookItem(
        category: .inspiration,
        folder: "性能",
        title: "按需加载优先",
        body: "同步加载应取消后台预热结果"
    )

    let store = TodoStore(storageURL: databaseURL)
    store.loadStartupData()
    store.scheduleLoadHandbookItemsIfNeeded()
    try expect(store.isLoadingHandbookItems, "调度后应记录后台手记加载状态")

    store.loadHandbookItemsIfNeeded()
    try expect(store.didLoadHandbookItems, "同步按需加载应完成手记加载")
    try expect(!store.isLoadingHandbookItems, "同步按需加载完成后不应残留后台 loading 状态")

    try await Task.sleep(for: .milliseconds(80))
    try expect(store.didLoadHandbookItems, "后台预热返回后不应回退已加载状态")
    try expect(!store.isLoadingHandbookItems, "后台预热返回后不应重新进入 loading 状态")
    try expect(store.handbookItems.contains { $0.title == "按需加载优先" }, "竞态后手记数据应保持可用")
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

    guard let todo = store.todos.first(where: { $0.title == "参加供应商对接会" }) else {
        throw CheckFailure.failed("新增待办后未找到数据")
    }
    try expect(todo.title == "参加供应商对接会", "待办标题应去除首尾空白")
    try expect(todo.notes == "带笔记本", "待办备注应去除首尾空白")
    try expect(todo.priority == .high, "待办优先级应持久化")
    try expect(todo.progress == .inProgress, "待办状态应持久化")

    let reloadedStore = TodoStore(storageURL: databaseURL)
    reloadedStore.load()
    guard let reloadedTodo = reloadedStore.todos.first(where: { $0.title == "参加供应商对接会" }) else {
        throw CheckFailure.failed("重载 SQLite 后未找到待办")
    }
    try expect(reloadedTodo.title == "参加供应商对接会", "SQLite 重载后标题错误")
    try expect(reloadedTodo.notes == "带笔记本", "SQLite 重载后备注错误")
    try expect(reloadedTodo.priority == .high, "SQLite 重载后优先级错误")
    try expect(reloadedTodo.progress == .inProgress, "SQLite 重载后状态错误")

    store.delete(todo)
    try expect(!store.todos.contains(where: { $0.id == todo.id }), "删除后内存中不应保留待办")
    store.restore(todo)
    guard let restoredTodo = store.todos.first(where: { $0.id == todo.id }) else {
        throw CheckFailure.failed("恢复删除后未找到原待办")
    }
    try expect(restoredTodo.id == todo.id, "恢复删除应保留原始 ID")
    let restoredReloadStore = TodoStore(storageURL: databaseURL)
    restoredReloadStore.load()
    try expect(restoredReloadStore.todos.contains(where: { $0.id == todo.id }), "恢复删除应写回 SQLite")

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

    Thread.sleep(forTimeInterval: 0.01)
    guard store.addHandbookItem(category: .research, folder: "竞品", title: "竞品资料", body: "后创建") != nil else {
        throw CheckFailure.failed("新增第二条手记失败")
    }
    guard let olderItem = store.handbookItems.last(where: { $0.id == item.id }) else {
        throw CheckFailure.failed("未找到待更新的旧手记")
    }
    store.update(
        olderItem,
        category: olderItem.category,
        folder: olderItem.folder,
        title: olderItem.title,
        body: "会议纪要更新后不应跳到顶部",
        attachments: olderItem.attachments
    )
    try expect(store.handbookItems.last?.id == item.id, "实时保存正文不应改变手记列表位置")
}

@MainActor
func checkCredentialStore() throws {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("DailyTodosCredentialChecks-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("credentials.sqlite")
    try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let store = CredentialStore(storageURL: databaseURL, autoLockInterval: 60)
    store.load()
    try expect(store.status == .uninitialized, "首次加载凭证库应处于未初始化状态")

    store.initialize(masterPassword: "correct horse battery staple")
    try expect(store.status == .unlocked, "初始化后应解锁凭证库")

    var draft = CredentialDraft()
    draft.title = "GitHub"
    draft.type = .apiKey
    draft.username = "dev@example.com"
    draft.serviceURL = "https://github.com"
    draft.secretValue = "sample-sensitive-token"
    draft.notes = "恢复码"
    draft.tagsText = "dev, code"

    guard let item = store.addCredential(draft) else {
        throw CheckFailure.failed("新增凭证失败：\(store.lastError ?? "unknown")")
    }
    try expect(store.credentials.count == 1, "新增凭证后内存列表应有 1 条")
    try expect(store.credentials(matching: "github", type: nil).count == 1, "凭证应支持标题搜索")
    try expect(store.credentials(matching: "sample-sensitive-token", type: nil).isEmpty, "敏感字段不应进入普通搜索")

    guard let secret = store.secretPayload(for: item, auditAction: "测试查看") else {
        throw CheckFailure.failed("解密凭证失败")
    }
    try expect(secret.secretValue == "sample-sensitive-token", "正确主密码应解密敏感字段")

    let databaseData = try Data(contentsOf: databaseURL)
    let databaseText = String(data: databaseData, encoding: .utf8) ?? ""
    try expect(!databaseText.contains("sample-sensitive-token"), "SQLite 文件不应包含敏感字段明文")
    try expect(!databaseText.contains("恢复码"), "SQLite 文件不应包含敏感备注明文")

    guard let backup = store.exportBackup(password: "backup password") else {
        throw CheckFailure.failed("导出凭证备份失败：\(store.lastError ?? "unknown")")
    }
    try expect(!backup.contains("sample-sensitive-token"), "备份文件不应包含敏感字段明文")

    store.lock()
    try expect(store.status == .locked, "手动锁定后状态应为 locked")
    store.unlock(masterPassword: "wrong password")
    try expect(store.status == .locked, "错误主密码不应解锁凭证库")
    store.unlock(masterPassword: "correct horse battery staple")
    try expect(store.status == .unlocked, "正确主密码应重新解锁凭证库")

    store.setMasterPasswordRequired(false)
    try expect(!store.requiresMasterPassword, "应支持关闭主密码验证")
    store.lock()
    try expect(store.status == .unlocked, "关闭主密码后手动锁定不应要求验证")
    let noPasswordStore = CredentialStore(storageURL: databaseURL, autoLockInterval: 60)
    noPasswordStore.load()
    try expect(noPasswordStore.status == .unlocked, "关闭主密码后重新加载应自动解锁")
    try expect(noPasswordStore.credentials.count == 1, "关闭主密码后凭证仍应可加载")
    noPasswordStore.setMasterPasswordRequired(true, newMasterPassword: "new master password")
    try expect(noPasswordStore.requiresMasterPassword, "应支持重新开启主密码验证")
    noPasswordStore.lock()
    noPasswordStore.unlock(masterPassword: "wrong password")
    try expect(noPasswordStore.status == .locked, "重新开启主密码后错误密码不应解锁")
    noPasswordStore.unlock(masterPassword: "new master password")
    try expect(noPasswordStore.status == .unlocked, "重新开启主密码后正确密码应解锁")

    let importedURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("DailyTodosCredentialImportChecks-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("credentials.sqlite")
    try FileManager.default.createDirectory(at: importedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let importedStore = CredentialStore(storageURL: importedURL, autoLockInterval: 60)
    importedStore.load()
    importedStore.importBackup(backup, password: "backup password", replaceExisting: true)
    importedStore.unlock(masterPassword: "correct horse battery staple")
    try expect(importedStore.credentials.count == 1, "导入备份后应恢复凭证")
    guard let importedItem = importedStore.credentials.first,
          let importedSecret = importedStore.secretPayload(for: importedItem, auditAction: "测试查看") else {
        throw CheckFailure.failed("导入备份后无法解密凭证")
    }
    try expect(importedSecret.secretValue == "sample-sensitive-token", "导入备份后敏感字段应保持一致")

    let looseText = """
    星邦（剪叉）
    http://s3.rootcloud.com/
    账号：HT008881
    密码：sample-login-password
    """
    guard let parsedDraft = CredentialImportParser.draft(fromLooseText: looseText) else {
        throw CheckFailure.failed("文本凭证解析失败")
    }
    try expect(parsedDraft.title == "星邦（剪叉）", "文本解析应识别第一行为标题")
    try expect(parsedDraft.serviceURL == "http://s3.rootcloud.com/", "文本解析应识别 URL")
    try expect(parsedDraft.username == "HT008881", "文本解析应识别账号")
    try expect(parsedDraft.secretValue == "sample-login-password", "文本解析应识别密码")

    let compactLooseText = """
    星邦（剪叉）
    http://s3.rootcloud.com/
    账号：HT001密码：888888
    """
    guard let compactParsedDraft = CredentialImportParser.draft(fromLooseText: compactLooseText) else {
        throw CheckFailure.failed("紧凑文本凭证解析失败")
    }
    try expect(compactParsedDraft.username == "HT001", "紧凑文本解析不应把密码吞进账号")
    try expect(compactParsedDraft.secretValue == "888888", "紧凑文本解析应识别密码")

    let chromeCSV = """
    name,url,username,password,note
    RootCloud,http://s3.rootcloud.com/,HT008881,sample-login-password,剪叉车平台
    """
    let chromeDrafts = CredentialImportParser.drafts(fromChromeCSV: chromeCSV)
    try expect(chromeDrafts.count == 1, "Chrome CSV 应解析 1 条凭证")
    try expect(chromeDrafts[0].title == "RootCloud", "Chrome CSV 应识别 name")
    try expect(chromeDrafts[0].username == "HT008881", "Chrome CSV 应识别 username")
    try expect(chromeDrafts[0].secretValue == "sample-login-password", "Chrome CSV 应识别 password")

    let importedCount = store.importCredentials([parsedDraft] + chromeDrafts)
    try expect(importedCount == 2, "批量导入应返回成功条数")
    try expect(store.credentials.count == 3, "批量导入后凭证数量应增加")
    let databaseDataAfterImport = try Data(contentsOf: databaseURL)
    let databaseTextAfterImport = String(data: databaseDataAfterImport, encoding: .utf8) ?? ""
    try expect(!databaseTextAfterImport.contains("sample-login-password"), "导入凭证后 SQLite 不应包含密码明文")

    store.deleteCredential(item)
    try expect(!store.credentials.contains { $0.id == item.id }, "删除凭证后内存列表不应保留该条")
}

@MainActor
func makeStore() throws -> (TodoStore, URL) {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("DailyTodosChecks-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("todos.sqlite")
    try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    return (TodoStore(storageURL: databaseURL), databaseURL)
}
