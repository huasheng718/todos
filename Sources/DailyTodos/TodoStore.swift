import Foundation
import SQLite3

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var todos: [TodoItem] = []
    @Published private(set) var handbookItems: [HandbookItem] = []
    @Published private(set) var lastError: String?
    @Published private(set) var didLoadTodos = false
    @Published private(set) var didLoadHandbookItems = false
    @Published private(set) var isLoadingHandbookItems = false

    private let databaseURL: URL
    private let legacyJSONURL: URL
    private let calendar = Calendar.current
    private var isDatabasePrepared = false
    private var handbookLoadGeneration = 0
    nonisolated(unsafe) private var db: OpaquePointer?

    init(storageURL: URL? = nil) {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let appDirectory = baseURL.appendingPathComponent("DailyTodos", isDirectory: true)

        if let storageURL {
            databaseURL = storageURL
            legacyJSONURL = storageURL.deletingLastPathComponent().appendingPathComponent("todos.json")
        } else {
            databaseURL = appDirectory.appendingPathComponent("todos.sqlite")
            legacyJSONURL = appDirectory.appendingPathComponent("todos.json")
        }
    }

    deinit {
        sqlite3_close(db)
    }

    func load() {
        do {
            try PerformanceMonitor.measure("TodoStore.load") {
                try loadStartupDataInternal()
                try loadHandbookItemsIfNeededInternal()
            }
            lastError = nil
        } catch {
            lastError = "读取待办数据失败：\(error.localizedDescription)"
        }
    }

    func loadStartupData() {
        do {
            try PerformanceMonitor.measure("TodoStore.loadStartupData") {
                try loadStartupDataInternal()
            }
            lastError = nil
        } catch {
            lastError = "读取待办数据失败：\(error.localizedDescription)"
        }
    }

    func loadHandbookItemsIfNeeded() {
        guard !didLoadHandbookItems else { return }

        do {
            try PerformanceMonitor.measure("TodoStore.loadHandbookItems") {
                try loadHandbookItemsIfNeededInternal()
            }
            lastError = nil
        } catch {
            lastError = "读取手记数据失败：\(error.localizedDescription)"
        }
    }

    func scheduleLoadHandbookItemsIfNeeded() {
        scheduleLoadHandbookItemsIfNeeded(after: nil)
    }

    func prefetchHandbookItemsAfterStartup() {
        scheduleLoadHandbookItemsIfNeeded(after: .milliseconds(350))
    }

    private func scheduleLoadHandbookItemsIfNeeded(after delay: Duration?) {
        guard !didLoadHandbookItems, !isLoadingHandbookItems else { return }

        do {
            try prepareDatabase()
            isLoadingHandbookItems = true
            handbookLoadGeneration += 1
            let generation = handbookLoadGeneration
            let databaseURL = databaseURL

            Task {
                if let delay {
                    try? await Task.sleep(for: delay)
                } else {
                    await Task.yield()
                }

                do {
                    let items = try await Task.detached(priority: .userInitiated) {
                        try PerformanceMonitor.measure("TodoStore.loadHandbookItems.background") {
                            try HandbookSQLiteBackgroundReader.fetchHandbookItems(databaseURL: databaseURL)
                        }
                    }.value

                    guard generation == handbookLoadGeneration, !didLoadHandbookItems else { return }
                    handbookItems = items
                    didLoadHandbookItems = true
                    isLoadingHandbookItems = false
                    lastError = nil
                } catch {
                    guard generation == handbookLoadGeneration, !didLoadHandbookItems else { return }
                    isLoadingHandbookItems = false
                    lastError = "读取手记数据失败：\(error.localizedDescription)"
                }
            }
        } catch {
            lastError = "读取手记数据失败：\(error.localizedDescription)"
        }
    }

    @discardableResult
    func add(
        title: String,
        notes: String,
        priority: TodoPriority,
        date: Date,
        progress: TodoProgress = .pending,
        isWeekly: Bool = false
    ) -> TodoItem? {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return nil }

        let item = TodoItem(
            title: cleanedTitle,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority,
            date: date,
            progress: progress,
            isWeekly: isWeekly
        )

        do {
            try PerformanceMonitor.measure("TodoStore.addTodo") {
                try insert(item)
                insertInMemory(item)
            }
            lastError = nil
            return item
        } catch {
            lastError = "保存待办数据失败：\(error.localizedDescription)"
            return nil
        }
    }

    func update(
        _ todo: TodoItem,
        title: String,
        notes: String,
        priority: TodoPriority,
        date: Date,
        progress: TodoProgress,
        isWeekly: Bool
    ) {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return }
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }

        var updated = todos[index]
        updated.title = cleanedTitle
        updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.priority = priority
        updated.date = date
        updated.progress = progress
        updated.isWeekly = isWeekly
        updated.isDone = progress == .done
        updated.updatedAt = Date()

        do {
            try PerformanceMonitor.measure("TodoStore.updateTodo") {
                try update(updated)
                todos.remove(at: index)
                insertInMemory(updated)
                if updated.isWeekly && updated.progress == .done,
                   let nextTodo = try ensureNextWeeklyOccurrence(after: updated) {
                    insertInMemory(nextTodo)
                }
            }
            lastError = nil
        } catch {
            lastError = "保存待办数据失败：\(error.localizedDescription)"
        }
    }

    func toggle(_ todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }

        var updated = todos[index]
        updated.progress = updated.progress == .done ? .pending : .done
        updated.isDone = updated.progress == .done
        updated.updatedAt = Date()

        do {
            try PerformanceMonitor.measure("TodoStore.toggleTodo") {
                try update(updated)
                todos.remove(at: index)
                insertInMemory(updated)
                if updated.isWeekly && updated.progress == .done,
                   let nextTodo = try ensureNextWeeklyOccurrence(after: updated) {
                    insertInMemory(nextTodo)
                }
            }
            lastError = nil
        } catch {
            lastError = "保存待办数据失败：\(error.localizedDescription)"
        }
    }

    func delete(_ todo: TodoItem) {
        do {
            try PerformanceMonitor.measure("TodoStore.deleteTodo") {
                try delete(id: todo.id)
                todos.removeAll { $0.id == todo.id }
            }
            lastError = nil
        } catch {
            lastError = "删除待办失败：\(error.localizedDescription)"
        }
    }

    func restore(_ todo: TodoItem) {
        do {
            try PerformanceMonitor.measure("TodoStore.restoreTodo") {
                try insert(todo)
                todos.removeAll { $0.id == todo.id }
                insertInMemory(todo)
            }
            lastError = nil
        } catch {
            lastError = "恢复待办失败：\(error.localizedDescription)"
        }
    }

    func addHandbookItem(
        category: HandbookCategory,
        folder: String = "",
        title: String,
        body: String,
        attachments: [HandbookAttachment] = []
    ) {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty || !cleanedBody.isEmpty else { return }

        let item = HandbookItem(
            category: category,
            folder: folder.trimmingCharacters(in: .whitespacesAndNewlines),
            title: cleanedTitle.isEmpty ? category.title : cleanedTitle,
            body: cleanedBody,
            attachments: attachments
        )

        do {
            try PerformanceMonitor.measure("TodoStore.addHandbookItem") {
                try loadHandbookItemsIfNeededInternal()
                try insert(item)
                handbookItems.insert(item, at: handbookInsertionIndex(for: item))
            }
            lastError = nil
        } catch {
            lastError = "保存手记失败：\(error.localizedDescription)"
        }
    }

    func update(
        _ item: HandbookItem,
        category: HandbookCategory,
        folder: String,
        title: String,
        body: String,
        attachments: [HandbookAttachment]
    ) {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty || !cleanedBody.isEmpty else { return }
        guard let index = handbookItems.firstIndex(where: { $0.id == item.id }) else { return }

        var updated = handbookItems[index]
        updated.category = category
        updated.folder = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.title = cleanedTitle.isEmpty ? category.title : cleanedTitle
        updated.body = cleanedBody
        updated.attachments = attachments
        updated.updatedAt = Date()

        do {
            try PerformanceMonitor.measure("TodoStore.updateHandbookItem") {
                try loadHandbookItemsIfNeededInternal()
                try update(updated)
                handbookItems.remove(at: index)
                handbookItems.insert(updated, at: handbookInsertionIndex(for: updated))
            }
            lastError = nil
        } catch {
            lastError = "保存手记失败：\(error.localizedDescription)"
        }
    }

    func delete(_ item: HandbookItem) {
        do {
            try PerformanceMonitor.measure("TodoStore.deleteHandbookItem") {
                try loadHandbookItemsIfNeededInternal()
                try deleteHandbookItem(id: item.id)
                handbookItems.removeAll { $0.id == item.id }
            }
            lastError = nil
        } catch {
            lastError = "删除手记失败：\(error.localizedDescription)"
        }
    }

    func handbookItems(in category: HandbookCategory?, folder: String? = nil, matching query: String = "") -> [HandbookItem] {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return handbookItems.filter { item in
            (category == nil || item.category == category)
                && matchesFolder(item, folder: folder)
                && matches(item, cleanedQuery: cleanedQuery)
        }
    }

    func handbookFolders() -> [String] {
        let folders = Set(handbookItems.map(\.trimmedFolder).filter { !$0.isEmpty })
        return folders.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func todos(on date: Date, matching query: String = "") -> [TodoItem] {
        let day = calendar.startOfDay(for: date)
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return todos.filter { todo in
            calendar.isDate(todo.date, inSameDayAs: day) && matches(todo, cleanedQuery: cleanedQuery)
        }
    }

    func todos(matching query: String = "") -> [TodoItem] {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else { return todos }
        return todos.filter { matches($0, cleanedQuery: cleanedQuery) }
    }

    func pendingCount(on date: Date) -> Int {
        todos(on: date).filter { !$0.isDone }.count
    }

    func completedCount(on date: Date) -> Int {
        todos(on: date).filter(\.isDone).count
    }

    func datesWithTodos() -> [Date] {
        let days = Set(todos.map { calendar.startOfDay(for: $0.date) })
        return days.sorted(by: >)
    }

    private func openDatabase() throws {
        if db != nil { return }

        let directory = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            throw SQLiteStoreError.open(message: databaseErrorMessage)
        }

        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
    }

    private func prepareDatabase() throws {
        try openDatabase()
        guard !isDatabasePrepared else { return }

        try createSchema()
        try migrateLegacyJSONIfNeeded()
        isDatabasePrepared = true
    }

    private func loadStartupDataInternal() throws {
        let shouldSeedIfEmpty = !FileManager.default.fileExists(atPath: databaseURL.path)
            && !FileManager.default.fileExists(atPath: legacyJSONURL.path)
        try prepareDatabase()

        todos = try fetchTodos()
        if todos.isEmpty && shouldSeedIfEmpty {
            try insertInitialTodo()
            todos = try fetchTodos()
        }
        didLoadTodos = true
    }

    private func loadHandbookItemsIfNeededInternal() throws {
        guard !didLoadHandbookItems else { return }

        handbookLoadGeneration += 1
        isLoadingHandbookItems = false
        try prepareDatabase()
        handbookItems = try fetchHandbookItems()
        didLoadHandbookItems = true
    }

    private func createSchema() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS todos (
                id TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                notes TEXT NOT NULL DEFAULT '',
                priority TEXT NOT NULL,
                date REAL NOT NULL,
                progress TEXT NOT NULL DEFAULT 'pending',
                is_weekly INTEGER NOT NULL DEFAULT 0,
                is_done INTEGER NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
            """
        )
        try addColumnIfNeeded(table: "todos", name: "progress", definition: "TEXT NOT NULL DEFAULT 'pending'")
        try addColumnIfNeeded(table: "todos", name: "is_weekly", definition: "INTEGER NOT NULL DEFAULT 0")
        try execute("UPDATE todos SET progress = CASE WHEN is_done = 1 THEN 'done' ELSE 'pending' END WHERE progress IS NULL OR progress = ''")
        try execute("CREATE INDEX IF NOT EXISTS idx_todos_date ON todos(date)")
        try execute("CREATE INDEX IF NOT EXISTS idx_todos_progress_date ON todos(progress, date)")
        try execute("CREATE INDEX IF NOT EXISTS idx_todos_done_priority ON todos(is_done, priority)")
        try execute(
            """
            CREATE TABLE IF NOT EXISTS handbook_items (
                id TEXT PRIMARY KEY NOT NULL,
                category TEXT NOT NULL,
                folder TEXT NOT NULL DEFAULT '',
                title TEXT NOT NULL,
                body TEXT NOT NULL DEFAULT '',
                attachments_json TEXT NOT NULL DEFAULT '[]',
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
            """
        )
        try addColumnIfNeeded(table: "handbook_items", name: "folder", definition: "TEXT NOT NULL DEFAULT ''")
        try addColumnIfNeeded(table: "handbook_items", name: "attachments_json", definition: "TEXT NOT NULL DEFAULT '[]'")
        try execute("CREATE INDEX IF NOT EXISTS idx_handbook_category_updated ON handbook_items(category, updated_at)")
        try execute("CREATE INDEX IF NOT EXISTS idx_handbook_folder_updated ON handbook_items(folder, updated_at)")
    }

    private func migrateLegacyJSONIfNeeded() throws {
        guard try todoCount() == 0 else { return }
        guard FileManager.default.fileExists(atPath: legacyJSONURL.path) else { return }

        let data = try Data(contentsOf: legacyJSONURL)
        let legacyTodos = try JSONDecoder.todoDecoder.decode([TodoItem].self, from: data)
        guard !legacyTodos.isEmpty else { return }

        try execute("BEGIN TRANSACTION")
        do {
            for todo in legacyTodos {
                try insert(todo)
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func fetchTodos() throws -> [TodoItem] {
        let sql =
            """
            SELECT id, title, notes, priority, date, progress, is_weekly, is_done, created_at, updated_at
            FROM todos
            """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(message: databaseErrorMessage)
        }

        var result: [TodoItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(try todo(from: statement))
        }
        return result.sorted(by: sortTodos)
    }

    private func fetchHandbookItems() throws -> [HandbookItem] {
        let sql =
            """
            SELECT id, category, folder, title, body, attachments_json, created_at, updated_at
            FROM handbook_items
            """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(message: databaseErrorMessage)
        }

        var result: [HandbookItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(try handbookItem(from: statement))
        }
        return result.sorted(by: sortHandbookItems)
    }

    private func insertInitialTodo() throws {
        try insert(TodoItem(title: "写下今天最重要的三件事", notes: "用这个应用记录每天的待办事项。", date: Date()))
    }

    private func insert(_ todo: TodoItem) throws {
        let sql =
            """
            INSERT OR REPLACE INTO todos
            (id, title, notes, priority, date, progress, is_weekly, is_done, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        try withPreparedStatement(sql) { statement in
            bind(todo, to: statement)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SQLiteStoreError.execute(message: databaseErrorMessage)
            }
        }
    }

    private func insert(_ item: HandbookItem) throws {
        let sql =
            """
            INSERT OR REPLACE INTO handbook_items
            (id, category, folder, title, body, attachments_json, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """
        try withPreparedStatement(sql) { statement in
            bind(item, to: statement)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SQLiteStoreError.execute(message: databaseErrorMessage)
            }
        }
    }

    private func ensureNextWeeklyOccurrence(after todo: TodoItem) throws -> TodoItem? {
        guard let nextDate = calendar.date(byAdding: .day, value: 7, to: todo.date) else { return nil }
        let nextDay = calendar.startOfDay(for: nextDate)
        let alreadyExists = todos.contains { candidate in
            candidate.isWeekly
                && candidate.progress != .done
                && calendar.isDate(candidate.date, inSameDayAs: nextDay)
                && candidate.trimmedTitle == todo.trimmedTitle
        }
        guard !alreadyExists else { return nil }

        let nextTodo = TodoItem(
            title: todo.title,
            notes: todo.notes,
            priority: todo.priority,
            date: preserveTime(from: todo.date, on: nextDay),
            progress: .pending,
            isWeekly: true
        )
        try insert(nextTodo)
        return nextTodo
    }

    private func update(_ todo: TodoItem) throws {
        let sql =
            """
            UPDATE todos
            SET title = ?, notes = ?, priority = ?, date = ?, progress = ?, is_weekly = ?, is_done = ?, updated_at = ?
            WHERE id = ?
            """
        try withPreparedStatement(sql) { statement in
            bindText(todo.title, to: statement, at: 1)
            bindText(todo.notes, to: statement, at: 2)
            bindText(todo.priority.rawValue, to: statement, at: 3)
            sqlite3_bind_double(statement, 4, todo.date.timeIntervalSince1970)
            bindText(todo.progress.rawValue, to: statement, at: 5)
            sqlite3_bind_int(statement, 6, todo.isWeekly ? 1 : 0)
            sqlite3_bind_int(statement, 7, todo.progress == .done ? 1 : 0)
            sqlite3_bind_double(statement, 8, todo.updatedAt.timeIntervalSince1970)
            bindText(todo.id.uuidString, to: statement, at: 9)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SQLiteStoreError.execute(message: databaseErrorMessage)
            }
        }
    }

    private func update(_ item: HandbookItem) throws {
        let sql =
            """
            UPDATE handbook_items
            SET category = ?, folder = ?, title = ?, body = ?, attachments_json = ?, updated_at = ?
            WHERE id = ?
            """
        try withPreparedStatement(sql) { statement in
            bindText(item.category.rawValue, to: statement, at: 1)
            bindText(item.folder, to: statement, at: 2)
            bindText(item.title, to: statement, at: 3)
            bindText(item.body, to: statement, at: 4)
            bindText(attachmentsJSON(for: item.attachments), to: statement, at: 5)
            sqlite3_bind_double(statement, 6, item.updatedAt.timeIntervalSince1970)
            bindText(item.id.uuidString, to: statement, at: 7)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SQLiteStoreError.execute(message: databaseErrorMessage)
            }
        }
    }

    private func delete(id: UUID) throws {
        try withPreparedStatement("DELETE FROM todos WHERE id = ?") { statement in
            bindText(id.uuidString, to: statement, at: 1)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SQLiteStoreError.execute(message: databaseErrorMessage)
            }
        }
    }

    private func deleteHandbookItem(id: UUID) throws {
        try withPreparedStatement("DELETE FROM handbook_items WHERE id = ?") { statement in
            bindText(id.uuidString, to: statement, at: 1)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SQLiteStoreError.execute(message: databaseErrorMessage)
            }
        }
    }

    private func todoCount() throws -> Int {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM todos", -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(message: databaseErrorMessage)
        }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLiteStoreError.execute(message: databaseErrorMessage)
        }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteStoreError.execute(message: databaseErrorMessage)
        }
    }

    private func addColumnIfNeeded(table: String, name: String, definition: String) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table))", -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(message: databaseErrorMessage)
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let columnName = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
               columnName == name {
                return
            }
        }

        try execute("ALTER TABLE \(table) ADD COLUMN \(name) \(definition)")
    }

    private func withPreparedStatement(_ sql: String, _ body: (OpaquePointer?) throws -> Void) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(message: databaseErrorMessage)
        }
        try body(statement)
    }

    private func bind(_ todo: TodoItem, to statement: OpaquePointer?) {
        bindText(todo.id.uuidString, to: statement, at: 1)
        bindText(todo.title, to: statement, at: 2)
        bindText(todo.notes, to: statement, at: 3)
        bindText(todo.priority.rawValue, to: statement, at: 4)
        sqlite3_bind_double(statement, 5, todo.date.timeIntervalSince1970)
        bindText(todo.progress.rawValue, to: statement, at: 6)
        sqlite3_bind_int(statement, 7, todo.isWeekly ? 1 : 0)
        sqlite3_bind_int(statement, 8, todo.progress == .done ? 1 : 0)
        sqlite3_bind_double(statement, 9, todo.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 10, todo.updatedAt.timeIntervalSince1970)
    }

    private func bind(_ item: HandbookItem, to statement: OpaquePointer?) {
        bindText(item.id.uuidString, to: statement, at: 1)
        bindText(item.category.rawValue, to: statement, at: 2)
        bindText(item.folder, to: statement, at: 3)
        bindText(item.title, to: statement, at: 4)
        bindText(item.body, to: statement, at: 5)
        bindText(attachmentsJSON(for: item.attachments), to: statement, at: 6)
        sqlite3_bind_double(statement, 7, item.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 8, item.updatedAt.timeIntervalSince1970)
    }

    private func bindText(_ value: String, to statement: OpaquePointer?, at index: Int32) {
        sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
    }

    private func todo(from statement: OpaquePointer?) throws -> TodoItem {
        guard
            let idText = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
            let id = UUID(uuidString: idText),
            let title = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
            let notes = sqlite3_column_text(statement, 2).map({ String(cString: $0) }),
            let priorityText = sqlite3_column_text(statement, 3).map({ String(cString: $0) }),
            let progressText = sqlite3_column_text(statement, 5).map({ String(cString: $0) })
        else {
            throw SQLiteStoreError.decode
        }

        let priority = TodoPriority(rawValue: priorityText) ?? .medium
        let date = Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
        let legacyIsDone = sqlite3_column_int(statement, 7) == 1
        let progress = TodoProgress(rawValue: progressText) ?? (legacyIsDone ? .done : .pending)
        let isWeekly = sqlite3_column_int(statement, 6) == 1
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 8))
        let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 9))

        return TodoItem(
            id: id,
            title: title,
            notes: notes,
            priority: priority,
            date: date,
            progress: progress,
            isWeekly: isWeekly,
            isDone: progress == .done,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func handbookItem(from statement: OpaquePointer?) throws -> HandbookItem {
        guard
            let idText = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
            let id = UUID(uuidString: idText),
            let categoryText = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
            let folder = sqlite3_column_text(statement, 2).map({ String(cString: $0) }),
            let title = sqlite3_column_text(statement, 3).map({ String(cString: $0) }),
            let body = sqlite3_column_text(statement, 4).map({ String(cString: $0) }),
            let attachmentsJSON = sqlite3_column_text(statement, 5).map({ String(cString: $0) })
        else {
            throw SQLiteStoreError.decode
        }

        return HandbookItem(
            id: id,
            category: HandbookCategory(rawValue: categoryText) ?? .inspiration,
            folder: folder,
            title: title,
            body: body,
            attachments: decodeAttachments(from: attachmentsJSON),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))
        )
    }

    private var databaseErrorMessage: String {
        guard let message = sqlite3_errmsg(db) else {
            return "unknown SQLite error"
        }
        return String(cString: message)
    }

    private func matches(_ todo: TodoItem, cleanedQuery: String) -> Bool {
        guard !cleanedQuery.isEmpty else { return true }
        return todo.title.localizedCaseInsensitiveContains(cleanedQuery)
            || todo.notes.localizedCaseInsensitiveContains(cleanedQuery)
    }

    private func matches(_ item: HandbookItem, cleanedQuery: String) -> Bool {
        guard !cleanedQuery.isEmpty else { return true }
        return item.title.localizedCaseInsensitiveContains(cleanedQuery)
            || item.body.localizedCaseInsensitiveContains(cleanedQuery)
            || item.folder.localizedCaseInsensitiveContains(cleanedQuery)
            || item.category.title.localizedCaseInsensitiveContains(cleanedQuery)
            || item.attachments.contains { $0.name.localizedCaseInsensitiveContains(cleanedQuery) }
    }

    private func matchesFolder(_ item: HandbookItem, folder: String?) -> Bool {
        guard let folder, !folder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        return item.trimmedFolder == folder.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func attachmentsJSON(for attachments: [HandbookAttachment]) -> String {
        guard let data = try? JSONEncoder.todoEncoder.encode(attachments),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func decodeAttachments(from json: String) -> [HandbookAttachment] {
        guard let data = json.data(using: .utf8),
              let attachments = try? JSONDecoder.todoDecoder.decode([HandbookAttachment].self, from: data) else {
            return []
        }
        return attachments
    }

    private func insertionIndex(for item: TodoItem) -> Int {
        todos.firstIndex { sortTodos(item, $0) } ?? todos.endIndex
    }

    private func insertInMemory(_ item: TodoItem) {
        todos.insert(item, at: insertionIndex(for: item))
    }

    private func handbookInsertionIndex(for item: HandbookItem) -> Int {
        handbookItems.firstIndex { sortHandbookItems(item, $0) } ?? handbookItems.endIndex
    }

    private func preserveTime(from source: Date, on targetDay: Date) -> Date {
        var targetComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
        let sourceComponents = calendar.dateComponents([.hour, .minute, .second], from: source)
        targetComponents.hour = sourceComponents.hour
        targetComponents.minute = sourceComponents.minute
        targetComponents.second = sourceComponents.second
        return calendar.date(from: targetComponents) ?? targetDay
    }

    private func sortTodos(_ lhs: TodoItem, _ rhs: TodoItem) -> Bool {
        if !calendar.isDate(lhs.date, inSameDayAs: rhs.date) {
            return lhs.date > rhs.date
        }
        if lhs.isDone != rhs.isDone {
            return !lhs.isDone
        }
        let lhsHasTime = !calendar.isDate(lhs.date, equalTo: calendar.startOfDay(for: lhs.date), toGranularity: .minute)
        let rhsHasTime = !calendar.isDate(rhs.date, equalTo: calendar.startOfDay(for: rhs.date), toGranularity: .minute)
        if lhsHasTime != rhsHasTime {
            return lhsHasTime
        }
        if lhsHasTime && rhsHasTime && !calendar.isDate(lhs.date, equalTo: rhs.date, toGranularity: .minute) {
            return lhs.date < rhs.date
        }
        if lhs.priority != rhs.priority {
            return lhs.priority.sortRank < rhs.priority.sortRank
        }
        return lhs.createdAt < rhs.createdAt
    }

    private func sortHandbookItems(_ lhs: HandbookItem, _ rhs: HandbookItem) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.createdAt > rhs.createdAt
    }
}

