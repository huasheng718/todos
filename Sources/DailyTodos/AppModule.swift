import SwiftUI

/// 微应用模块协议
/// 每个模块是一个独立的功能单元，可以安装/卸载
protocol AppModule: Identifiable {
    /// 模块唯一标识
    var id: String { get }
    /// 显示名称
    var displayName: String { get }
    /// SF Symbol 图标名
    var icon: String { get }
    /// 是否默认安装（不可卸载）
    var isDefault: Bool { get }
    /// 模块描述
    var description: String { get }
}

/// 微应用注册中心
/// 管理已注册和已安装的模块，持久化安装状态到 UserDefaults
@MainActor
final class AppModuleRegistry: ObservableObject {
    static let installedModulesKey = "AppModuleRegistry.installedModuleIDs"

    @Published private(set) var registeredModules: [any AppModule]
    @Published var installedModuleIDs: Set<String>
    @Published var activeModuleID: String

    init() {
        // 注册内置模块
        let modules: [any AppModule] = [
            TodoAppModule(),
            HandbookAppModule(),
            CredentialsAppModule(),
            SettingsAppModule(),
            AccountAppModule()
        ]

        // 从 UserDefaults 读取已安装模块
        let savedIDs = UserDefaults.standard.stringArray(forKey: Self.installedModulesKey) ?? []
        let defaultIDs = modules.filter { $0.isDefault }.map { $0.id }
        let installed: Set<String>
        if savedIDs.isEmpty {
            // 首次启动，安装所有默认模块
            installed = Set(defaultIDs)
        } else {
            installed = Set(savedIDs).union(defaultIDs)
        }

        registeredModules = modules
        installedModuleIDs = installed

        let requestedInitialModuleID = ProcessInfo.processInfo.environment["DAILY_TODOS_UIQA_MODULE"]

        // 激活第一个按注册顺序安装的模块，避免 Set.first 带来的启动页随机性。
        activeModuleID = modules.first(where: { $0.id == requestedInitialModuleID && installed.contains($0.id) })?.id
            ?? modules.first(where: { installed.contains($0.id) })?.id
            ?? modules.first!.id

        if !savedIDs.isEmpty, installed != Set(savedIDs) {
            persistInstalledModules(installed)
        }
    }

    /// 已安装的模块（按注册顺序）
    var installedModules: [any AppModule] {
        registeredModules.filter { installedModuleIDs.contains($0.id) }
    }

    /// 当前激活的模块
    var activeModule: (any AppModule)? {
        registeredModules.first { $0.id == activeModuleID }
    }

    /// 安装模块
    func install(_ moduleID: String) {
        installedModuleIDs.insert(moduleID)
        persistInstalledModules(installedModuleIDs)
    }

    /// 卸载模块（默认模块不可卸载）
    func uninstall(_ moduleID: String) {
        guard let module = registeredModules.first(where: { $0.id == moduleID }),
              !module.isDefault else { return }
        installedModuleIDs.remove(moduleID)
        persistInstalledModules(installedModuleIDs)

        // 如果卸载的是当前激活模块，切换到第一个已安装模块
        if activeModuleID == moduleID {
            activeModuleID = installedModules.first?.id ?? ""
        }
    }

    /// 切换激活模块
    func activate(_ moduleID: String) {
        guard installedModuleIDs.contains(moduleID) else { return }
        activeModuleID = moduleID
    }

    /// 检查模块是否已安装
    func isInstalled(_ moduleID: String) -> Bool {
        installedModuleIDs.contains(moduleID)
    }

    private func persistInstalledModules(_ installed: Set<String>) {
        let orderedIDs = registeredModules.map(\.id).filter { installed.contains($0) }
        UserDefaults.standard.set(orderedIDs, forKey: Self.installedModulesKey)
    }
}
