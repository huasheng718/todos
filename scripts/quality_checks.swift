import AppKit
import Foundation
import UniformTypeIdentifiers

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
                try checkP0PerformanceGuardrails()
                try checkRemainingPerformanceGuardrails()
                try checkStoreArchitectureGuardrails()
                try checkDeadCodeGuardrails()
                try checkWorkspaceVisualClarityTheme()
                try checkTodoSidebarVisualClarity()
                try checkQuickInputParser()
                try checkHandbookEditorPlaceholderPolicy()
                try checkHandbookEditorSyncPolicy()
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
                try checkTodoIssueListUsesContextMenu()
                try checkTodoDenseNaturalListPresentation()
                try checkTodoControlsVisualClarity()
                try checkTodoCalendarVisualClarity()
                try checkHandbookDetailReconcilesSameItemUpdates()
                try checkHandbookDetailHandlesImagePaste()
                try checkHandbookImagePasteMenuValidation()
                try checkHandbookPasteboardImageReader()
                try checkHandbookAttachmentStorage()
                try checkSystemInputSourcePolicy()
                try checkTodoStore()
                try checkHandbookStore()
                try checkCredentialBreachChecker()
            }
            try await checkCredentialStore()
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

struct WorkspaceThemeCheckRGB {
    let red: Double
    let green: Double
    let blue: Double
}

func workspaceThemeCheckRelativeLuminance(_ color: WorkspaceThemeCheckRGB) -> Double {
    func linearChannel(_ channel: Double) -> Double {
        channel <= 0.04045
            ? channel / 12.92
            : pow((channel + 0.055) / 1.055, 2.4)
    }

    return 0.2126 * linearChannel(color.red)
        + 0.7152 * linearChannel(color.green)
        + 0.0722 * linearChannel(color.blue)
}

func workspaceThemeCheckContrastRatio(
    _ foreground: WorkspaceThemeCheckRGB,
    _ background: WorkspaceThemeCheckRGB
) -> Double {
    let foregroundLuminance = workspaceThemeCheckRelativeLuminance(foreground)
    let backgroundLuminance = workspaceThemeCheckRelativeLuminance(background)
    let lighter = max(foregroundLuminance, backgroundLuminance)
    let darker = min(foregroundLuminance, backgroundLuminance)
    return (lighter + 0.05) / (darker + 0.05)
}