private enum SQLiteStoreError: LocalizedError {
    case open(message: String)
    case prepare(message: String)
    case execute(message: String)
    case decode

    var errorDescription: String? {
        switch self {
        case .open(let message):
            return "打开 SQLite 数据库失败：\(message)"
        case .prepare(let message):
            return "准备 SQLite 语句失败：\(message)"
        case .execute(let message):
            return "执行 SQLite 语句失败：\(message)"
        case .decode:
            return "解析 SQLite 数据失败"
        }
    }
}

private enum HandbookSQLiteBackgroundReader {
    static func fetchHandbookItems(databaseURL: URL) throws -> [HandbookItem] {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }

        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &db, flags, nil) == SQLITE_OK else {
            throw SQLiteStoreError.open(message: databaseErrorMessage(for: db))
        }

        sqlite3_busy_timeout(db, 2_000)

        let sql =
            """
            SELECT id, category, folder, title, body, attachments_json, created_at, updated_at
            FROM handbook_items
            ORDER BY updated_at DESC, created_at DESC
            """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepare(message: databaseErrorMessage(for: db))
        }

        var result: [HandbookItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(try handbookItem(from: statement))
        }
        return result
    }

    private static func handbookItem(from statement: OpaquePointer?) throws -> HandbookItem {
        guard
            let idText = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
            let id = UUID(uuidString: idText),
            let categoryText = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
            let folder = sqlite3_column_text(statement, 2).map({ String(cString: $0) }),
            let title = sqlite3_column_text(statement, 3).map({ String(cString: $0) }),
            let body = sqlite3_column_text(statement, 4).map({ String(cString: $0) }),
            let attachmentsJSON = sqlite3_column_text(statement, 5).map({ String(cString: $0) })
        else {
            throw SQLiteStoreError.decode
        }

        return HandbookItem(
            id: id,
            category: HandbookCategory(rawValue: categoryText) ?? .inspiration,
            folder: folder,
            title: title,
            body: body,
            attachments: decodeAttachments(from: attachmentsJSON),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))
        )
    }

    private static func decodeAttachments(from json: String) -> [HandbookAttachment] {
        guard let data = json.data(using: .utf8),
              let attachments = try? JSONDecoder.todoDecoder.decode([HandbookAttachment].self, from: data) else {
            return []
        }
        return attachments
    }

    private static func databaseErrorMessage(for db: OpaquePointer?) -> String {
        guard let message = sqlite3_errmsg(db) else {
            return "unknown SQLite error"
        }
        return String(cString: message)
    }
}

private extension JSONDecoder {
    static var todoDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var todoEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
