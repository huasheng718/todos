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

/// 凭证微应用模块
@MainActor
struct CredentialsAppModule: AppModule {
    let id = "credentials"
    let displayName = "凭证"
    let icon = "key.fill"
    let isDefault = true
    let description = "管理个人账号、密码、Key 和证书"

    var navigationView: AnyView {
        AnyView(EmptyView())
    }

    var contentView: AnyView {
        AnyView(CredentialsModuleView())
    }
}

struct SettingsAppModule: AppModule {
    let id = "settings"
    let displayName = "设置"
    let icon = "gearshape"
    let isDefault = true
    let description = "管理外观、AI、更新、模块和安全配置"
}