func sourceFile(_ relativePath: String) throws -> String {
    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

func checkSystemInputSourcePolicy() throws {
    let forbiddenInputSourceAPIs = [
        "NSTextInputContext.current",
        "selectedKeyboardInputSource",
        "keyboardInputSource",
        "TISSelectInputSource",
        "activateKeyboardLayout",
        "kTISPropertyInputSourceID",
        "com.apple.keylayout",
        "com.apple.inputmethod"
    ]
    let sourceFiles = [
        "Sources/DailyTodos/ContentView.swift",
        "Sources/DailyTodos/WorkspaceShellViews.swift",
        "Sources/DailyTodos/TodoCaptureViews.swift",
        "Sources/DailyTodos/HandbookEditableCanvas.swift",
        "Sources/DailyTodos/CredentialViews.swift",
        "Sources/DailyTodos/SettingsViews.swift"
    ]

    for relativePath in sourceFiles {
        let source = try sourceFile(relativePath)
        for forbiddenAPI in forbiddenInputSourceAPIs {
            try expect(
                !source.contains(forbiddenAPI),
                "\(relativePath) 不应调用 \(forbiddenAPI)，输入法必须继承 macOS 当前系统配置"
            )
        }
    }

    let workspaceShellSource = try sourceFile("Sources/DailyTodos/WorkspaceShellViews.swift")
    guard let topBarStart = workspaceShellSource.range(of: "struct GlobalTopBar")?.lowerBound,
          let moduleRailStart = workspaceShellSource.range(of: "struct ModuleRail")?.lowerBound
    else {
        throw CheckFailure.failed("无法定位 GlobalTopBar")
    }
    let globalTopBarSource = String(workspaceShellSource[topBarStart..<moduleRailStart])
    try expect(
        !globalTopBarSource.contains(".frame(width: 1, height: 1)") &&
            !globalTopBarSource.contains(".opacity(0.01)"),
        "全局搜索不能保留 1x1/透明 TextField 常驻焦点树，避免影响系统输入法上下文"
    )
    try expect(
        globalTopBarSource.contains("if isSearchPresented {") &&
            globalTopBarSource.contains("TextField(\"\", text: $searchText)"),
        "全局搜索输入框应仅在搜索打开时创建，避免隐藏 TextField 常驻抢占输入法上下文"
    )
}

func checkP0PerformanceGuardrails() throws {
    let credentialStoreSource = try sourceFile("Sources/DailyTodos/CredentialStore.swift")
    try expect(
        credentialStoreSource.contains("sqlite3_busy_timeout(db, 2_000)"),
        "CredentialStore.openDatabase 应设置 sqlite3_busy_timeout，避免凭证库遇到短暂 SQLite 锁时直接失败"
    )
    try expect(
        credentialStoreSource.contains("Task.detached(priority: .userInitiated)"),
        "凭证加解密必须放到 Task.detached，不能在 MainActor 上执行 PBKDF2/AES 重活"
    )
    guard let credentialLoadStart = credentialStoreSource.range(of: "func load()")?.lowerBound,
          let credentialInitializeStart = credentialStoreSource.range(of: "func initialize(")?.lowerBound
    else {
        throw CheckFailure.failed("无法定位 CredentialStore.load")
    }
    let credentialLoadSource = String(credentialStoreSource[credentialLoadStart..<credentialInitializeStart])
    try expect(
        !credentialLoadSource.contains("CredentialCrypto.unlockLocal"),
        "CredentialStore.load 不能在 MainActor 同步执行本地解锁 PBKDF2，应改为后台解锁"
    )
    try expect(
        credentialLoadSource.contains("guard !hasLoaded") || credentialLoadSource.contains("isLoading"),
        "CredentialStore.load 应具备幂等/加载中保护，避免页面进入时重复加载"
    )
    try expect(
        credentialLoadSource.contains("if isUnlocked") && credentialLoadSource.contains("force"),
        "CredentialStore.load 应显式保护已解锁状态，刷新时只重读列表，不能回退为 locked"
    )
    guard let credentialFilterStart = credentialStoreSource.range(of: "func credentials(matching query: String, type: CredentialType?)")?.lowerBound,
          let credentialAddStart = credentialStoreSource.range(of: "@discardableResult")?.lowerBound
    else {
        throw CheckFailure.failed("无法定位 CredentialStore.credentials(matching:type:)")
    }
    let credentialFilterSource = String(credentialStoreSource[credentialFilterStart..<credentialAddStart])
    try expect(
        !credentialFilterSource.contains("ensureAutoLock()"),
        "CredentialStore.credentials(matching:type:) 是 SwiftUI body 路径，不能触发 ensureAutoLock/lock 等状态修改"
    )
    guard let secretPayloadStart = credentialStoreSource.range(of: "func secretPayload(for item: CredentialItem")?.lowerBound,
          let exportBackupStart = credentialStoreSource.range(of: "func exportBackup(")?.lowerBound
    else {
        throw CheckFailure.failed("无法定位 CredentialStore.secretPayload")
    }
    let secretPayloadSource = String(credentialStoreSource[secretPayloadStart..<exportBackupStart])
    try expect(
        secretPayloadSource.contains("await Self.openSecretPayload") || secretPayloadSource.contains("openSecretPayload("),
        "CredentialStore.secretPayload 应把 AES 解密移到后台 helper，避免查看/编辑/复制凭证时卡住主线程"
    )

    let credentialViewsSource = try sourceFile("Sources/DailyTodos/CredentialViews.swift")
    guard let credentialSidebarStart = credentialViewsSource.range(of: "struct CredentialContextSidebar")?.lowerBound,
          let credentialWorkspaceStart = credentialViewsSource.range(of: "struct CredentialWorkspaceContent")?.lowerBound
    else {
        throw CheckFailure.failed("无法定位 CredentialContextSidebar")
    }
    let credentialSidebarSource = String(credentialViewsSource[credentialSidebarStart..<credentialWorkspaceStart])
    try expect(
        !credentialSidebarSource.contains("credentialStore.load()"),
        "CredentialContextSidebar 不应在 onAppear 重复加载凭证库，加载入口应集中在模块内容或应用启动"
    )

    let todoStoreSource = try sourceFile("Sources/DailyTodos/TodoStore.swift")
    let todoStoreMainOpenStart = todoStoreSource.range(of: "private func openDatabase() throws")?.lowerBound
    let todoStoreMainOpenEnd = todoStoreSource.range(of: "private func prepareDatabase() throws")?.lowerBound
    if let todoStoreMainOpenStart, let todoStoreMainOpenEnd {
        let mainOpenDatabase = String(todoStoreSource[todoStoreMainOpenStart..<todoStoreMainOpenEnd])
        try expect(
            mainOpenDatabase.contains("sqlite3_busy_timeout(db, 2_000)"),
            "TodoStore 主 SQLite 连接应设置 busy_timeout，避免主连接和后台手记连接互相抢锁时报错"
        )
        try expect(
            mainOpenDatabase.contains("PRAGMA foreign_keys = ON") && mainOpenDatabase.contains("PRAGMA journal_mode = WAL"),
            "TodoStore 主 SQLite 连接应保留 foreign_keys 与 WAL PRAGMA"
        )
    } else {
        throw CheckFailure.failed("无法定位 TodoStore.openDatabase")
    }

    let contentViewSource = try sourceFile("Sources/DailyTodos/ContentView.swift")
    try expect(
        contentViewSource.contains("@State private var debouncedGlobalSearchText = \"\""),
        "全局搜索应维护 debouncedGlobalSearchText，避免每次击键同步重算所有模块结果"
    )
    try expect(
        contentViewSource.contains("globalSearchModel.groupedResults")
            && contentViewSource.contains("globalSearchModel.scheduleSearch(query: debouncedGlobalSearchText, context: globalSearchContext)"),
        "全局搜索结果应由后台模型产出，并使用 debouncedGlobalSearchText 调度"
    )
    try expect(
        contentViewSource.contains("Task.sleep(for: .milliseconds(120))")
            && contentViewSource.contains("debounceGlobalSearchText(newValue)"),
        "全局搜索应使用 120ms 防抖，与待办/手记局部搜索保持一致"
    )

    let appThemeSource = try sourceFile("Sources/DailyTodos/AppTheme.swift")
    let settingsSource = try sourceFile("Sources/DailyTodos/SettingsViews.swift")
    try expect(
        appThemeSource.contains("reduceMotionStorageKey = \"DailyTodos.reduceMotion\"")
            && appThemeSource.contains("UserDefaults.standard.bool(forKey: reduceMotionStorageKey)")
            && settingsSource.contains("@AppStorage(AppMotion.reduceMotionStorageKey)"),
        "AppMotion 应恢复 reduceMotion 感知，并在设置页提供减少动态效果入口"
    )
}

func checkRemainingPerformanceGuardrails() throws {
    let contentViewSource = try sourceFile("Sources/DailyTodos/ContentView.swift")
    let globalSearchSource = try sourceFile("Sources/DailyTodos/GlobalCommandSearch.swift")
    try expect(
        contentViewSource.contains("@StateObject private var globalSearchModel")
            && contentViewSource.contains("globalSearchModel.scheduleSearch")
            && globalSearchSource.contains("Task.detached(priority: .userInitiated)"),
        "全局搜索应在后台 Task.detached 计算，不能只在主线程做 120ms 防抖"
    )

    let todoStoreSource = try sourceFile("Sources/DailyTodos/TodoStore.swift")
    guard let toggleStart = todoStoreSource.range(of: "func toggle(_ todo: TodoItem)")?.lowerBound,
          let deleteStart = todoStoreSource.range(of: "func delete(_ todo: TodoItem)")?.lowerBound
    else {
        throw CheckFailure.failed("无法定位 TodoStore.toggle")
    }
    let toggleSource = String(todoStoreSource[toggleStart..<deleteStart])
    try expect(
        toggleSource.contains("BEGIN TRANSACTION") && toggleSource.contains("COMMIT") && toggleSource.contains("ROLLBACK"),
        "toggle weekly 应把更新原事项和生成下周事项包进同一个 SQLite 事务"
    )

    let todoListSource = try sourceFile("Sources/DailyTodos/TodoListViews.swift")
    try expect(
        todoListSource.contains("TodoListSnapshot")
            && todoListSource.contains("let snapshot = TodoListSnapshot(")
            && !todoListSource.contains("private var boardGroups: [TodoProgress: [TodoItem]]"),
        "待办列表 board/matrix/dashboard 分桶应使用单次快照，避免每次 body 重算多套分桶"
    )

    let todoFlowRowSource = try sourceFile("Sources/DailyTodos/TodoFlowRow.swift")
    try expect(
        (todoFlowRowSource.contains("struct TodoFlowRow: View, Equatable")
            || todoFlowRowSource.contains("struct TodoFlowRow: View, @MainActor Equatable"))
            && todoListSource.contains(".equatable()"),
        "TodoFlowRow 应支持 Equatable 并在列表中使用 .equatable()，减少无关行重绘"
    )

    let dateFormatterSource = try sourceFile("Sources/DailyTodos/TodoRowFormatting.swift")
    try expect(
        dateFormatterSource.contains("enum CachedDateFormatter")
            && dateFormatterSource.contains("CachedDateFormatter.fullFollowUpDate"),
        "待办行日期格式化应恢复 CachedDateFormatter，避免大列表中重复创建格式化器"
    )
}

func checkStoreArchitectureGuardrails() throws {
    let handbookStoreSource = try sourceFile("Sources/DailyTodos/HandbookStore.swift")
    try expect(
        handbookStoreSource.contains("final class HandbookStore: ObservableObject"),
        "手记状态和持久化应拆到 HandbookStore，避免 TodoStore 继续膨胀"
    )
    try expect(
        handbookStoreSource.contains("CREATE TABLE IF NOT EXISTS handbook_items")
            && handbookStoreSource.contains("HandbookSQLiteBackgroundReader"),
        "HandbookStore 应承接 handbook_items schema 和后台读取器"
    )

    let todoStoreSource = try sourceFile("Sources/DailyTodos/TodoStore.swift")
    try expect(
        !todoStoreSource.contains("handbook_items"),
        "TodoStore 不应再包含 handbook_items SQL，手记持久化归 HandbookStore"
    )
    try expect(
        !todoStoreSource.contains("HandbookSQLiteBackgroundReader"),
        "TodoStore 不应再承载手记后台 SQLite 读取器"
    )
    try expect(
        !todoStoreSource.contains("HandbookItem"),
        "TodoStore 不应再暴露 HandbookItem 状态或手记 CRUD，视图应依赖 HandbookStore"
    )
}

func checkDeadCodeGuardrails() throws {
    let removedLegacyFiles = [
        "Sources/DailyTodos/HandbookViews.swift",
        "Sources/DailyTodos/HandbookTreeView.swift",
        "Sources/DailyTodos/HandbookSidebarViews.swift",
        "Sources/DailyTodos/HandbookEmptyStates.swift"
    ]
    for file in removedLegacyFiles {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(file)
        try expect(
            !FileManager.default.fileExists(atPath: url.path),
            "\(file) 是旧手记方案残留，不应重新引入"
        )
    }

    let moduleSource = try sourceFile("Sources/DailyTodos/ModuleNavigationViews.swift")
    try expect(
        moduleSource.contains("HandbookFolderSidebarView(")
            && moduleSource.contains("HandbookNotesListView("),
        "手记入口应保持当前三栏工作区，不能回退到旧 HandbookContentView/HandbookTreeView"
    )
    try expect(
        !moduleSource.contains("HandbookContentView(")
            && !moduleSource.contains("HandbookTreeView(")
            && !moduleSource.contains("HandbookSidebarView("),
        "模块导航不应引用已删除的旧手记视图"
    )
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

@MainActor
func checkHandbookAttachmentStorage() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("DailyTodosAttachmentChecks-\(UUID().uuidString)", isDirectory: true)
    let storage = HandbookAttachmentStorage(rootDirectory: root)
    let noteID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    let image = NSImage(size: NSSize(width: 8, height: 8))
    image.lockFocus()
    NSColor.systemTeal.setFill()
    NSRect(x: 0, y: 0, width: 8, height: 8).fill()
    image.unlockFocus()

    let attachment = try storage.savePastedImage(
        image,
        noteID: noteID,
        now: Date(timeIntervalSince1970: 1_777_777_777)
    )

    try expect(attachment.kind == .image, "粘贴图片应保存为 image 附件")
    try expect(attachment.name.hasSuffix(".png"), "粘贴图片应规范化保存为 PNG")
    try expect(attachment.path.contains(noteID.uuidString), "粘贴图片应按手记 ID 分目录保存")
    try expect(FileManager.default.fileExists(atPath: attachment.path), "粘贴图片应写入磁盘")

    let legacyImageLine = "![\(attachment.name)](\(URL(fileURLWithPath: attachment.path).absoluteString))"
    try expect(
        HandbookAttachmentStorage.removingLegacyPastedImageLinks(
            from: "会议结论\n\n\(legacyImageLine)",
            attachments: [attachment]
        ) == "会议结论",
        "升级后应移除与现有图片附件匹配的旧本地 Markdown 引用"
    )
    try expect(
        HandbookAttachmentStorage.removingLegacyPastedImageLinks(
            from: "会议结论\n\n![外部图](https://example.com/image.png)",
            attachments: [attachment]
        ) == "会议结论\n\n![外部图](https://example.com/image.png)",
        "清理旧粘贴记录时不应删除用户自己的 Markdown 图片链接"
    )
    try expect(
        HandbookAttachmentStorage.removingLegacyPastedImageLinks(
            from: "会议结论\n\n  \(legacyImageLine)",
            attachments: [attachment]
        ) == "会议结论\n\n  \(legacyImageLine)",
        "自动清理只能删除完全匹配的历史生成行，不能删除用户缩进过的内容"
    )
    try expect(
        HandbookAttachmentStorage.removingLegacyPastedImageLinks(
            from: "\(legacyImageLine)\n\n用户补充",
            attachments: [attachment]
        ) == "\(legacyImageLine)\n\n用户补充",
        "自动清理只能处理历史生成器追加的正文末尾后缀"
    )
    try expect(
        HandbookAttachmentStorage.removingLegacyPastedImageLinks(
            from: "会议结论\r\n补充说明",
            attachments: [attachment]
        ) == "会议结论\r\n补充说明",
        "没有匹配历史后缀时应逐字节保留正文换行格式"
    )
}

func checkHandbookPasteboardImageReader() throws {
    let pasteboard = NSPasteboard.withUniqueName()
    pasteboard.clearContents()

    let image = NSImage(size: NSSize(width: 8, height: 8))
    image.lockFocus()
    NSColor.systemBlue.setFill()
    NSRect(x: 0, y: 0, width: 8, height: 8).fill()
    image.unlockFocus()

    guard let data = checkPNGData(from: image) else {
        throw CheckFailure.failed("测试图片应能编码为 PNG")
    }
    let didWrite = pasteboard.setData(data, forType: NSPasteboard.PasteboardType(UTType.png.identifier))
    try expect(didWrite, "测试粘贴板应能写入 PNG 数据")

    let pastedImage = HandbookPasteboardImageReader.image(from: pasteboard)
    try expect(pastedImage != nil, "截图粘贴板中的 PNG 数据应能还原为 NSImage")
}

private func checkPNGData(from image: NSImage) -> Data? {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        return nil
    }
    return bitmap.representation(using: .png, properties: [:])
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
        source.contains("handbookStore.scheduleLoadHandbookItemsIfNeeded()"),
        "切换到手记模块时应调度后台加载，避免同步 SQLite 阻塞 UI"
    )
    try expect(
        !source.contains("guard newValue == \"handbook\" else { return }\n            handbookStore.loadHandbookItemsIfNeeded()"),
        "手记模块激活路径不应同步调用 loadHandbookItemsIfNeeded"
    )
}

