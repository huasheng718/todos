import Foundation
import os

enum PerformanceMonitor {
    private static let logger = Logger(subsystem: "com.cukethink.DailyTodos", category: "Performance")
    private static let signposter = OSSignposter(subsystem: "com.cukethink.DailyTodos", category: "Performance")

    @discardableResult
    static func measure<T>(_ name: StaticString, _ operation: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval(name)
        let start = ContinuousClock.now
        defer {
            let elapsed = start.duration(to: .now)
            signposter.endInterval(name, state)
            logger.debug("\(String(describing: name), privacy: .public) finished in \(elapsed.description, privacy: .public)")
        }
        return try operation()
    }

    static func event(_ name: StaticString, detail: String = "") {
        signposter.emitEvent(name)
        if detail.isEmpty {
            logger.debug("\(String(describing: name), privacy: .public)")
        } else {
            logger.debug("\(String(describing: name), privacy: .public): \(detail, privacy: .public)")
        }
    }
}
