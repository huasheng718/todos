import SwiftUI

enum AppSettingsSection: String, CaseIterable, Identifiable {
    case account
    case appearance
    case credentials
    case ai
    case modules
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account: "账户"
        case .appearance: "外观"
        case .credentials: "凭证"
        case .ai: "AI"
        case .modules: "模块"
        case .updates: "更新"
        }
    }

    var subtitle: String {
        switch self {
        case .account: "空间、订阅、账单"
        case .appearance: "主题与视觉密度"
        case .credentials: "导入、备份、安全"
        case .ai: "DeepSeek 连接"
        case .modules: "功能边界"
        case .updates: "版本与下载"
        }
    }

    var icon: String {
        switch self {
        case .account: "person.crop.circle"
        case .appearance: "paintpalette.fill"
        case .credentials: "key.fill"
        case .ai: "sparkles"
        case .modules: "puzzlepiece.extension.fill"
        case .updates: "arrow.triangle.2.circlepath"
        }
    }
}

struct AppSettingsSheet: View {
    @EnvironmentObject private var updateController: UpdateController
    @EnvironmentObject private var moduleRegistry: AppModuleRegistry
    @EnvironmentObject private var aiSettings: AISettingsStore
    @EnvironmentObject private var credentialStore: CredentialStore
    @EnvironmentObject private var credentialActions: CredentialManagementActions
    @Binding var selectedSkinRawValue: String
    @Binding var selectedSection: AppSettingsSection
    @State private var isSecondarySidebarCollapsed = false

    var body: some View {
        HStack(spacing: 0) {
            SettingsContextSidebar(
                selectedSection: $selectedSection,
                isSecondarySidebarCollapsed: $isSecondarySidebarCollapsed
            )
                .environmentObject(updateController)
                .environmentObject(aiSettings)

            Divider()
                .overlay(AppTheme.hairline)

            SettingsModuleView(
                selectedSkinRawValue: $selectedSkinRawValue,
                selectedSection: $selectedSection
            )
            .environmentObject(updateController)
            .environmentObject(moduleRegistry)
            .environmentObject(aiSettings)
            .environmentObject(credentialStore)
            .environmentObject(credentialActions)
        }
        .frame(width: 920, height: 640)
        .background(AppTheme.workspaceSurface)
        .foregroundStyle(AppTheme.ink)
    }
}

struct SettingsContextSidebar: View {
    @EnvironmentObject private var updateController: UpdateController
    @EnvironmentObject private var aiSettings: AISettingsStore
    @Binding var selectedSection: AppSettingsSection
    @Binding var isSecondarySidebarCollapsed: Bool

    var body: some View {
        Group {
            if isSecondarySidebarCollapsed {
                CollapsedContextRail(title: "设置", isCollapsed: $isSecondarySidebarCollapsed)
                    .frame(width: collapsedSecondarySidebarWidth)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    WorkspaceContextHeader(
                        title: "设置",
                        subtitle: "外观、AI、更新、安全",
                        isCollapsed: $isSecondarySidebarCollapsed
                    )

                    Divider()
                        .overlay(AppTheme.hairline.opacity(0.72))

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(AppSettingsSection.allCases) { section in
                            Button {
                                withAnimation(AppMotion.smooth) {
                                    selectedSection = section
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: section.icon)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(selectedSection == section ? AppTheme.accent : AppTheme.mutedInk)
                                        .frame(width: 16)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(section.title)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(AppTheme.ink)
                                        Text(section.subtitle)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(selectedSection == section ? AppTheme.accent : AppTheme.mutedInk)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    if section == .ai {
                                        Circle()
                                            .fill(aiSettings.canUseAI ? AppTheme.success : AppTheme.mutedInk.opacity(0.36))
                                            .frame(width: 6, height: 6)
                                    } else if section == .updates, updateController.hasAvailableUpdate {
                                        Circle()
                                            .fill(TodoPriority.high.displayColor)
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 46)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .background(
                                    selectedSection == section ? AppTheme.sidebarSelected : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                        }
                    }
                    .padding(.top, 6)

                    Spacer(minLength: 0)

                    Text(AppVersion.displayText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .padding(18)
                }
                .frame(width: secondarySidebarWidth)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .background(AppTheme.workspaceSidebar)
            }
        }
    }
}

struct SettingsModuleView: View {
    @EnvironmentObject private var updateController: UpdateController
    @EnvironmentObject private var moduleRegistry: AppModuleRegistry
    @EnvironmentObject private var aiSettings: AISettingsStore
    @EnvironmentObject private var credentialStore: CredentialStore
    @EnvironmentObject private var credentialActions: CredentialManagementActions
    @Binding var selectedSkinRawValue: String
    @Binding var selectedSection: AppSettingsSection

