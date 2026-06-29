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
                try checkLazyStartupLoading()
                try checkHandbookActivationUsesScheduledLoading()
                try checkHandbookNotesSnapshotInvalidation()
                try checkHandbookNotesSnapshotPreservesSourceOrder()
                try checkHandbookNotesRowsAreLightweight()
                try checkHandbookSearchUsesFullBodyIndex()
                try checkHandbookRepositorySummaryDetailBoundary()
                try checkHandbookWorkspaceSelectionScope()
                try checkHandbookWorkspaceSelectionUsesCurrentScope()
                try checkHandbookCreateDraftTracksCreatedScope()
                try checkHandbookDragTargetsClearFolder()
                try checkHandbookDetailReconcilesSameItemUpdates()
                try checkTodoStore()
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

func checkHandbookActivationUsesScheduledLoading() throws {
    let contentViewURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sources/DailyTodos/ContentView.swift")
    let source = try String(contentsOf: contentViewURL, encoding: .utf8)
    try expect(
        source.contains("store.scheduleLoadHandbookItemsIfNeeded()"),
        "切换到手记模块时应调度后台加载，避免同步 SQLite 阻塞 UI"
    )
    try expect(
        !source.contains("guard newValue == \"handbook\" else { return }\n            store.loadHandbookItemsIfNeeded()"),
        "手记模块激活路径不应同步调用 loadHandbookItemsIfNeeded"
    )
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

func checkHandbookNotesSnapshotPreservesSourceOrder() throws {
    let calendar = makeCalendar()
    let baseDate = try makeDate(DateComponents(year: 2026, month: 6, day: 24, hour: 9), calendar: calendar)
    let stableFirst = HandbookItem(
        category: .meeting,
        folder: "供应商",
        title: "先显示的手记",
        body: "正文实时保存后仍然保持位置",
        createdAt: baseDate,
        updatedAt: baseDate
    )
    let newerButSecond = HandbookItem(
        category: .meeting,
        folder: "供应商",
        title: "更新时间更新但仍排第二",
        body: "快照应尊重 TodoStore 已维护的稳定顺序",
        createdAt: baseDate.addingTimeInterval(10),
        updatedAt: baseDate.addingTimeInterval(3_600)
    )

    let snapshot = HandbookNotesListSnapshot(
        items: [stableFirst, newerButSecond],
        selectedCategory: nil,
        selectedFolder: nil,
        searchText: ""
    )
    let rows = snapshot.groups.flatMap(\.rows)
    try expect(rows.map(\.id) == [stableFirst.id, newerButSecond.id], "手记列表快照应尊重源顺序，避免实时保存后按 updatedAt 二次排序导致列表跳动")
}

func checkHandbookNotesRowsAreLightweight() throws {
    let calendar = makeCalendar()
    let baseDate = try makeDate(DateComponents(year: 2026, month: 6, day: 24, hour: 10), calendar: calendar)
    let longBody = String(repeating: "正文内容", count: 2_000)
    let item = HandbookItem(
        category: .businessRule,
        folder: "审批流",
        title: "CRM-盘账要支持一键打印",
        body: longBody,
        createdAt: baseDate,
        updatedAt: baseDate
    )

    let snapshot = HandbookNotesListSnapshot(
        items: [item],
        selectedCategory: nil,
        selectedFolder: nil,
        searchText: ""
    )
    guard let row = snapshot.groups.first?.rows.first else {
        throw CheckFailure.failed("轻量列表快照应生成列表行")
    }

    let storedPropertyNames = Set(Mirror(reflecting: row).children.compactMap(\.label))
    try expect(!storedPropertyNames.contains("item"), "列表行不应重新持有完整 HandbookItem")
    try expect(!storedPropertyNames.contains("body"), "列表行不应持有完整正文 body")
    try expect(row.preview.count <= 80, "列表行摘要应是短文本，不能携带完整正文")
}

func checkHandbookSearchUsesFullBodyIndex() throws {
    let longPrefix = String(repeating: "前缀内容", count: 40)
    let item = HandbookItem(
        category: .businessRule,
        folder: "合同",
        title: "全文搜索",
        body: "\(longPrefix) 末尾唯一关键词XYZ"
    )
    let snapshot = HandbookNotesListSnapshot(
        items: [item],
        selectedCategory: nil,
        selectedFolder: nil,
        searchText: "唯一关键词XYZ"
    )
    try expect(snapshot.visibleCount == 1, "手记搜索应匹配完整正文，不能只查 80 字列表摘要")
    let row = snapshot.groups.flatMap(\.rows).first
    try expect(row?.preview.contains("唯一关键词XYZ") == false, "回归用例应证明命中词不在短摘要里")
}

func checkHandbookRepositorySummaryDetailBoundary() throws {
    let calendar = makeCalendar()
    let baseDate = try makeDate(DateComponents(year: 2026, month: 6, day: 24, hour: 10), calendar: calendar)
    let id = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    let body = String(repeating: "同步边界正文", count: 500)
    let item = HandbookItem(
        id: id,
        category: .businessRule,
        folder: "审批流",
        title: "Repository 边界",
        body: body,
        createdAt: baseDate,
        updatedAt: baseDate
    )

    let repository = LocalHandbookRepository(items: [item])
    let summaries = repository.noteSummaries()
    try expect(summaries.count == 1, "Repository 应提供列表摘要")
    try expect(summaries[0].id == id, "摘要应保留稳定 ID")
    try expect(summaries[0].preview.count <= 80, "摘要不应暴露完整正文")
    try expect(repository.noteDetail(id: id)?.body == body, "详情应按 ID 单独读取完整正文")

    let index = repository.sidebarIndex(selectedCategory: .businessRule)
    try expect(index.totalCount == 1, "Repository 应提供侧边栏总数")
    try expect(index.categoryCounts[.businessRule] == 1, "Repository 应提供分类计数")
    try expect(index.folders.first?.name == "审批流", "Repository 应提供目录索引")
}

@MainActor
func checkHandbookWorkspaceSelectionScope() throws {
    let calendar = makeCalendar()
    let baseDate = try makeDate(DateComponents(year: 2026, month: 6, day: 24, hour: 11), calendar: calendar)
    let selectedID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    let otherID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    let business = HandbookItem(
        id: selectedID,
        category: .businessRule,
        folder: "审批流",
        title: "业务规则",
        body: "规则",
        createdAt: baseDate,
        updatedAt: baseDate
    )
    let research = HandbookItem(
        id: otherID,
        category: .research,
        folder: "竞品",
        title: "竞品调研",
        body: "调研",
        createdAt: baseDate.addingTimeInterval(-10),
        updatedAt: baseDate.addingTimeInterval(-10)
    )

    let model = HandbookWorkspaceViewModel()
    model.refresh(items: [business, research], selectedCategory: nil, selectedFolder: nil, searchText: "")
    model.selectItem(id: selectedID)
    try expect(model.selectedItemID == selectedID, "选择列表行后应记录选中 ID")

    model.updateScope(selectedCategory: .research, selectedFolder: nil, searchText: "")
    try expect(model.selectedItemID == nil, "切换到不包含当前手记的分类时应清空选择，不应跳选第一条")
    try expect(model.selectedItem == nil, "清空选择后详情应为空")

    model.selectItem(id: otherID)
    model.updateScope(selectedCategory: .research, selectedFolder: nil, searchText: "")
    try expect(model.selectedItemID == otherID, "当前手记仍在范围内时应保持选择")
}

func checkHandbookWorkspaceSelectionUsesCurrentScope() throws {
    let viewModelURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sources/DailyTodos/HandbookWorkspaceViewModel.swift")
    let source = try String(contentsOf: viewModelURL, encoding: .utf8)
    try expect(
        source.contains("summaries.contains(where: { $0.id == selectedItemID && scope.contains($0) })"),
        "手记选中项可见性应基于当前 scope 和 summaries 判断，不能依赖可能滞后的 listSnapshot"
    )
    try expect(
        !source.contains("let visibleIDs = Set(listSnapshot.groups.flatMap"),
        "手记选中项同步不应读取旧 listSnapshot，否则异步重建期间会清错或保留错详情"
    )
}

func checkHandbookCreateDraftTracksCreatedScope() throws {
    let moduleViewURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sources/DailyTodos/ModuleNavigationViews.swift")
    let source = try String(contentsOf: moduleViewURL, encoding: .utf8)
    try expect(
        !source.contains("let previousCategory = handbookCategory"),
        "新建手记后不应恢复旧分类，否则列表 scope 会和新建详情脱节"
    )
    try expect(
        source.contains("handbookCategory = category"),
        "新建手记后应定位到新建项分类，保证左侧菜单、列表和详情一致"
    )
    try expect(
        source.contains("handbookFolder = createdItem.trimmedFolder.isEmpty ? nil : createdItem.trimmedFolder"),
        "新建手记后应定位到新建项二级目录，保证创建后可在当前列表看到选中项"
    )
}

func checkHandbookDragTargetsClearFolder() throws {
    let sidebarURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sources/DailyTodos/HandbookNotesWorkspaceView.swift")
    let sidebarSource = try String(contentsOf: sidebarURL, encoding: .utf8)
    try expect(
        sidebarSource.contains("moveDraggedItems(itemIDs, category: nil, folder: \"\")"),
        "拖到全部手记应显式清空二级目录，不能把 nil 当成保留原目录"
    )
    try expect(
        sidebarSource.contains("moveDraggedItems(itemIDs, category: category, folder: \"\")"),
        "拖到分类行应显式清空二级目录，避免拖拽后仍停在旧标签"
    )

    let moduleURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sources/DailyTodos/ModuleNavigationViews.swift")
    let moduleSource = try String(contentsOf: moduleURL, encoding: .utf8)
    try expect(
        moduleSource.contains("onUpdate(item, category ?? item.category, folder ?? \"\", item.title, item.body, item.attachments)"),
        "拖拽更新应区分清空目录和保留分类，folder nil 不应写回旧目录"
    )
}

func checkHandbookDetailReconcilesSameItemUpdates() throws {
    let detailURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sources/DailyTodos/HandbookDetailPanel.swift")
    let source = try String(contentsOf: detailURL, encoding: .utf8)
    try expect(
        source.contains("reconcileDraft(with: newValue)"),
        "同一手记被外部移动分类/目录后，详情草稿应同步外部字段"
    )
    try expect(
        source.contains("if category != item.category { category = item.category }"),
        "详情草稿应吸收同 ID 外部分类变化，避免自动保存写回旧分类"
    )
    try expect(
        source.contains("if folder != item.folder { folder = item.folder }"),
        "详情草稿应吸收同 ID 外部目录变化，避免自动保存写回旧目录"
    )
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
    try expect(item.remoteID == nil, "本地新增手记默认不应绑定远端 ID")
    try expect(item.syncVersion == 0, "本地新增手记默认同步版本应为 0")
    try expect(item.deletedAt == nil, "本地新增手记默认不应标记删除")

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
    try expect(store.handbookItems.last?.dirtyFields == ["body"], "手记更新应记录同步脏字段")

    guard let dirtyItem = store.handbookItems.last(where: { $0.id == item.id }) else {
        throw CheckFailure.failed("未找到待验证脏字段累积的手记")
    }
    store.update(
        dirtyItem,
        category: dirtyItem.category,
        folder: dirtyItem.folder,
        title: "供应商对接更新",
        body: dirtyItem.body,
        attachments: dirtyItem.attachments
    )
    guard let mergedDirtyItem = store.handbookItems.last(where: { $0.id == item.id }) else {
        throw CheckFailure.failed("未找到已合并脏字段的手记")
    }
    try expect(mergedDirtyItem.dirtyFields == ["body", "title"], "连续本地更新应累积同步脏字段，不能被本次 delta 覆盖")

    store.delete(item)
    try expect(!store.handbookItems.contains(where: { $0.id == item.id }), "软删除后 UI 内存列表不应保留手记")

    let deletedReloadStore = TodoStore(storageURL: databaseURL)
    deletedReloadStore.load()
    try expect(!deletedReloadStore.handbookItems.contains(where: { $0.id == item.id }), "软删除后普通加载不应返回 tombstone")
}

@MainActor
func makeStore() throws -> (TodoStore, URL) {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("DailyTodosChecks-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("todos.sqlite")
    try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    return (TodoStore(storageURL: databaseURL), databaseURL)
}
