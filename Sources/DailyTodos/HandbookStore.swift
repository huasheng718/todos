import Foundation
import SQLite3

@MainActor
final class HandbookStore: ObservableObject {
    @Published private(set) var handbookItems: [HandbookItem] = []
    @Published private(set) var lastError: String?
    @Published private(set) var didLoadHandbookItems = false
    @Published private(set) var isLoadingHandbookItems = false

    private let databaseURL: URL
    private var isDatabasePrepared = false
    private var handbookLoadGeneration = 0
    nonisolated(unsafe) private var db: OpaquePointer?

    init(storageURL: URL? = nil) {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let appDirectory = baseURL.appendingPathComponent("DailyTodos", isDirectory: true)

        if let storageURL {
            databaseURL = storageURL
        } else {
            databaseURL = appDirectory.appendingPathComponent("todos.sqlite")
        }
    }

    deinit {
        sqlite3_close(db)
    }

    func loadHandbookItemsIfNeeded() {
        guard !didLoadHandbookItems else { return }

        do {
            try PerformanceMonitor.measure("HandbookStore.loadHandbookItems") {
                try loadHandbookItemsIfNeededInternal()
            }
            lastError = nil
        } catch {
            lastError = "读取手记数据失败：\(error.localizedDescription)"
        }
    }

    func reloadHandbookItems() {
        do {
            try PerformanceMonitor.measure("HandbookStore.reloadHandbookItems") {
                didLoadHandbookItems = false
                try loadHandbookItemsIfNeededInternal()
            }
            lastError = nil
        } catch {
            lastError = "刷新手记数据失败：\(error.localizedDescription)"
        }
    }

    func scheduleLoadHandbookItemsIfNeeded() {
        scheduleLoadHandbookItemsIfNeeded(after: nil)
    }

