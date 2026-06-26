// 性能基准测试工具(独立实现,衡量算法层性能差异)
//
// 用法: swift run daily-todos-bench
//
// 衡量 DailyTodos 关键算法路径的耗时,输出可对比的 baseline 数据:
//   - SQLite PRAGMA 优化前后写入吞吐
//   - dashboardGroups 计算 O(N²) vs O(N) Set 优化
//   - insertInMemory 双重 O(N) vs 原地更新
//   - 行视图 Equatable 短路
//   - 日期格式化 DateFormatter 缓存效果
//
// 输出格式: `<场景> → 平均 ms ± stddev ms [run1, run2, ...]`

import Foundation
import SQLite3

@main
struct DailyTodosBench {
    static func main() {
        let benchmarks: [(String, () -> Void)] = [
            ("SQLite 写入: 默认 synchronous=FULL", benchSQLiteWriteFullSync),
            ("SQLite 写入: synchronous=NORMAL+WAL优化", benchSQLiteWriteOptimized),
            ("dashboardGroups O(N²) contains(where:)", benchDashboardGroupsOversquared),
            ("dashboardGroups O(N) Set 优化", benchDashboardGroupsSetOptimized),
            ("insertInMemory 双重 O(N) remove+insert", benchInsertInMemoryDoubleScan),
            ("insertInMemory 原地更新 todos[index]=", benchInsertInMemoryInPlace),
            ("行视图 Equatable 短路 diff", benchRowEquatableShortCircuit),
            ("DateFormatter 反复构造(每行一次)", benchDateFormatterRecreate),
            ("DateFormatter 缓存(static let)", benchDateFormatterCached)
        ]

        print("DailyTodos 性能基准测试")
        print("============================================================")
        print("CPU: \(ProcessInfo.processInfo.activeProcessorCount) 核 | 内存: \(ProcessInfo.processInfo.physicalMemory / 1024 / 1024) MB")
        print("------------------------------------------------------------")
        for (name, benchmark) in benchmarks {
            bench(name, benchmark)
        }
        print("============================================================")
    }

    static func bench(_ name: String, _ operation: () -> Void) {
        operation()  // 预热 1 次
        var durations: [Double] = []
        for _ in 0..<5 {
            let start = ContinuousClock.now
            operation()
            let elapsed = start.duration(to: .now)
            durations.append(Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000)
        }
        let avg = durations.reduce(0, +) / Double(durations.count)
        let variance = durations.map { pow($0 - avg, 2) }.reduce(0, +) / Double(durations.count)
        let stddev = sqrt(variance)
        let durationStrings = durations.map { String(format: "%.2f", $0) }.joined(separator: ", ")
        print("\(name) → \(String(format: "%7.2f", avg)) ± \(String(format: "%5.2f", stddev)) ms  [\(durationStrings)]")
    }

    // MARK: - SQLite 写入吞吐对比

    static func openDatabase(at url: URL, pragmas: [String]) -> OpaquePointer? {
        var db: OpaquePointer?
        sqlite3_open(url.path, &db)
        for pragma in pragmas {
            sqlite3_exec(db, pragma, nil, nil, nil)
        }
        sqlite3_exec(db, """
            CREATE TABLE IF NOT EXISTS todos (
                id TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                date REAL NOT NULL,
                updated_at REAL NOT NULL
            )
            """, nil, nil, nil)
        return db
    }

    static func benchSQLiteWriteFullSync() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bench-full-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let db = openDatabase(at: url, pragmas: [
            "PRAGMA journal_mode = WAL",
            "PRAGMA foreign_keys = ON"
        ])
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO todos (id, title, date, updated_at) VALUES (?, ?, ?, ?)", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }

        let now = Date().timeIntervalSince1970
        for i in 0..<500 {
            sqlite3_reset(stmt)
            sqlite3_bind_text(stmt, 1, "id-\(i)", -1, nil)
            sqlite3_bind_text(stmt, 2, "待办 #\(i)", -1, nil)
            sqlite3_bind_double(stmt, 3, now)
            sqlite3_bind_double(stmt, 4, now)
            sqlite3_step(stmt)
        }
    }

    static func benchSQLiteWriteOptimized() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bench-opt-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let db = openDatabase(at: url, pragmas: [
            "PRAGMA journal_mode = WAL",
            "PRAGMA synchronous = NORMAL",      // WAL 下 NORMAL 足够安全,跳过 fsync
            "PRAGMA temp_store = MEMORY",        // 临时表/索引放内存
            "PRAGMA cache_size = -20000",        // 20MB 页缓存
            "PRAGMA mmap_size = 268435456",      // 256MB mmap
            "PRAGMA wal_autocheckpoint = 256",   // 减少 checkpoint 抖动
            "PRAGMA busy_timeout = 2000",        // 主连接也设忙等待
            "PRAGMA foreign_keys = ON"
        ])
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO todos (id, title, date, updated_at) VALUES (?, ?, ?, ?)", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }

        let now = Date().timeIntervalSince1970
        for i in 0..<500 {
            sqlite3_reset(stmt)
            sqlite3_bind_text(stmt, 1, "id-\(i)", -1, nil)
            sqlite3_bind_text(stmt, 2, "待办 #\(i)", -1, nil)
            sqlite3_bind_double(stmt, 3, now)
            sqlite3_bind_double(stmt, 4, now)
            sqlite3_step(stmt)
        }
    }

    // MARK: - dashboardGroups O(N²) vs O(N) Set

    struct FakeTodo: Identifiable {
        let id = UUID()
        let date: Date
        let progress: String
        let isWeekly: Bool
        let isDone: Bool
    }

    static func makeFakeTodos(count: Int) -> [FakeTodo] {
        let calendar = Calendar.current
        return (0..<count).map { i in
            FakeTodo(
                date: calendar.date(byAdding: .day, value: -i / 10, to: Date())!,
                progress: i % 4 == 0 ? "waiting" : "pending",
                isWeekly: i % 5 == 0,
                isDone: i % 7 == 0
            )
        }
    }

    static func benchDashboardGroupsOversquared() {
        // 复刻原 TodoListView.dashboardGroups 的 O(N²) 实现
        let todos = makeFakeTodos(count: 1000)
        let active = todos.filter { !$0.isDone }
        let overdue = active.filter { $0.date < Date() }
        let today = active.filter { Calendar.current.isDateInToday($0.date) }
        let waiting = active.filter { $0.progress == "waiting" }
        _ = active.filter { todo in
            todo.isWeekly
                && !overdue.contains(where: { $0.id == todo.id })
                && !today.contains(where: { $0.id == todo.id })
                && !waiting.contains(where: { $0.id == todo.id })
        }
    }

    static func benchDashboardGroupsSetOptimized() {
        // 优化版:用 Set<UUID> O(1) 查找
        let todos = makeFakeTodos(count: 1000)
        let active = todos.filter { !$0.isDone }
        let overdue = active.filter { $0.date < Date() }
        let today = active.filter { Calendar.current.isDateInToday($0.date) }
        let waiting = active.filter { $0.progress == "waiting" }
        let overdueIDs = Set(overdue.map(\.id))
        let todayIDs = Set(today.map(\.id))
        let waitingIDs = Set(waiting.map(\.id))
        _ = active.filter { todo in
            todo.isWeekly
                && !overdueIDs.contains(todo.id)
                && !todayIDs.contains(todo.id)
                && !waitingIDs.contains(todo.id)
        }
    }

    // MARK: - insertInMemory 双重 O(N) vs 原地更新

    struct SortableItem: Identifiable, Equatable {
        let id = UUID()
        var title: String
        var isDone: Bool
        let date: Date
    }

    static func makeSortableItems(count: Int) -> [SortableItem] {
        (0..<count).map { SortableItem(title: "item-\($0)", isDone: $0 % 2 == 0, date: Date()) }
    }

    static func benchInsertInMemoryDoubleScan() {
        // 模拟原 TodoStore.toggle: remove(at:) + insertInMemory(firstIndex + insert)
        var todos = makeSortableItems(count: 1000)
        let toggleIDs = Set(todos.prefix(100).map(\.id))
        for _ in 0..<1 {
            for id in toggleIDs {
                guard let index = todos.firstIndex(where: { $0.id == id }) else { continue }
                var updated = todos[index]
                updated.isDone.toggle()
                todos.remove(at: index)
                let insertIndex = todos.firstIndex { updated.title < $0.title } ?? todos.endIndex
                todos.insert(updated, at: insertIndex)
            }
        }
    }

    static func benchInsertInMemoryInPlace() {
        // 优化版:当 sort key 未变时直接 todos[index] = updated
        var todos = makeSortableItems(count: 1000)
        let toggleIDs = Set(todos.prefix(100).map(\.id))
        for _ in 0..<1 {
            for id in toggleIDs {
                guard let index = todos.firstIndex(where: { $0.id == id }) else { continue }
                var updated = todos[index]
                updated.isDone.toggle()
                // sort key 是 title+date,isDone 不参与排序 → 原地更新
                todos[index] = updated
            }
        }
    }

    // MARK: - 行视图 Equatable 短路

    static func benchRowEquatableShortCircuit() {
        // 模拟 SwiftUI diff:对 1000 个元素,仅 1 条变化
        // Equatable 短路:只对 1 条重新求 body,其余 999 条跳过
        let oldTodos = makeSortableItems(count: 1000)
        var newTodos = oldTodos
        if let index = newTodos.indices.first {
            newTodos[index].isDone.toggle()
        }
        var diffCount = 0
        for (old, new) in zip(oldTodos, newTodos) {
            if old != new { diffCount += 1 }
        }
        _ = diffCount
    }

    // MARK: - DateFormatter 缓存

    static func benchDateFormatterRecreate() {
        // 反模式:每次调用都构造新的 DateFormatter
        let dates = (0..<1000).map { _ in Date() }
        for date in dates {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            _ = formatter.string(from: date)
        }
    }

    static func benchDateFormatterCached() {
        // 优化:static let 缓存
        let dates = (0..<1000).map { _ in Date() }
        for date in dates {
            _ = Self.cachedFormatter.string(from: date)
        }
    }

    static let cachedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