    var body: some View {
        VStack(spacing: 0) {
            ContentHeader(title: selectedSection.title, subtitle: selectedSection.subtitle)
                .frame(height: WorkspaceChromeMetrics.headerHeight)

            Divider()
                .overlay(AppTheme.hairline)

            ScrollView {
                SettingsContentView(
                    selectedSkinRawValue: $selectedSkinRawValue,
                    selectedSection: $selectedSection
                )
                .padding(22)
            }
            .scrollIndicators(.visible)
            .background(AppTheme.workspaceSurface)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.workspaceTokens.contentSurface)
        .sheet(isPresented: $credentialActions.isBackupSheetPresented) {
            CredentialBackupSheet()
                .environmentObject(credentialStore)
        }
    }
}

private struct SettingsContentView: View {
    @EnvironmentObject private var updateController: UpdateController
    @EnvironmentObject private var moduleRegistry: AppModuleRegistry
    @EnvironmentObject private var aiSettings: AISettingsStore
    @EnvironmentObject private var credentialStore: CredentialStore
    @EnvironmentObject private var credentialActions: CredentialManagementActions
    @AppStorage(AppMotion.reduceMotionStorageKey) private var reduceMotion = false
    @Binding var selectedSkinRawValue: String
    @Binding var selectedSection: AppSettingsSection

    private var selectedSkin: AppSkin {
        AppSkin(rawValue: selectedSkinRawValue) ?? .ocean
    }

    private var skinColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    var body: some View {
        settingsContent
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selectedSection {
        case .account:
            accountSettings
        case .appearance:
            appearanceSettings
        case .credentials:
            credentialSettings
        case .ai:
            aiSettingsPanel
        case .modules:
            moduleSettings
        case .updates:
            updateSettings
        }
    }