    @discardableResult
    func addHandbookItem(
        category: HandbookCategory,
        folder: String = "",
        title: String,
        body: String,
        attachments: [HandbookAttachment] = []
    ) -> HandbookItem? {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty || !cleanedBody.isEmpty || !attachments.isEmpty else { return nil }

        let item = HandbookItem(
            category: category,
            folder: folder.trimmingCharacters(in: .whitespacesAndNewlines),
            title: cleanedTitle,
            body: cleanedBody,
            attachments: attachments
        )

        do {
            try PerformanceMonitor.measure("HandbookStore.addHandbookItem") {
                try loadHandbookItemsIfNeededInternal()
                try insert(item)
                handbookItems.insert(item, at: handbookInsertionIndex(for: item))
            }
            lastError = nil
            return item
        } catch {
            lastError = "保存手记失败：\(error.localizedDescription)"
            return nil
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
        let cleanedFolder = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty || !cleanedBody.isEmpty || !attachments.isEmpty else { return }
        guard let index = handbookItems.firstIndex(where: { $0.id == item.id }) else { return }
        let current = handbookItems[index]
        guard current.category != category
            || current.trimmedFolder != cleanedFolder
            || current.trimmedTitle != cleanedTitle
            || current.trimmedBody != cleanedBody
            || current.attachments != attachments
        else { return }
        let didMoveScope = current.category != category || current.trimmedFolder != cleanedFolder

        var updated = current
        updated.category = category
        updated.folder = cleanedFolder
        updated.title = cleanedTitle
        updated.body = cleanedBody
        updated.attachments = attachments
        updated.updatedAt = Date()
        updated.dirtyFields = mergedDirtyFields(
            current.dirtyFields,
            dirtyFields(
                current: current,
                category: category,
                folder: cleanedFolder,
                title: cleanedTitle,
                body: cleanedBody,
                attachments: attachments
            )
        )

        do {
            try PerformanceMonitor.measure("HandbookStore.updateHandbookItem") {
                try loadHandbookItemsIfNeededInternal()
                try update(updated)
                if didMoveScope {
                    handbookItems.remove(at: index)
                    handbookItems.insert(updated, at: handbookInsertionIndex(for: updated))
                } else {
                    handbookItems[index] = updated
                }
            }
            lastError = nil
        } catch {
            lastError = "保存手记失败：\(error.localizedDescription)"
        }
    }

    func delete(_ item: HandbookItem) {
        do {
            try PerformanceMonitor.measure("HandbookStore.deleteHandbookItem") {
                try loadHandbookItemsIfNeededInternal()
                let current = handbookItems.first(where: { $0.id == item.id }) ?? item
                try deleteHandbookItem(current)
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
                        try PerformanceMonitor.measure("HandbookStore.loadHandbookItems.background") {
                            try HandbookSQLiteBackgroundReader.fetchHandbookItems(databaseURL: databaseURL)
                        }
                    }.value

                    finishScheduledHandbookLoad(items, generation: generation)
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

    private func openDatabase() throws {
        if db != nil { return }

        let directory = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            throw HandbookSQLiteStoreError.open(message: databaseErrorMessage)
        }

        sqlite3_busy_timeout(db, 2_000)

        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
    }

    private func prepareDatabase() throws {
        try openDatabase()
        guard !isDatabasePrepared else { return }

        try createSchema()
        isDatabasePrepared = true
    }

    private func loadHandbookItemsIfNeededInternal() throws {
        guard !didLoadHandbookItems else { return }

        handbookLoadGeneration += 1
        isLoadingHandbookItems = false
        try prepareDatabase()
        handbookItems = try fetchHandbookItems()
        didLoadHandbookItems = true
    }

    private func finishScheduledHandbookLoad(_ items: [HandbookItem], generation: Int) {
        guard generation == handbookLoadGeneration, !didLoadHandbookItems else { return }
        handbookItems = items
        didLoadHandbookItems = true
        isLoadingHandbookItems = false
        lastError = nil
    }

    private func createSchema() throws {
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
                updated_at REAL NOT NULL,
                remote_id TEXT,
                sync_version INTEGER NOT NULL DEFAULT 0,
                deleted_at REAL,
                dirty_fields_json TEXT NOT NULL DEFAULT '[]'
            )
            """
        )
        try addColumnIfNeeded(table: "handbook_items", name: "folder", definition: "TEXT NOT NULL DEFAULT ''")
        try addColumnIfNeeded(table: "handbook_items", name: "attachments_json", definition: "TEXT NOT NULL DEFAULT '[]'")
        try addColumnIfNeeded(table: "handbook_items", name: "remote_id", definition: "TEXT")
        try addColumnIfNeeded(table: "handbook_items", name: "sync_version", definition: "INTEGER NOT NULL DEFAULT 0")
        try addColumnIfNeeded(table: "handbook_items", name: "deleted_at", definition: "REAL")
        try addColumnIfNeeded(table: "handbook_items", name: "dirty_fields_json", definition: "TEXT NOT NULL DEFAULT '[]'")
        try execute("CREATE INDEX IF NOT EXISTS idx_handbook_category_updated ON handbook_items(category, updated_at)")
        try execute("CREATE INDEX IF NOT EXISTS idx_handbook_folder_updated ON handbook_items(folder, updated_at)")
        try execute("CREATE INDEX IF NOT EXISTS idx_handbook_updated_created ON handbook_items(updated_at DESC, created_at DESC)")
    }

    private func fetchHandbookItems() throws -> [HandbookItem] {
        let sql =
            """
            SELECT id, category, folder, title, body, attachments_json, created_at, updated_at,
                   remote_id, sync_version, deleted_at, dirty_fields_json
            FROM handbook_items
            WHERE deleted_at IS NULL
            ORDER BY updated_at DESC, created_at DESC
            """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HandbookSQLiteStoreError.prepare(message: databaseErrorMessage)
        }

        var result: [HandbookItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(try handbookItem(from: statement))
        }
        return result
    }

    private func insert(_ item: HandbookItem) throws {
        let sql =
            """
            INSERT OR REPLACE INTO handbook_items
            (id, category, folder, title, body, attachments_json, created_at, updated_at, remote_id, sync_version, deleted_at, dirty_fields_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        try withPreparedStatement(sql) { statement in
            bind(item, to: statement)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw HandbookSQLiteStoreError.execute(message: databaseErrorMessage)
            }
        }
    }

    private func update(_ item: HandbookItem) throws {
        let sql =
            """
            UPDATE handbook_items
            SET category = ?, folder = ?, title = ?, body = ?, attachments_json = ?, updated_at = ?, remote_id = ?, sync_version = ?, deleted_at = ?, dirty_fields_json = ?
            WHERE id = ?
            """
        try withPreparedStatement(sql) { statement in
            bindText(item.category.rawValue, to: statement, at: 1)
            bindText(item.folder, to: statement, at: 2)
            bindText(item.title, to: statement, at: 3)
            bindText(item.body, to: statement, at: 4)
            bindText(attachmentsJSON(for: item.attachments), to: statement, at: 5)
            sqlite3_bind_double(statement, 6, item.updatedAt.timeIntervalSince1970)
            bindOptionalText(item.remoteID, to: statement, at: 7)
            sqlite3_bind_int(statement, 8, Int32(item.syncVersion))
            bindOptionalDate(item.deletedAt, to: statement, at: 9)
            bindText(dirtyFieldsJSON(for: item.dirtyFields), to: statement, at: 10)
            bindText(item.id.uuidString, to: statement, at: 11)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw HandbookSQLiteStoreError.execute(message: databaseErrorMessage)
            }
        }
    }

