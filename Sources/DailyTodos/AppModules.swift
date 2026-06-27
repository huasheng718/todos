import SwiftUI

/// 待办微应用模块
struct TodoAppModule: AppModule {
    let id = "todos"
    let displayName = "待办"
    let icon = "checklist"
    let isDefault = true
    let description = "管理日常待办事项，支持优先级、进度、循环任务"
}

/// 手记微应用模块
struct HandbookAppModule: AppModule {
    let id = "handbook"
    let displayName = "手记"
    let icon = "book.closed"
    let isDefault = true
    let description = "沉淀业务规则、调研、会议纪要和灵感"
}