    private var accountSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            AccountSettingsContent()
        }
    }

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsPanel(title: "皮肤", icon: "paintpalette.fill") {
                LazyVGrid(columns: skinColumns, alignment: .leading, spacing: 8) {
                    ForEach(AppSkin.allCases) { skin in
                        skinButton(skin)
                    }
                }
            }

            settingsPanel(title: "动态效果", icon: "figure.walk.motion") {
                Toggle(isOn: $reduceMotion) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("减少动态效果")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                        Text("降低弹簧、缩放和列表转场强度，优先保证稳定阅读。")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }
                .toggleStyle(.switch)
            }
        }
    }

    private var aiSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            AISettingsContentView()
        }
    }

    private var credentialSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsPanel(title: "凭证库", icon: "key.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        CredentialSettingsStatusBadge(
                            status: credentialStore.status,
                            requiresMasterPassword: credentialStore.requiresMasterPassword,
                            count: credentialStore.credentials.count
                        )

                        Spacer()

                        Toggle(isOn: Binding(
                            get: { credentialStore.requiresMasterPassword },
                            set: { value in
                                Task {
                                    await credentialActions.updateMasterPasswordRequirement(
                                        store: credentialStore,
                                        required: value
                                    )
                                }
                            }
                        )) {
                            Text("主密码验证")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .toggleStyle(.switch)
                        .disabled(!credentialStore.isUnlocked)
                    }

                    if let notice = credentialActions.notice {
                        Label(notice.message, systemImage: notice.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(notice.isError ? TodoPriority.high.displayColor : AppTheme.accent)
                    }

                    HStack(spacing: 10) {
                        credentialSettingsActionButton(
                            title: "导入",
                            icon: "folder",
                            isPrimary: true,
                            action: { credentialActions.importCredentialsFromFile(store: credentialStore) }
                        )
                        credentialSettingsActionButton(
                            title: "备份 / 恢复",
                            icon: "externaldrive.badge.checkmark",
                            action: { credentialActions.showBackupSheet(store: credentialStore) }
                        )
                    }
                    .disabled(!credentialStore.isUnlocked)

                    if credentialActions.securityMode != nil {
                        CredentialSecuritySettingsPane(
                            error: credentialStore.lastError,
                            onSave: { password, repeatedPassword in
                                Task {
                                    await credentialActions.enableMasterPassword(
                                        store: credentialStore,
                                        password: password,
                                        repeatedPassword: repeatedPassword
                                    )
                                }
                            },
                            onCancel: { credentialActions.clearTransientModes() }
                        )
                        .frame(minHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private var moduleSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsPanel(title: "已注册模块", icon: "puzzlepiece.extension.fill") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(moduleRegistry.registeredModules, id: \.id) { module in
                        ModuleManagementRow(
                            module: module,
                            isInstalled: moduleRegistry.isInstalled(module.id),
                            onInstall: { moduleRegistry.install(module.id) },
                            onUninstall: { moduleRegistry.uninstall(module.id) }
                        )
                    }
                }
            }
        }
    }

    private var updateSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsPanel(title: "版本状态", icon: "arrow.triangle.2.circlepath") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(updateStatusColor)
                                    .frame(width: 7, height: 7)
                                Text(AppVersion.displayText)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(AppTheme.ink)
                            }

                            Text(updateStatusText)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(updateController.isChecking || updateController.isDownloading ? AppTheme.ink : AppTheme.mutedInk)
                                .lineLimit(2)

                            if let lastCheckedAt = updateController.lastCheckedAt {
                                Text("上次检查 \(lastCheckedAt.formatted(date: .omitted, time: .shortened))")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.mutedInk)
                            }
                        }

                        Spacer()

                        updateActions
                    }

                    if updateController.isDownloading {
                        updateDownloadProgressView
                    }

                    updateReminderNote
                }
            }
        }
    }

    private func credentialSettingsActionButton(
        title: String,
        icon: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .bold))
                .frame(minWidth: 112, minHeight: 34)
        }
        .buttonStyle(.tactilePlain)
        .foregroundStyle(isPrimary ? .white : AppTheme.ink)
        .background(isPrimary ? AppTheme.accent : AppTheme.adaptiveWhite(0.72), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isPrimary ? AppTheme.adaptiveWhite(0.26) : AppTheme.hairline)
        )
    }

    private func settingsPanel<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.adaptiveWhite(0.76), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border.opacity(0.78))
        )
    }

    private func skinButton(_ skin: AppSkin) -> some View {
        let isSelected = skin == selectedSkin

        return Button {
            withAnimation(AppMotion.smooth) {
                activeAppSkin = skin
                selectedSkinRawValue = skin.rawValue
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: skin.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(skin.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(skin.shortTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppTheme.accentSoft : AppTheme.adaptiveWhite(0.78), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.24) : AppTheme.hairline)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.tactilePlain)
    }

    private var updateActions: some View {
        HStack(spacing: 8) {
            if updateController.availableUpdate != nil {
                Button {
                    updateController.downloadAvailableUpdate()
                } label: {
                    Label(updateController.isDownloading ? "下载中" : "下载", systemImage: updateController.isDownloading ? "arrow.down.circle.fill" : "arrow.down.to.line")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 78, height: 32)
                }
                .buttonStyle(.tactilePlain)
                .tactilePlainControlAppearance(
                    isDisabled: updateController.isDownloading,
                    enabledForeground: AppTheme.workspaceTokens.accentForeground,
                    enabledBackground: AppTheme.workspaceTokens.accent,
                    enabledBorder: AppTheme.workspaceTokens.accent
                )
                .disabled(updateController.isDownloading)
                .help("下载当前发现的新版本")
            }

            Button {
                updateController.checkForUpdates()
            } label: {
                Label(updateController.isChecking ? "检查中" : "检查更新", systemImage: updateController.isChecking ? "clock.arrow.circlepath" : "arrow.down.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 104, height: 32)
            }
            .buttonStyle(.tactilePlain)
            .tactilePlainControlAppearance(
                isDisabled: updateController.isChecking || updateController.isDownloading,
                enabledForeground: AppTheme.workspaceTokens.accentForeground,
                enabledBackground: AppTheme.workspaceTokens.accent,
                enabledBorder: AppTheme.workspaceTokens.accent
            )
            .disabled(updateController.isChecking || updateController.isDownloading)
            .help("检查更新")
        }
    }

    private var updateStatusText: String {
        if updateController.isChecking {
            return "正在检查远程版本..."
        }
        if updateController.isDownloading {
            if let progress = updateController.downloadProgress {
                return "正在下载更新 \(progress.statusText)"
            }
            return "正在连接下载服务..."
        }
        if let update = updateController.availableUpdate {
            return "可更新到 v\(update.version) (\(update.build))，设置入口会持续显示红点。"
        }
        return updateController.statusMessage ?? "每天自动检查一次，也可以手动检查。"
    }

    private var updateStatusColor: Color {
        if updateController.isChecking {
            return AppTheme.accentWarm
        }
        if updateController.isDownloading {
            return AppTheme.accentWarm
        }
        if updateController.availableUpdate != nil {
            return AppTheme.accent
        }
        if let message = updateController.statusMessage, message.contains("失败") || message.contains("没有发布") || message.contains("无效") {
            return TodoPriority.medium.displayColor
        }
        return AppTheme.success
    }

    @ViewBuilder
    private var updateDownloadProgressView: some View {
        let progress = updateController.downloadProgress

        VStack(alignment: .leading, spacing: 7) {
            if let fraction = progress?.fractionCompleted {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .tint(AppTheme.accentWarm)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(AppTheme.accentWarm)
            }

            HStack(spacing: 8) {
                Text(progress?.percentText ?? "下载中")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.ink)
                Text(progress?.detailText ?? "正在获取文件大小")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.adaptiveWhite(0.70), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.accentWarm.opacity(0.24))
        )
    }

    private var updateReminderNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bell.badge")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(updateController.availableUpdate == nil ? AppTheme.mutedInk : TodoPriority.high.displayColor)
                .frame(width: 16)

            Text("提醒机制：启动和回到前台会自动检查；应用长期打开时每小时轮询一次，最多每天检查一次远端版本。发现新版本后，设置入口显示红点；自动弹窗按版本与时间节流，手动检查始终反馈结果。")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.adaptiveWhite(0.62), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.72))
        )
    }
}