    private func deleteHandbookItem(_ item: HandbookItem) throws {
        let deletedAt = Date()
        try withPreparedStatement(
            """
            UPDATE handbook_items
            SET deleted_at = ?, updated_at = ?, dirty_fields_json = ?
            WHERE id = ?
            """
        ) { statement in
            sqlite3_bind_double(statement, 1, deletedAt.timeIntervalSince1970)
            sqlite3_bind_double(statement, 2, deletedAt.timeIntervalSince1970)
            bindText(dirtyFieldsJSON(for: mergedDirtyFields(item.dirtyFields, ["deletedAt"])), to: statement, at: 3)
            bindText(item.id.uuidString, to: statement, at: 4)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw HandbookSQLiteStoreError.execute(message: databaseErrorMessage)
            }
        }
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw HandbookSQLiteStoreError.execute(message: databaseErrorMessage)
        }
    }

    private func addColumnIfNeeded(table: String, name: String, definition: String) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table))", -1, &statement, nil) == SQLITE_OK else {
            throw HandbookSQLiteStoreError.prepare(message: databaseErrorMessage)
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
            throw HandbookSQLiteStoreError.prepare(message: databaseErrorMessage)
        }
        try body(statement)
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
        bindOptionalText(item.remoteID, to: statement, at: 9)
        sqlite3_bind_int(statement, 10, Int32(item.syncVersion))
        bindOptionalDate(item.deletedAt, to: statement, at: 11)
        bindText(dirtyFieldsJSON(for: item.dirtyFields), to: statement, at: 12)
    }

    private func bindText(_ value: String, to statement: OpaquePointer?, at index: Int32) {
        sqlite3_bind_text(statement, index, value, -1, HANDBOOK_SQLITE_TRANSIENT)
    }

    private func bindOptionalText(_ value: String?, to statement: OpaquePointer?, at index: Int32) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        bindText(value, to: statement, at: index)
    }

    private func bindOptionalDate(_ value: Date?, to statement: OpaquePointer?, at index: Int32) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
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
            throw HandbookSQLiteStoreError.decode
        }

        return HandbookItem(
            id: id,
            category: HandbookCategory(rawValue: categoryText) ?? .inspiration,
            folder: folder,
            title: title,
            body: body,
            attachments: decodeAttachments(from: attachmentsJSON),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7)),
            remoteID: optionalText(from: statement, at: 8),
            syncVersion: Int(sqlite3_column_int(statement, 9)),
            deletedAt: optionalDate(from: statement, at: 10),
            dirtyFields: decodeDirtyFields(from: sqlite3_column_text(statement, 11).map { String(cString: $0) } ?? "[]")
        )
    }

    private var databaseErrorMessage: String {
        guard let message = sqlite3_errmsg(db) else {
            return "unknown SQLite error"
        }
        return String(cString: message)
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

    private func dirtyFields(
        current: HandbookItem,
        category: HandbookCategory,
        folder: String,
        title: String,
        body: String,
        attachments: [HandbookAttachment]
    ) -> [String] {
        var fields: [String] = []
        if current.category != category { fields.append("category") }
        if current.trimmedFolder != folder { fields.append("folder") }
        if current.trimmedTitle != title { fields.append("title") }
        if current.trimmedBody != body { fields.append("body") }
        if current.attachments != attachments { fields.append("attachments") }
        return fields
    }

    private func mergedDirtyFields(_ current: [String], _ changed: [String]) -> [String] {
        Array(Set(current + changed)).sorted()
    }

    private func attachmentsJSON(for attachments: [HandbookAttachment]) -> String {
        guard let data = try? JSONEncoder.handbookEncoder.encode(attachments),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func dirtyFieldsJSON(for fields: [String]) -> String {
        guard let data = try? JSONEncoder.handbookEncoder.encode(fields),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func decodeAttachments(from json: String) -> [HandbookAttachment] {
        guard let data = json.data(using: .utf8),
              let attachments = try? JSONDecoder.handbookDecoder.decode([HandbookAttachment].self, from: data) else {
            return []
        }
        return attachments
    }

    private func decodeDirtyFields(from json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let fields = try? JSONDecoder.handbookDecoder.decode([String].self, from: data) else {
            return []
        }
        return fields
    }

    private func optionalText(from statement: OpaquePointer?, at index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let value = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: value)
    }

    private func optionalDate(from statement: OpaquePointer?, at index: Int32) -> Date? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }

    private func handbookInsertionIndex(for item: HandbookItem) -> Int {
        handbookItems.firstIndex { sortHandbookItems(item, $0) } ?? handbookItems.endIndex
    }

    private func sortHandbookItems(_ lhs: HandbookItem, _ rhs: HandbookItem) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.createdAt > rhs.createdAt
    }
}

