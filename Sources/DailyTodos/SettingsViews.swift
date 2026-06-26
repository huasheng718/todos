import SwiftUI

struct AppSettingsSheet: View {
    @EnvironmentObject private var updateController: UpdateController
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSkinRawValue: String

    private var selectedSkin: AppSkin {
        AppSkin(rawValue: selectedSkinRawValue) ?? .ocean
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("应用设置")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    Text("外观、版本与更新")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .interactionHitArea()
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .help("关闭")
                .accessibilityLabel("关闭")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()
                .overlay(AppTheme.hairline)

            VStack(alignment: .leading, spacing: 14) {
                settingsSection(title: "外观", icon: "paintpalette.fill") {
                    VStack(spacing: 7) {
                        ForEach(AppSkin.allCases) { skin in
                            Button {
                                withAnimation(AppMotion.smooth) {
                                    activeAppSkin = skin
                                    selectedSkinRawValue = skin.rawValue
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: skin.icon)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(skin == selectedSkin ? AppTheme.accent : AppTheme.mutedInk)
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

                                    if skin == selectedSkin {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(skin == selectedSkin ? AppTheme.accentSoft : AppTheme.adaptiveWhite(0.78), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(skin == selectedSkin ? AppTheme.accent.opacity(0.24) : AppTheme.hairline)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.tactilePlain)
                        }
                    }
                }

                settingsSection(title: "更新", icon: "arrow.triangle.2.circlepath") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 10) {
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

                            if updateController.availableUpdate != nil {
                                Button {
                                    updateController.downloadAvailableUpdate()
                                } label: {
                                    Label(updateController.isDownloading ? "下载中" : "下载", systemImage: updateController.isDownloading ? "arrow.down.circle.fill" : "arrow.down.to.line")
                                        .font(.system(size: 12, weight: .semibold))
                                        .frame(width: 78, height: 32)
                                }
                                .buttonStyle(.tactilePlain)
                                .foregroundStyle(.white)
                                .background(updateController.isDownloading ? AppTheme.mutedInk : AppTheme.accentWarm, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(AppTheme.adaptiveWhite(0.28))
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
                            .foregroundStyle(updateController.isChecking ? AppTheme.accent : .white)
                            .background(updateController.isChecking ? AppTheme.accentSoft : AppTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(updateController.isChecking ? AppTheme.accent.opacity(0.24) : AppTheme.adaptiveWhite(0.26))
                            )
                            .disabled(updateController.isChecking || updateController.isDownloading)
                            .help("检查更新")
                        }

                        if updateController.isDownloading {
                            updateDownloadProgressView
                        }

                        updateReminderNote
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 460)
        .background(AppTheme.workSurface)
    }

    private var updateStatusText: String {
        if updateController.isChecking {
            return "正在检查远程版本…"
        }
        if updateController.isDownloading {
            if let progress = updateController.downloadProgress {
                return "正在下载更新 \(progress.statusText)"
            }
            return "正在连接下载服务…"
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

    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
        .padding(12)
        .background(AppTheme.adaptiveWhite(0.76), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border.opacity(0.78))
        )
    }
}

struct AISettingsSheet: View {
    @EnvironmentObject private var aiSettings: AISettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    settingsCard
                    usageSection
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.visible)
        }
        .padding(22)
        .frame(width: 720, height: 560)
        .background(AppTheme.workSurface)
        .foregroundStyle(AppTheme.ink)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentSoft)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text("AI 设置")
                    .font(.system(size: 25, weight: .semibold))
                Text("DeepSeek 负责智能解析、推进建议和备注摘要；密钥只保存在本机私有配置文件。")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .interactionHitArea()
            }
            .buttonStyle(.tactilePlain)
            .foregroundStyle(AppTheme.mutedInk)
            .help("关闭")
            .accessibilityLabel("关闭")
        }
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
                    SecureField("sk-…", text: $aiSettings.apiKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .accessibilityLabel("API Key")
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
            .foregroundStyle(.white)
            .background(aiSettings.configuration.hasEndpoint && aiSettings.hasAPIKey ? AppTheme.accent : AppTheme.adaptiveBlack(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                // 等价 aria-live="polite"：测试结果出现时 VoiceOver 自动播报。
                .accessibilityElement(children: .combine)
                .accessibilityLabel(message)
                .accessibilityAddTraits(.updatesFrequently)
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
            .autocorrectionDisabled()
            .accessibilityLabel(placeholder)
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