struct AISettingsContentView: View {
    @EnvironmentObject private var aiSettings: AISettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsCard
            usageSection
        }
        .foregroundStyle(AppTheme.ink)
    }

    private var settingsCard: some View {
        HStack(alignment: .top, spacing: 16) {
            statusPanel

            VStack(alignment: .leading, spacing: 12) {
                Text("连接配置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)

                LabeledContent("供应商") {
                    providerPill
                }

                LabeledContent("API 地址") {
                    AISettingsTextField("https://api.deepseek.com", text: $aiSettings.configuration.baseURL)
                }

                LabeledContent("模型") {
                    VStack(alignment: .leading, spacing: 5) {
                        DeepSeekModelPicker(model: $aiSettings.configuration.model)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(currentModelSubtitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                LabeledContent("API Key") {
                    SecureField("sk-...", text: $aiSettings.apiKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .background(AppTheme.adaptiveWhite(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(aiSettings.hasAPIKey ? AppTheme.success.opacity(0.36) : AppTheme.border)
                        )
                }

                securityNote

                if let trace = aiSettings.lastTrace {
                    AITraceDisclosure(trace: trace, isExpanded: .constant(true))
                }
            }
            .labeledContentStyle(AISettingsLabeledContentStyle())
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.border)
        )
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(aiSettings.configuration.isEnabled ? AppTheme.accent : AppTheme.mutedInk.opacity(0.22))
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(aiSettings.configuration.isEnabled ? "AI 已启用" : "AI 未启用")
                        .font(.system(size: 16, weight: .semibold))
                    Text(statusSubtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle(isOn: $aiSettings.configuration.isEnabled) {
                Text("启用 DeepSeek")
                    .font(.system(size: 13, weight: .semibold))
            }
            .toggleStyle(.switch)

            connectionControls
        }
        .padding(14)
        .frame(width: 210, alignment: .topLeading)
        .background(statusBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(statusStroke)
        )
    }

    private var statusSubtitle: String {
        if !aiSettings.configuration.isEnabled {
            return "填写密钥并打开开关后，快记和建议会调用 DeepSeek。"
        }
        if !aiSettings.hasAPIKey {
            return "还缺 API Key，当前不会发起 AI 请求。"
        }
        return aiSettings.connectionSucceeded ? "连接已验证，可用于当前工作流。" : "配置已就绪，建议先测试连接。"
    }

    private var statusBackground: Color {
        if aiSettings.connectionSucceeded {
            return AppTheme.successSoft
        }
        return aiSettings.configuration.isEnabled ? AppTheme.accentSoft : AppTheme.adaptiveWhite(0.78)
    }

    private var statusStroke: Color {
        if aiSettings.connectionSucceeded {
            return AppTheme.success.opacity(0.36)
        }
        return aiSettings.configuration.isEnabled ? AppTheme.accent.opacity(0.24) : AppTheme.hairline
    }

    private var providerPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text(aiSettings.configuration.provider.title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("HTTPS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppTheme.success)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(AppTheme.success.opacity(AppTheme.isDark ? 0.18 : 0.10), in: Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.adaptiveWhite(0.90), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline)
        )
    }

    private var securityNote: some View {
        Label("API Key 保存到本机用户目录的私有文件，权限 600，不写入源码或 Git 仓库；这不是 Keychain 加密。", systemImage: "lock.shield")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppTheme.accentSoft.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var currentModelSubtitle: String {
        DeepSeekModel(rawValue: aiSettings.configuration.model)?.subtitle ?? "自定义模型名，请确认该模型兼容 Chat Completions。"
    }

    private var connectionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task {
                    await aiSettings.testConnection()
                }
            } label: {
                Label(aiSettings.isTestingConnection ? "测试中" : "测试连接", systemImage: "network")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.tactilePlain)
            .tactilePlainControlAppearance(
                isDisabled: aiSettings.isTestingConnection || !aiSettings.configuration.hasEndpoint || !aiSettings.hasAPIKey,
                enabledForeground: AppTheme.workspaceTokens.accentForeground,
                enabledBackground: AppTheme.workspaceTokens.accent,
                enabledBorder: AppTheme.workspaceTokens.accent,
                shape: .roundedRectangle(10)
            )
            .interactionHitArea()
            .disabled(aiSettings.isTestingConnection || !aiSettings.configuration.hasEndpoint || !aiSettings.hasAPIKey)

            if let message = aiSettings.connectionMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: aiSettings.connectionSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.top, 1)
                    Text(message)
                        .font(.system(size: 11, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(aiSettings.connectionSucceeded ? AppTheme.success : TodoPriority.high.displayColor)
            } else if aiSettings.isTestingConnection {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在请求 DeepSeek")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }
        }
    }

    private var usageSection: some View {
        HStack(spacing: 10) {
            AIUsageRow(icon: "command", title: "快记解析", detail: "自动拆出时间、优先级、状态、备注和固定周期。")
            AIUsageRow(icon: "sun.max", title: "每日建议", detail: "按当前未完成事项生成 1-3 条推进建议。")
            AIUsageRow(icon: "text.alignleft", title: "备注摘要", detail: "长备注压缩成适合扫读的一句话。")
        }
    }
}

private struct CredentialSettingsStatusBadge: View {
    let status: CredentialVaultStatus
    let requiresMasterPassword: Bool
    let count: Int

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(statusColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text(statusSubtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.adaptiveWhite(0.70), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(statusColor.opacity(0.22))
        )
    }

    private var iconName: String {
        switch status {
        case .uninitialized: "key"
        case .locked: "lock.fill"
        case .unlocked: requiresMasterPassword ? "lock.open.fill" : "lock.open"
        }
    }

    private var statusTitle: String {
        switch status {
        case .uninitialized: "尚未初始化"
        case .locked: "凭证库已锁定"
        case .unlocked: "\(count) 条凭证"
        }
    }

    private var statusSubtitle: String {
        switch status {
        case .uninitialized:
            return "先进入凭证模块完成初始化"
        case .locked:
            return "解锁后可导入、备份和调整安全设置"
        case .unlocked:
            return requiresMasterPassword ? "已开启主密码验证" : "未开启主密码验证"
        }
    }

    private var statusColor: Color {
        switch status {
        case .uninitialized: AppTheme.mutedInk
        case .locked: TodoPriority.medium.displayColor
        case .unlocked: AppTheme.success
        }
    }
}

private struct AISettingsLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 14) {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 72, alignment: .leading)
            configuration.content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AISettingsTextField: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(AppTheme.adaptiveWhite(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.border)
            )
    }
}