@MainActor
func checkLazyStartupLoading() throws {
    let (store, databaseURL) = try makeStore()
    let handbookStore = HandbookStore(storageURL: databaseURL)

    store.loadStartupData()
    try expect(store.didLoadTodos, "首屏加载后应标记待办已加载")
    try expect(!handbookStore.didLoadHandbookItems, "首屏加载不应同步加载手记")
    try expect(!handbookStore.isLoadingHandbookItems, "首屏加载不应进入手记加载状态")
    try expect(handbookStore.handbookItems.isEmpty, "首屏加载时手记列表应保持空集合")

    handbookStore.loadHandbookItemsIfNeeded()
    try expect(handbookStore.didLoadHandbookItems, "按需加载后应标记手记已加载")
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

func checkWorkspaceVisualClarityTheme() throws {
    let themeSource = try sourceFile("Sources/DailyTodos/AppTheme.swift")
    let shellSource = try sourceFile("Sources/DailyTodos/WorkspaceShellViews.swift")

    guard let tokensStart = themeSource.range(of: "static var workspaceTokens: WorkspaceThemeTokens"),
          let tokensEnd = themeSource.range(of: "static var isDark: Bool")
    else {
        throw CheckFailure.failed("无法定位 AppTheme.workspaceTokens")
    }
    let tokensSource = String(themeSource[tokensStart.lowerBound..<tokensEnd.lowerBound])

    for requiredMapping in [
        "moduleRail: workspaceModuleRail",
        "contextSidebar: workspaceContextSidebar",
        "contentAltSurface: workspaceAltSurface",
        "listRowHover: workspaceListRowHover",
        "textPrimary: workspacePrimaryText",
        "textSecondary: workspaceSecondaryText",
        "textMuted: workspaceMutedText",
        "action: accent",
        "accentForeground: workspaceAccentForeground",
        "actionSoft: accentSoft",
        "warning: workspaceWarning",
        "danger: workspaceDanger",
        "shadow: .clear"
    ] {
        try expect(tokensSource.contains(requiredMapping), "工作台主题缺少清晰度映射：\(requiredMapping)")
    }
    try expect(
        !tokensSource.contains("moduleRail: sidebar")
            && !tokensSource.contains("contextSidebar: sidebar")
            && !tokensSource.contains("action: accentWarm"),
        "工作台结构表面与主要操作不能继续复用旧皮肤表面或第二强调色"
    )

    for requiredToken in [
        "static var workspaceModuleRail: Color",
        "static var workspaceContextSidebar: Color",
        "static var workspaceAltSurface: Color",
        "static var workspaceListRowHover: Color",
        "static var workspacePrimaryText: Color",
        "static var workspaceSecondaryText: Color",
        "static var workspaceMutedText: Color",
        "static var workspaceAccentForeground: Color",
        "static var workspaceDanger: Color",
        "static var workspaceWarning: Color"
    ] {
        try expect(themeSource.contains(requiredToken), "AppTheme 缺少视觉令牌：\(requiredToken)")
    }

    guard let primaryStart = themeSource.range(of: "static var workspacePrimaryText: Color"),
          let secondaryStart = themeSource.range(of: "static var workspaceSecondaryText: Color"),
          let mutedStart = themeSource.range(of: "static var workspaceMutedText: Color"),
          let hairlineStart = themeSource.range(of: "static var workspaceHairline: Color"),
          let canvasStart = themeSource.range(of: "static var workspaceCanvas: Color"),
          let moduleStart = themeSource.range(of: "static var workspaceModuleRail: Color"),
          let sidebarStart = themeSource.range(of: "static var workspaceContextSidebar: Color"),
          let surfaceStart = themeSource.range(of: "static var workspaceSurface: Color"),
          let altSurfaceStart = themeSource.range(of: "static var workspaceAltSurface: Color"),
          let hoverStart = themeSource.range(of: "static var workspaceListRowHover: Color")
    else {
        throw CheckFailure.failed("无法定位工作台文本和表面令牌")
    }
    let primarySource = String(themeSource[primaryStart.lowerBound..<secondaryStart.lowerBound])
    let secondarySource = String(themeSource[secondaryStart.lowerBound..<mutedStart.lowerBound])
    let mutedSource = String(themeSource[mutedStart.lowerBound..<hairlineStart.lowerBound])
    let canvasSource = String(themeSource[canvasStart.lowerBound..<moduleStart.lowerBound])
    let moduleSource = String(themeSource[moduleStart.lowerBound..<sidebarStart.lowerBound])
    let sidebarSource = String(themeSource[sidebarStart.lowerBound..<surfaceStart.lowerBound])
    let surfaceSource = String(themeSource[surfaceStart.lowerBound..<altSurfaceStart.lowerBound])
    let altSurfaceSource = String(themeSource[altSurfaceStart.lowerBound..<hoverStart.lowerBound])
    let hoverSource = String(themeSource[hoverStart.lowerBound..<primaryStart.lowerBound])
    try expect(
        primarySource.contains("Color(red: 0.949, green: 0.957, blue: 0.969)")
            && primarySource.contains("Color(red: 0.125, green: 0.141, blue: 0.165)"),
        "workspacePrimaryText 必须使用已验证的明暗中性文本值"
    )
    try expect(
        secondarySource.contains("Color(red: 0.722, green: 0.753, blue: 0.800)")
            && secondarySource.contains("Color(red: 0.349, green: 0.384, blue: 0.439)"),
        "workspaceSecondaryText 必须使用已验证的明暗中性文本值"
    )
    try expect(
        mutedSource.contains("Color(red: 0.604, green: 0.639, blue: 0.690)")
            && mutedSource.contains("Color(red: 0.395, green: 0.430, blue: 0.480)"),
        "workspaceMutedText 必须使用已验证的明暗中性文本值"
    )
    try expect(
        canvasSource.contains("Color(red: 0.082, green: 0.090, blue: 0.106)")
            && canvasSource.contains("Color(red: 0.957, green: 0.961, blue: 0.969)"),
        "对比度校验的画布表面必须与工作台令牌保持一致"
    )
    try expect(
        moduleSource.contains("Color(red: 0.098, green: 0.110, blue: 0.129)")
            && moduleSource.contains("Color(red: 0.933, green: 0.941, blue: 0.953)"),
        "对比度校验的模块栏表面必须与工作台令牌保持一致"
    )
    try expect(
        sidebarSource.contains("Color(red: 0.114, green: 0.125, blue: 0.149)")
            && sidebarSource.contains("Color(red: 0.969, green: 0.973, blue: 0.980)"),
        "对比度校验的侧栏表面必须与工作台令牌保持一致"
    )
    try expect(
        surfaceSource.contains("Color(red: 0.129, green: 0.145, blue: 0.169)")
            && surfaceSource.contains("Color.white"),
        "对比度校验的内容表面必须与工作台令牌保持一致"
    )
    try expect(
        altSurfaceSource.contains("Color(red: 0.149, green: 0.169, blue: 0.196)")
            && altSurfaceSource.contains("Color(red: 0.973, green: 0.976, blue: 0.984)"),
        "对比度校验的次级内容表面必须与工作台令牌保持一致"
    )
    try expect(
        hoverSource.contains("Color(red: 0.169, green: 0.188, blue: 0.220)")
            && hoverSource.contains("Color(red: 0.957, green: 0.965, blue: 0.973)"),
        "对比度校验的 hover 表面必须与工作台令牌保持一致"
    )

    let textTokens: [(String, WorkspaceThemeCheckRGB, WorkspaceThemeCheckRGB)] = [
        ("primary", .init(red: 0.125, green: 0.141, blue: 0.165), .init(red: 0.949, green: 0.957, blue: 0.969)),
        ("secondary", .init(red: 0.349, green: 0.384, blue: 0.439), .init(red: 0.722, green: 0.753, blue: 0.800)),
        ("muted", .init(red: 0.395, green: 0.430, blue: 0.480), .init(red: 0.604, green: 0.639, blue: 0.690))
    ]
    let surfaces: [(String, WorkspaceThemeCheckRGB, WorkspaceThemeCheckRGB)] = [
        ("canvas", .init(red: 0.957, green: 0.961, blue: 0.969), .init(red: 0.082, green: 0.090, blue: 0.106)),
        ("module rail", .init(red: 0.933, green: 0.941, blue: 0.953), .init(red: 0.098, green: 0.110, blue: 0.129)),
        ("context sidebar", .init(red: 0.969, green: 0.973, blue: 0.980), .init(red: 0.114, green: 0.125, blue: 0.149)),
        ("content", .init(red: 1.0, green: 1.0, blue: 1.0), .init(red: 0.129, green: 0.145, blue: 0.169)),
        ("alternate content", .init(red: 0.973, green: 0.976, blue: 0.984), .init(red: 0.149, green: 0.169, blue: 0.196)),
        ("row hover", .init(red: 0.957, green: 0.965, blue: 0.973), .init(red: 0.169, green: 0.188, blue: 0.220))
    ]
    for (textName, lightText, darkText) in textTokens {
        for (surfaceName, lightSurface, darkSurface) in surfaces {
            let lightRatio = workspaceThemeCheckContrastRatio(lightText, lightSurface)
            let darkRatio = workspaceThemeCheckContrastRatio(darkText, darkSurface)
            try expect(lightRatio >= 4.5, "light \(textName) 与 \(surfaceName) 对比度必须 >= 4.5:1，实际为 \(lightRatio)")
            try expect(darkRatio >= 4.5, "dark \(textName) 与 \(surfaceName) 对比度必须 >= 4.5:1，实际为 \(darkRatio)")
        }
    }

    let lightAccentForeground = WorkspaceThemeCheckRGB(red: 1.0, green: 1.0, blue: 1.0)
    let darkAccentForeground = WorkspaceThemeCheckRGB(red: 0.082, green: 0.090, blue: 0.106)
    let accentSurfaces: [(String, WorkspaceThemeCheckRGB, WorkspaceThemeCheckRGB)] = [
        ("ocean", .init(red: 0.170, green: 0.400, blue: 0.950), .init(red: 0.365, green: 0.596, blue: 1.000)),
        ("aurora", .init(red: 0.435, green: 0.357, blue: 0.827), .init(red: 0.620, green: 0.536, blue: 0.930)),
        ("board", .init(red: 0.720, green: 0.280, blue: 0.510), .init(red: 0.890, green: 0.430, blue: 0.650)),
        ("leafcutter", .init(red: 0.184, green: 0.490, blue: 0.361), .init(red: 0.360, green: 0.720, blue: 0.540)),
        ("workspace", .init(red: 0.239, green: 0.388, blue: 0.867), .init(red: 0.400, green: 0.560, blue: 1.000))
    ]
    for (skinName, lightAccent, darkAccent) in accentSurfaces {
        let lightRatio = workspaceThemeCheckContrastRatio(lightAccentForeground, lightAccent)
        let darkRatio = workspaceThemeCheckContrastRatio(darkAccentForeground, darkAccent)
        try expect(lightRatio >= 4.5, "light accentForeground 与 \(skinName) accent 对比度必须 >= 4.5:1，实际为 \(lightRatio)")
        try expect(darkRatio >= 4.5, "dark accentForeground 与 \(skinName) accent 对比度必须 >= 4.5:1，实际为 \(darkRatio)")
    }
    guard let accentForegroundStart = themeSource.range(of: "static var workspaceAccentForeground: Color"),
          let dangerStart = themeSource.range(of: "static var workspaceDanger: Color")
    else {
        throw CheckFailure.failed("无法定位 accentForeground/danger 令牌")
    }
    let accentForegroundSource = String(themeSource[accentForegroundStart.lowerBound..<dangerStart.lowerBound])
    try expect(
        accentForegroundSource.contains("isDark ? workspaceCanvas : Color.white")
            && !accentForegroundSource.contains("AppSkin.current"),
        "accentForeground 应按明暗模式提供可访问前景，不能按皮肤分支"
    )

    try expect(
        shellSource.contains("AppLogoImage(size: 26, shadowRadius: 0)"),
        "模块导航 logo 不应显示投影"
    )

    guard let sharedVisualStart = themeSource.range(of: "static var canvasGradient: [Color]"),
          let accentStart = themeSource.range(of: "static var accent: Color"),
          let sharedVisualAfterAccentStart = themeSource.range(of: "static var shellStroke: Color"),
          let darkOverlayStart = themeSource.range(of: "private static var darkOverlayBase: Color")
    else {
        throw CheckFailure.failed("无法定位 AppTheme 共享视觉令牌边界")
    }
    let sharedVisualBeforeAccent = String(themeSource[sharedVisualStart.lowerBound..<accentStart.lowerBound])
    let sharedVisualAfterAccent = String(themeSource[sharedVisualAfterAccentStart.lowerBound..<darkOverlayStart.lowerBound])
    try expect(
        !sharedVisualBeforeAccent.contains("AppSkin.current")
            && !sharedVisualBeforeAccent.contains("case .ocean"),
        "canvasGradient 及 accent 之前的工作台视觉令牌不能按皮肤分支"
    )
    try expect(
        !sharedVisualAfterAccent.contains("AppSkin.current")
            && !sharedVisualAfterAccent.contains("case .ocean"),
        "accent/accentSoft 之外的工作台视觉令牌不能按皮肤分支"
    )

    let darkOverlaySource = String(themeSource[darkOverlayStart.lowerBound..<themeSource.endIndex])
    try expect(
        !darkOverlaySource.contains("AppSkin.current")
            && !darkOverlaySource.contains("case .ocean"),
        "darkOverlayBase 不能按皮肤分支"
    )
    for requiredAlias in [
        "static var accentCyan: Color { accent }",
        "static var shellStroke: Color { workspaceHairline }",
        "static var shadow: Color { .clear }",
        "static var accentWarm: Color { workspaceWarning }"
    ] {
        try expect(themeSource.contains(requiredAlias), "旧视觉令牌应委托给共享令牌：\(requiredAlias)")
    }

    guard let railButtonStart = shellSource.range(of: "struct ModuleRailButton"),
          let chromeMetricsStart = shellSource.range(of: "enum WorkspaceChromeMetrics")
    else {
        throw CheckFailure.failed("无法定位 ModuleRailButton")
    }
    let railButtonSource = String(shellSource[railButtonStart.lowerBound..<chromeMetricsStart.lowerBound])
    try expect(
        railButtonSource.contains("cornerRadius: 6")
            && railButtonSource.contains("AppTheme.workspaceTokens.listRowHover"),
        "模块导航应使用 6px 圆角和统一 hover 表面"
    )
}

func checkTodoSidebarVisualClarity() throws {
    let source = try sourceFile("Sources/DailyTodos/TodoSidebarViews.swift")
    guard let buttonStart = source.range(of: "struct DateButton")
    else {
        throw CheckFailure.failed("无法定位 DateButton")
    }
    let buttonSource = String(source[buttonStart.lowerBound..<source.endIndex])

    try expect(
        source.contains(".background(AppTheme.workspaceTokens.contextSidebar)"),
        "待办上下文侧栏应使用独立 contextSidebar 表面"
    )
    try expect(
        !buttonSource.contains("AppTheme.accentWarm")
            && !buttonSource.contains("cornerRadius: 12")
            && !buttonSource.contains("RoundedRectangle(cornerRadius: 2"),
        "待办分类不能保留橙色竖线或 12px 卡片式选中态"
    )
    try expect(
        buttonSource.contains("cornerRadius: 6")
            && buttonSource.contains("private var countForeground: Color")
            && buttonSource.contains("private var countBackground: Color")
            && buttonSource.contains("AppTheme.workspaceTokens.listRowHover"),
        "待办分类应使用统一圆角、hover 表面和数量颜色规则"
    )
}

func checkTodoIssueListUsesContextMenu() throws {
    let rowSource = try sourceFile("Sources/DailyTodos/TodoFlowRow.swift")
    let listSource = try sourceFile("Sources/DailyTodos/TodoListViews.swift")
    let menuSource = try sourceFile("Sources/DailyTodos/TodoContextMenuViews.swift")

    try expect(
        rowSource.contains("TodoIssueStatusMarker")
            && rowSource.contains("TodoIssueSignalIcon(todo: todo)")
            && rowSource.contains("TodoContextMenuContent(")
            && rowSource.contains(".contextMenu"),
        "待办行应使用完成框与单一 issue 信号，并通过右键菜单承载操作"
    )
    try expect(
        !rowSource.contains("ProgressMenuTag(progress: todo.progress")
            && !rowSource.contains("Image(systemName: \"pencil\")"),
        "普通待办行不应保留行内状态下拉或 pencil 操作入口"
    )
    try expect(
        listSource.contains("TodoBoardCard")
            && listSource.contains("TodoContextMenuContent(")
            && !listSource.contains("ProgressMenuTag(progress: todo.progress")
            && !listSource.contains("Image(systemName: \"pencil\")"),
        "看板卡片也应把状态/编辑操作收进右键菜单，避免与列表规则不一致"
    )
    try expect(
        menuSource.contains("Menu(\"状态\")")
            && menuSource.contains("Menu(\"优先级\")")
            && menuSource.contains("Menu(\"跟进日期\")")
            && menuSource.contains("Label(\"编辑\", systemImage: \"pencil\")")
            && menuSource.contains("Label(\"复制标题\", systemImage: \"doc.on.doc\")")
            && menuSource.contains("Label(\"删除\", systemImage: \"trash\")"),
        "右键菜单应覆盖状态、优先级、跟进日期、编辑、复制和删除这些原行内操作"
    )
}

func checkTodoDenseNaturalListPresentation() throws {
    let rowSource = try sourceFile("Sources/DailyTodos/TodoFlowRow.swift")
    let listSource = try sourceFile("Sources/DailyTodos/TodoListViews.swift")
    let badgesSource = try sourceFile("Sources/DailyTodos/TodoBadges.swift")
    let captureSource = try sourceFile("Sources/DailyTodos/TodoCaptureViews.swift")
    let sidebarSource = try sourceFile("Sources/DailyTodos/TodoSidebarViews.swift")
    guard
        let rowBackgroundStart = rowSource.range(of: "private var rowBackground: Color"),
        let startEditingStart = rowSource.range(of: "private func startEditing()")
    else {
        throw CheckFailure.failed("待办行应保留 rowBackground 视觉分层入口")
    }
    let rowBackgroundSource = String(rowSource[rowBackgroundStart.lowerBound..<startEditingStart.lowerBound])

    try expect(
        rowSource.contains("TodoIssueSignalIcon(todo: todo)")
            && listSource.contains("TodoIssueSignalIcon(todo: todo)"),
        "紧凑、分组和看板待办应复用单一状态信号"
    )
    try expect(
        !rowSource.contains("TodoIssuePriorityIcon")
            && !rowSource.contains("TodoIssueProgressIcon")
            && !listSource.contains("TodoIssuePriorityIcon")
            && !listSource.contains("TodoIssueProgressIcon"),
        "普通待办不能同时展示优先级和进度两个彩色 icon"
    )
    try expect(
        !rowSource.contains("issueRailColor")
            && !rowSource.contains("sideRailOpacity")
            && rowSource.contains("AppTheme.workspaceTokens.danger")
            && rowSource.contains("AppTheme.workspaceTokens.textSecondary"),
        "任务行应取消状态竖线，并用语义色区分逾期日期与普通日期"
    )
    try expect(
        rowSource.contains(".font(.system(size: 14, weight: todo.isDone ? .regular : .semibold))")
            && rowSource.contains(".font(.system(size: 12, weight: .regular))")
            && rowSource.contains(".lineLimit(2)"),
        "任务标题和备注应使用 14/12 的清晰文字层级"
    )
    try expect(
        !rowSource.contains("PriorityOutlineTag(priority: todo.priority")
            && !rowSource.contains("TodoIssueProgressText(progress: todo.progress)"),
        "普通待办行不应继续使用“高/中/低”或“待/推进/完成”的文字标签"
    )
    try expect(
        rowSource.contains("naturalFollowUpText")
            && rowSource.contains("Text(naturalFollowUpText)")
            && rowSource.contains("Text(titleText)"),
        "待办主行应把跟进时间和标题组合成自然语言阅读顺序"
    )
    try expect(
        !rowBackgroundSource.contains("isOverdue")
            && !rowBackgroundSource.contains("TodoPriority.high.displayColor"),
        "逾期普通行不应再使用红色背景底色"
    )
    try expect(
        !rowSource.contains(".opacity(rowOpacity)")
            && !rowSource.contains("private var rowOpacity: Double")
            && rowSource.contains("AppTheme.workspaceTokens.accentForeground")
            && !rowSource.contains(".foregroundStyle(.white)"),
        "已完成普通行不能通过容器透明度降低文字对比度"
    )

    guard let signalStart = rowSource.range(of: "private var signal: (systemName: String, color: Color, label: String)?"),
          let overdueStart = rowSource.range(of: "private var isOverdue: Bool", range: signalStart.upperBound..<rowSource.endIndex)
    else {
        throw CheckFailure.failed("无法定位 TodoIssueSignalIcon.signal")
    }
    let signalSource = String(rowSource[signalStart.lowerBound..<overdueStart.lowerBound])
    try expect(
        signalSource.contains("if isOverdue")
            && signalSource.contains("case .inProgress:")
            && signalSource.contains("case .waiting:")
            && signalSource.contains("case .done:")
            && signalSource.contains("case .pending:\n            if todo.priority == .high")
            && signalSource.contains("AppTheme.workspaceTokens.textSecondary, \"高优先级\"")
            && !signalSource.contains("AppTheme.workspaceTokens.danger, \"高优先级\""),
        "issue 信号应按逾期、进度、高优先级 pending 的顺序解析，且高优先级旗标保持中性"
    )

    guard let boardStart = listSource.range(of: "struct TodoBoardCard"),
          let boardEnd = listSource.range(of: "enum WorkSectionKind")
    else {
        throw CheckFailure.failed("无法定位 TodoBoardCard")
    }
    let boardSource = String(listSource[boardStart.lowerBound..<boardEnd.lowerBound])
    try expect(
        !boardSource.contains("priorityRailColor")
            && !boardSource.contains("todo.priority.displayColor")
            && !boardSource.contains(".shadow(")
            && !boardSource.contains("cardOpacity")
            && !boardSource.contains(".opacity(cardOpacity)")
            && !boardSource.contains("cornerRadius: 15"),
        "看板卡片不能保留优先级竖线/边框、直接投影、完成态容器透明度或超过 8px 圆角"
    )
    for requiredToken in [
        "AppTheme.workspaceTokens.contentSurface",
        "AppTheme.workspaceTokens.listRowHover",
        "AppTheme.workspaceTokens.listRowSelected",
        "AppTheme.workspaceTokens.hairline",
        "AppTheme.workspaceTokens.accent",
        "AppTheme.workspaceTokens.danger",
        "AppTheme.workspaceTokens.textPrimary",
        "AppTheme.workspaceTokens.textSecondary"
    ] {
        try expect(boardSource.contains(requiredToken), "TodoBoardCard 缺少工作台令牌：\(requiredToken)")
    }
    try expect(
        boardSource.contains("RoundedRectangle(cornerRadius: 8")
            && boardSource.contains("todo.isDone ? AppTheme.workspaceTokens.textSecondary : AppTheme.workspaceTokens.textPrimary")
            && !boardSource.contains("AppTheme.workspaceTokens.textSecondary.opacity"),
        "看板完成态应保留完整容器不透明度，并使用可访问文本令牌与删除线"
    )

    guard let progressColorStart = badgesSource.range(of: "var displayColor: Color"),
          let priorityExtensionStart = badgesSource.range(of: "extension TodoPriority")
    else {
        throw CheckFailure.failed("无法定位 TodoProgress.displayColor")
    }
    let progressColorSource = String(badgesSource[progressColorStart.lowerBound..<priorityExtensionStart.lowerBound])
    let priorityColorSource = String(badgesSource[priorityExtensionStart.lowerBound..<badgesSource.endIndex])
    try expect(
        !progressColorSource.contains("AppSkin.current")
            && !priorityColorSource.contains("AppSkin.current"),
        "TodoProgress/TodoPriority displayColor 不能按皮肤分支"
    )
    try expect(
        progressColorSource.contains("AppTheme.workspaceTokens.textSecondary")
            && progressColorSource.contains("AppTheme.workspaceTokens.accent")
            && progressColorSource.contains("AppTheme.workspaceTokens.warning")
            && progressColorSource.contains("AppTheme.workspaceTokens.success"),
        "待办进度颜色应只使用共享语义/工作台令牌"
    )
    try expect(
        priorityColorSource.contains("var taskDisplayColor: Color")
            && priorityColorSource.contains("case .high: return AppTheme.workspaceTokens.warning")
            && priorityColorSource.contains("case .high: return AppTheme.workspaceTokens.danger")
            && badgesSource.contains("priority.taskDisplayColor")
            && captureSource.contains("color: priority.taskDisplayColor")
            && listSource.contains("case .urgentImportant: TodoPriority.high.taskDisplayColor"),
        "任务优先级必须使用 warning/neutral 颜色，同时保留 danger 供通用风险与错误调用"
    )
    try expect(
        listSource.contains("LazyVStack(spacing: 3)")
            && listSource.contains("LazyVStack(spacing: 4)")
            && !listSource.contains("LazyVStack(spacing: 7)"),
        "待办列表行距应压缩，提高信息密度"
    )

    let expectedNavigation = [
        ("今日推进", "scope"),
        ("未完成", "circle.dashed"),
        ("等待反馈", "hourglass"),
        ("本周固定", "repeat.circle"),
        ("已完成", "checkmark.circle.fill"),
        ("全部待办", "tray.full.fill")
    ]
    let navigationTitleIndexes = expectedNavigation.compactMap { title, _ in
        sidebarSource.range(of: "title: \"\(title)\"")?.lowerBound
    }
    try expect(
        navigationTitleIndexes.count == expectedNavigation.count
            && zip(navigationTitleIndexes, navigationTitleIndexes.dropFirst()).allSatisfy(<),
        "待办侧栏应按今日推进、未完成、等待反馈、本周固定、已完成、全部待办排列"
    )
    for (title, symbol) in expectedNavigation {
        guard let titleRange = sidebarSource.range(of: "title: \"\(title)\"") else {
            throw CheckFailure.failed("待办侧栏缺少 \(title)")
        }
        let remainingSource = sidebarSource[titleRange.lowerBound...]
        try expect(
            remainingSource.prefix(220).contains("systemImage: \"\(symbol)\""),
            "\(title) 应使用 \(symbol) 图标"
        )
        try expect(
            NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil,
            "当前 macOS 不支持待办侧栏图标 \(symbol)"
        )
    }
    try expect(
        sidebarSource.contains(".symbolRenderingMode(.hierarchical)")
            && sidebarSource.contains(".font(.system(size: 14, weight: .semibold))")
            && sidebarSource.contains(".frame(width: 20, height: 20)"),
        "待办侧栏图标应统一使用 hierarchical 渲染和 20x20 稳定尺寸"
    )
}

func checkTodoControlsVisualClarity() throws {
    let shellSource = try sourceFile("Sources/DailyTodos/WorkspaceShellViews.swift")
    let captureSource = try sourceFile("Sources/DailyTodos/TodoCaptureViews.swift")

    guard let searchStart = shellSource.range(of: "struct WorkspaceSearchField"),
          let rowSurfaceStart = shellSource.range(of: "struct WorkspaceListRowSurface")
    else {
        throw CheckFailure.failed("无法定位工作台搜索和分段控件")
    }
    let controlsSource = String(shellSource[searchStart.lowerBound..<rowSurfaceStart.lowerBound])

    try expect(
        controlsSource.contains("AppTheme.workspaceTokens.contentSurface")
            && controlsSource.contains("lineWidth: focusBinding.wrappedValue ? 1.5 : 1")
            && controlsSource.contains("AppTheme.workspaceTokens.accentSoft")
            && controlsSource.contains("AppTheme.workspaceTokens.accent"),
        "搜索与分段控件应使用明确表面、1.5px 焦点环和轻量选中态"
    )
    try expect(
        !controlsSource.contains("selection == option ? .white")
            && !controlsSource.contains(".fill(AppTheme.workspaceTokens.accent)"),
        "分段控件不应继续使用整块强调色填充"
    )

    guard let captureStart = captureSource.range(of: "struct QuickCaptureBar"),
          let previewStart = captureSource.range(of: "struct QuickCapturePreview")
    else {
        throw CheckFailure.failed("无法定位 QuickCaptureBar")
    }
    let captureBarSource = String(captureSource[captureStart.lowerBound..<previewStart.lowerBound])
    try expect(
        !captureBarSource.contains("LinearGradient")
            && !captureBarSource.contains("AppTheme.accentWarm")
            && !captureBarSource.contains(".shadow(")
            && !captureBarSource.contains("cornerRadius: 16"),
        "快速记录应去除渐变、第二强调色、投影和 16px 卡片圆角"
    )
    try expect(
        captureBarSource.contains("cornerRadius: 8")
            && captureBarSource.contains("lineWidth: isFocused ? 1.5 : 1")
            && captureBarSource.contains("AppTheme.workspaceTokens.contentSurface")
            && captureBarSource.contains("AppTheme.workspaceTokens.accentForeground")
            && !captureBarSource.contains("? Color.white"),
        "快速记录应使用 8px 平面表面、明确焦点边框和可访问强调色前景"
    )
}

func checkTodoCalendarVisualClarity() throws {
    let quickDateSource = try sourceFile("Sources/DailyTodos/SidebarSharedViews.swift")
    let calendarSource = try sourceFile("Sources/DailyTodos/TodoMiniCalendarViews.swift")

    try expect(
        quickDateSource.contains("AppTheme.workspaceTokens.accentSoft")
            && quickDateSource.contains("AppTheme.workspaceTokens.listRowHover")
            && quickDateSource.contains("if isSelected || calendar.isDateInToday(date)")
            && !quickDateSource.contains("AppTheme.adaptiveWhite(0.74)")
            && !quickDateSource.contains("cornerRadius: 10"),
        "快速日期应使用轻量选中/hover 状态，且今天在未选中时使用 accent 前景"
    )
    try expect(
        calendarSource.contains("private var calendarNavigation: some View")
            && !calendarSource.contains("private var yearStepper")
            && !calendarSource.contains("private var monthStepper")
            && !calendarSource.contains("AppTheme.accentWarm"),
        "小日历应合并年月导航并移除第二强调色"
    )
    guard let bodyStart = calendarSource.range(of: "var body: some View"),
          let navigationStart = calendarSource.range(of: "private var calendarNavigation: some View")
    else {
        throw CheckFailure.failed("无法定位 TodoMiniCalendar.body/calendarNavigation")
    }
    let calendarBodySource = String(calendarSource[bodyStart.lowerBound..<navigationStart.lowerBound])
    try expect(
        !calendarBodySource.contains("AppTheme.adaptiveWhite")
            && !calendarBodySource.contains("cornerRadius: 13"),
        "月历主体不能继续使用半透明卡片容器"
    )
    guard let dayCellStart = calendarSource.range(of: "struct MiniCalendarDayCell") else {
        throw CheckFailure.failed("无法定位 MiniCalendarDayCell")
    }
    let dayCellSource = String(calendarSource[dayCellStart.lowerBound..<calendarSource.endIndex])
    try expect(
        dayCellSource.contains("@State private var isHovered = false")
            && dayCellSource.contains(".onHover { isHovered = $0 }")
            && dayCellSource.contains("if isSelected { return AppTheme.workspaceTokens.accentSoft }")
            && dayCellSource.contains("if isHovered { return AppTheme.workspaceTokens.listRowHover }")
            && dayCellSource.contains("if isToday { return AppTheme.workspaceTokens.accent }")
            && dayCellSource.contains("if isToday { return AppTheme.workspaceTokens.hairline }"),
        "小日历日期应提供稳定 hover，保留选中优先级，并让今天使用 accent 前景或 hairline"
    )
}

func checkHandbookDetailReconcilesSameItemUpdates() throws {
    let detailURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sources/DailyTodos/HandbookDetailPanel.swift")
    let source = try String(contentsOf: detailURL, encoding: .utf8)
    try expect(
        source.contains("preservesLocalTextEdits: HandbookEditorSyncPolicy.preservesLocalTextEditsForSameItemUpdate"),
        "同一手记回写时应通过同步策略保护本地输入和焦点"
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

func checkHandbookDetailHandlesImagePaste() throws {
    let sourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../Sources/DailyTodos/HandbookDetailPanel.swift")
        .standardizedFileURL
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    let bodyEditorSource = try sourceFile("Sources/DailyTodos/HandbookBodyEditorSection.swift")
    let canvasSourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../Sources/DailyTodos/HandbookEditableCanvas.swift")
        .standardizedFileURL
    let canvasSource = try String(contentsOf: canvasSourceURL, encoding: .utf8)
    let attachmentViewsSourceURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../Sources/DailyTodos/HandbookAttachmentViews.swift")
        .standardizedFileURL
    let attachmentViewsSource = try String(contentsOf: attachmentViewsSourceURL, encoding: .utf8)
    let pasteEditorSource = try sourceFile("Sources/DailyTodos/HandbookPastingTextEditor.swift")
    let pasteboardReaderSource = try sourceFile("Sources/DailyTodos/HandbookPasteboardImageReader.swift")
    try expect(
        bodyEditorSource.contains("let onPasteImage: (NSImage) -> Void"),
        "手记正文编辑器应接收 AppKit 图片粘贴回调，不能只依赖 SwiftUI 粘贴命令"
    )
    try expect(
        bodyEditorSource.contains("HandbookPastingTextEditor("),
        "正文编辑器应使用可拦截 NSTextView paste(_:) 的编辑器，避免 TextEditor 吞掉截图粘贴事件"
    )
    try expect(
        pasteEditorSource.contains("override func paste(_ sender: Any?)")
            && pasteEditorSource.contains("HandbookPasteboardImageReader.image(from: NSPasteboard.general)"),
        "图片粘贴应在 AppKit responder 层读取 NSPasteboard，而不是等待 SwiftUI onPasteCommand"
    )
    try expect(
        !bodyEditorSource.contains(".onPasteCommand(of: [.image]"),
        "手记正文图片粘贴不应继续依赖 TextEditor 上的 onPasteCommand；该路径在 NSTextView 焦点中不会稳定触发"
    )
    try expect(
        pasteboardReaderSource.contains("NSImage(pasteboard: pasteboard)")
            && pasteboardReaderSource.contains("UTType.png.identifier")
            && pasteboardReaderSource.contains("UTType.jpeg.identifier")
            && pasteboardReaderSource.contains("UTType.tiff.identifier"),
        "截图粘贴应直接支持 NSPasteboard 中的 png/jpeg/tiff 位图数据"
    )
    try expect(
        !source.contains("guard canvasFocus == .body else { return }"),
        "选中手记但正文尚未聚焦时，图片粘贴也应落到正文末尾，不能静默忽略"
    )
    try expect(
        source.contains("guard canvasFocus != .title else { return }"),
        "标题焦点中粘贴图片时应避免误写正文"
    )
    try expect(
        source.contains("focusBodyAfterItemSelection(newValue.id)"),
        "从列表选中手记后应把正文设为粘贴目标，避免图片粘贴停在列表焦点中失效"
    )
    try expect(
        source.contains("private func focusBodyAfterItemSelection(_ selectedItemID: UUID)"),
        "手记详情应有专门的选择后正文聚焦 helper，避免焦点逻辑散落在同步流程里"
    )
    try expect(
        !source.contains("HandbookAttachmentStorage.appendingMarkdownImage"),
        "图片粘贴只应添加图片预览与附件，不能把本地文件 Markdown 链接写入正文"
    )
    try expect(
        source.contains("HandbookAttachmentStorage.removingLegacyPastedImageLinks")
            && source.contains("shouldPersistLegacyImageCleanup")
            && source.contains("guard self.item?.id == item.id else { return }")
            && source.contains("submitEdit(for: item, force: true)"),
        "打开旧手记时应清理并保存历史图片引用，且不能在快速切换时回写到其他手记"
    )
    try expect(
        source.contains("|| !attachments.isEmpty"),
        "仅包含图片或附件的手记也应允许保存清理后的正文"
    )
    try expect(
        canvasSource.contains("HandbookInlineImagePreviewList(attachments: $attachments"),
        "粘贴后的图片应在正文编辑区下方以内联预览显示，不能只作为附件芯片存在"
    )
    try expect(
        bodyEditorSource.contains("private var resolvedEditorHeight: CGFloat") &&
            bodyEditorSource.contains(".frame(height: resolvedEditorHeight)"),
        "有图片附件时正文编辑器应使用动态高度，让图片出现在正文空白区域内"
    )
    try expect(
        attachmentViewsSource.contains("struct HandbookInlineImagePreviewList")
            && attachmentViewsSource.contains("NSImage(contentsOfFile: attachment.path)")
            && attachmentViewsSource.contains("Image(nsImage: image)"),
        "图片附件预览应直接读取本地图片并渲染位图，而不是只显示文件名"
    )
    try expect(
        source.contains("HandbookAttachmentStrip(attachments: $attachments, isEditing: true)"),
        "手记详情应显示可编辑附件区"
    )
}

func checkHandbookImagePasteMenuValidation() throws {
    let source = try sourceFile("Sources/DailyTodos/HandbookPastingTextEditor.swift")
    try expect(
        source.contains("override func validateUserInterfaceItem")
            && source.contains("item.action == #selector(paste(_:))")
            && source.contains("HandbookPasteboardImageReader.image(from: NSPasteboard.general) != nil")
            && source.contains("return super.validateUserInterfaceItem(item)"),
        "截图图片在剪贴板中时，手记正文右键菜单的粘贴项应保持可用，不能只覆盖 paste(_:)"
    )
}

@MainActor
func checkScheduledHandbookLoading() async throws {
    let (_, databaseURL) = try makeStore()
    let seedStore = HandbookStore(storageURL: databaseURL)
    seedStore.addHandbookItem(
        category: .businessRule,
        folder: "合同",
        title: "租赁合同状态",
        body: "切换手记时不应阻塞主线程"
    )

    let store = HandbookStore(storageURL: databaseURL)
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
    let (_, databaseURL) = try makeStore()
    let seedStore = HandbookStore(storageURL: databaseURL)
    seedStore.addHandbookItem(
        category: .inspiration,
        folder: "性能",
        title: "按需加载优先",
        body: "同步加载应取消后台预热结果"
    )

    let store = HandbookStore(storageURL: databaseURL)
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
}

@MainActor
func checkHandbookStore() throws {
    let (_, databaseURL) = try makeStore()
    let store = HandbookStore(storageURL: databaseURL)

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

    let legacyAttachment = HandbookAttachment(kind: .image, name: "pasted-image.png", path: "/tmp/pasted-image.png")
    let legacyImageLine = "![\(legacyAttachment.name)](\(URL(fileURLWithPath: legacyAttachment.path).absoluteString))"
    guard let imageOnlyItem = store.addHandbookItem(
        category: .inspiration,
        title: "",
        body: legacyImageLine,
        attachments: [legacyAttachment]
    ) else {
        throw CheckFailure.failed("创建历史图片手记失败")
    }
    store.update(
        imageOnlyItem,
        category: imageOnlyItem.category,
        folder: imageOnlyItem.folder,
        title: "",
        body: "",
        attachments: imageOnlyItem.attachments
    )
    let imageOnlyReloadStore = HandbookStore(storageURL: databaseURL)
    imageOnlyReloadStore.loadHandbookItemsIfNeeded()
    guard let reloadedImageOnlyItem = imageOnlyReloadStore.handbookItems.first(where: { $0.id == imageOnlyItem.id }) else {
        throw CheckFailure.failed("仅含图片附件的手记清理后未持久化")
    }
    try expect(reloadedImageOnlyItem.body.isEmpty, "历史图片链接清理后正文应保持为空")
    try expect(
        reloadedImageOnlyItem.attachments.count == 1
            && reloadedImageOnlyItem.attachments[0].kind == legacyAttachment.kind
            && reloadedImageOnlyItem.attachments[0].name == legacyAttachment.name
            && reloadedImageOnlyItem.attachments[0].path == legacyAttachment.path,
        "历史图片链接清理后附件应继续保留"
    )

    store.delete(item)
    try expect(!store.handbookItems.contains(where: { $0.id == item.id }), "软删除后 UI 内存列表不应保留手记")

    let deletedReloadStore = HandbookStore(storageURL: databaseURL)
    deletedReloadStore.loadHandbookItemsIfNeeded()
    try expect(!deletedReloadStore.handbookItems.contains(where: { $0.id == item.id }), "软删除后普通加载不应返回 tombstone")
}

@MainActor
func checkCredentialStore() async throws {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("DailyTodosCredentialChecks-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("credentials.sqlite")
    try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)

    let store = CredentialStore(storageURL: databaseURL, autoLockInterval: 60)
    await store.load()
    try expect(store.status == .uninitialized, "首次加载凭证库应处于未初始化状态")

    await store.initialize(masterPassword: "correct horse battery staple")
    try expect(store.status == .unlocked, "初始化后应解锁凭证库")

    var draft = CredentialDraft()
    draft.title = "GitHub"
    draft.type = .apiKey
    draft.username = "dev@example.com"
    draft.serviceURL = "https://github.com"
    draft.secretValue = "sample-sensitive-token"
    draft.notes = "恢复码"
    draft.tagsText = "dev, code"

    guard let item = await store.addCredential(draft) else {
        throw CheckFailure.failed("新增凭证失败：\(store.lastError ?? "unknown")")
    }
    try expect(store.credentials.count == 1, "新增凭证后内存列表应有 1 条")
    try expect(store.credentials(matching: "github", type: nil).count == 1, "凭证应支持标题搜索")
    try expect(store.credentials(matching: "sample-sensitive-token", type: nil).isEmpty, "敏感字段不应进入普通搜索")

    guard let secret = await store.secretPayload(for: item, auditAction: "测试查看") else {
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
    await store.unlock(masterPassword: "wrong password")
    try expect(store.status == .locked, "错误主密码不应解锁凭证库")
    await store.unlock(masterPassword: "correct horse battery staple")
    try expect(store.status == .unlocked, "正确主密码应重新解锁凭证库")
    await store.load()
    try expect(store.status == .unlocked, "已解锁凭证库重复 load 不应回退为 locked")
    try expect(store.credentials.count == 1, "已解锁凭证库重复 load 不应清空内存列表")

    await store.setMasterPasswordRequired(false)
    try expect(!store.requiresMasterPassword, "应支持关闭主密码验证")
    store.lock()
    try expect(store.status == .unlocked, "关闭主密码后手动锁定不应要求验证")
    let noPasswordStore = CredentialStore(storageURL: databaseURL, autoLockInterval: 60)
    await noPasswordStore.load()
    try expect(noPasswordStore.status == .unlocked, "关闭主密码后重新加载应自动解锁")
    try expect(noPasswordStore.credentials.count == 1, "关闭主密码后凭证仍应可加载")
    await noPasswordStore.setMasterPasswordRequired(true, newMasterPassword: "new master password")
    try expect(noPasswordStore.requiresMasterPassword, "应支持重新开启主密码验证")
    noPasswordStore.lock()
    await noPasswordStore.unlock(masterPassword: "wrong password")
    try expect(noPasswordStore.status == .locked, "重新开启主密码后错误密码不应解锁")
    await noPasswordStore.unlock(masterPassword: "new master password")
    try expect(noPasswordStore.status == .unlocked, "重新开启主密码后正确密码应解锁")

    let importedURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("DailyTodosCredentialImportChecks-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("credentials.sqlite")
    try FileManager.default.createDirectory(at: importedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let importedStore = CredentialStore(storageURL: importedURL, autoLockInterval: 60)
    await importedStore.load()
    importedStore.importBackup(backup, password: "backup password", replaceExisting: true)
    await importedStore.unlock(masterPassword: "correct horse battery staple")
    try expect(importedStore.credentials.count == 1, "导入备份后应恢复凭证")
    guard let importedItem = importedStore.credentials.first,
          let importedSecret = await importedStore.secretPayload(for: importedItem, auditAction: "测试查看") else {
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

    let importedCount = await store.importCredentials([parsedDraft] + chromeDrafts)
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