private enum HandbookSQLiteStoreError: LocalizedError {
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
            throw HandbookSQLiteStoreError.open(message: databaseErrorMessage(for: db))
        }

        sqlite3_busy_timeout(db, 2_000)

        let sql =
            """
            SELECT id, category, folder, title, body, attachments_json, created_at, updated_at,
                   remote_id, sync_version, deleted_at, dirty_fields_json
            FROM handbook_items
            WHERE deleted_at IS NULL
            ORDER BY updated_at DESC, created_at DESC
            """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HandbookSQLiteStoreError.prepare(message: databaseErrorMessage(for: db))
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
            throw HandbookSQLiteStoreError.decode
        }

        return HandbookItem(
            id: id,
            category: HandbookCategory(rawValue: categoryText) ?? .inspiration,
            folder: folder,
            title: title,
            body: body,
            attachments: decodeAttachments(from: attachmentsJSON),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7)),
            remoteID: optionalText(from: statement, at: 8),
            syncVersion: Int(sqlite3_column_int(statement, 9)),
            deletedAt: optionalDate(from: statement, at: 10),
            dirtyFields: decodeDirtyFields(from: sqlite3_column_text(statement, 11).map { String(cString: $0) } ?? "[]")
        )
    }

    private static func decodeAttachments(from json: String) -> [HandbookAttachment] {
        guard let data = json.data(using: .utf8),
              let attachments = try? JSONDecoder.handbookDecoder.decode([HandbookAttachment].self, from: data) else {
            return []
        }
        return attachments
    }

    private static func decodeDirtyFields(from json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let fields = try? JSONDecoder.handbookDecoder.decode([String].self, from: data) else {
            return []
        }
        return fields
    }

    private static func optionalText(from statement: OpaquePointer?, at index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let value = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: value)
    }

    private static func optionalDate(from statement: OpaquePointer?, at index: Int32) -> Date? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }

    private static func databaseErrorMessage(for db: OpaquePointer?) -> String {
        guard let message = sqlite3_errmsg(db) else {
            return "unknown SQLite error"
        }
        return String(cString: message)
    }
}

private extension JSONDecoder {
    static var handbookDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var handbookEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private let HANDBOOK_SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