struct DeepSeekModelPicker: View {
    @Binding var model: String

    private var currentModel: DeepSeekModel? {
        DeepSeekModel(rawValue: model)
    }

    var body: some View {
        Menu {
            ForEach(DeepSeekModel.allCases) { option in
                Button {
                    model = option.rawValue
                } label: {
                    VStack(alignment: .leading) {
                        Text(option.title)
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentModel?.title ?? "自定义模型")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(model.isEmpty ? AIProvider.deepSeek.defaultModel : model)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppTheme.adaptiveWhite(0.94), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(AppTheme.border)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.tactilePlain)
        .menuStyle(.borderlessButton)
        .help(currentModel?.subtitle ?? "当前使用自定义模型名")
    }
}

struct AIUsageRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 22, height: 22)
                .background(AppTheme.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.hairline)
        )
    }
}

struct ModuleManagementRow: View {
    let module: any AppModule
    let isInstalled: Bool
    let onInstall: () -> Void
    let onUninstall: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: module.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 32, height: 32)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(module.displayName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                Text(module.description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if isInstalled {
                Button(action: onUninstall) {
                    Text(module.isDefault ? "内置" : "卸载")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(module.isDefault ? AppTheme.mutedInk : Color.red)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(module.isDefault ? AppTheme.adaptiveWhite(0.3) : Color.red.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .disabled(module.isDefault)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.success)
            } else {
                Button(action: onInstall) {
                    Text("安装")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.adaptiveWhite(0.34))
        )
    }
}
