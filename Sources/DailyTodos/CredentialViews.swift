import AppKit
import SwiftUI

enum CredentialEditorMode: Equatable {
    case create(CredentialDraft)
    case edit(CredentialItem, CredentialDraft)
}

struct CredentialsModuleView: View {
    @EnvironmentObject private var credentialStore: CredentialStore
    @EnvironmentObject private var credentialActions: CredentialManagementActions
    @State private var searchText = ""
    @State private var selectedType: CredentialType?
    @State private var selectedCredentialID: UUID?
    @State private var editorMode: CredentialEditorMode?
    @State private var isResetConfirmationPresented = false
    @State private var unlockPassword = ""
    @State private var newMasterPassword = ""
    @State private var repeatedMasterPassword = ""
    @State private var initializationError: String?
    @State private var initializeRequiresMasterPassword = true

    private var visibleCredentials: [CredentialItem] {
        credentialStore.credentials(matching: searchText, type: selectedType)
    }

    private var selectedCredential: CredentialItem? {
        guard let selectedCredentialID else { return visibleCredentials.first }
        return visibleCredentials.first { $0.id == selectedCredentialID } ?? visibleCredentials.first
    }

    var body: some View {
        HStack(spacing: 0) {
            CredentialSidebar(
                searchText: $searchText,
                selectedType: $selectedType,
                credentials: credentialStore.credentials,
                status: credentialStore.status
            )
            .frame(width: 280)
            .background(AppTheme.sidebar)

            VStack(spacing: 0) {
                CredentialTopBar(
                    status: credentialStore.status,
                    count: credentialStore.credentials.count,
                    requiresMasterPassword: credentialStore.requiresMasterPassword,
                    notice: credentialActions.notice,
                    onNew: openNewCredential,
                    onLock: { credentialStore.lock() }
                )
                .frame(height: 48)

                Divider()
                    .overlay(AppTheme.hairline)

                content
            }
            .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.workSurface)
        }
        .onAppear {
            credentialStore.load()
        }
        .confirmationDialog(
            "重置会永久删除所有凭证",
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("确认重置凭证库", role: .destructive) {
                credentialStore.resetVault()
                unlockPassword = ""
                newMasterPassword = ""
                repeatedMasterPassword = ""
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("忘记主密码时只能重置。除非你已有加密备份，否则旧凭证不可恢复。")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch credentialStore.status {
        case .uninitialized:
            CredentialInitializeView(
                masterPassword: $newMasterPassword,
                repeatedPassword: $repeatedMasterPassword,
                requiresMasterPassword: $initializeRequiresMasterPassword,
                error: initializationError ?? credentialStore.lastError,
                onInitialize: initializeVault
            )
        case .locked:
            CredentialUnlockView(
                password: $unlockPassword,
                error: credentialStore.lastError,
                onUnlock: {
                    credentialStore.unlock(masterPassword: unlockPassword)
                    unlockPassword = ""
                },
                onReset: { isResetConfirmationPresented = true }
            )
        case .unlocked:
            CredentialWorkArea(
                credentials: visibleCredentials,
                selectedCredential: selectedCredential,
                editorMode: $editorMode,
                securityMode: $credentialActions.securityMode,
                error: credentialStore.lastError,
                auditEvents: credentialStore.auditEvents,
                onSelect: { selectedCredentialID = $0.id },
                onEdit: { item in
                    let secret = credentialStore.secretPayload(for: item, auditAction: "编辑凭证") ?? .empty
                    editorMode = .edit(item, CredentialDraft(item: item, secret: secret))
                },
                onSaveDraft: saveEditorDraft,
                onSaveSecurity: { password, repeatedPassword in
                    credentialActions.enableMasterPassword(
                        store: credentialStore,
                        password: password,
                        repeatedPassword: repeatedPassword
                    )
                },
                onImportDrafts: { drafts in
                    let importedCount = credentialActions.importDrafts(drafts, store: credentialStore)
                    if importedCount > 0 {
                        selectedCredentialID = credentialStore.credentials.first?.id
                        editorMode = nil
                    }
                },
                onDelete: { item in
                    credentialStore.deleteCredential(item)
                    if selectedCredentialID == item.id {
                        selectedCredentialID = nil
                    }
                },
                onReveal: { item in
                    credentialStore.secretPayload(for: item, auditAction: "查看敏感字段")
                },
                onCopy: { item, value in
                    copyToClipboard(value)
                    _ = credentialStore.secretPayload(for: item, auditAction: "复制敏感字段")
                }
            )
        }
    }

    private func initializeVault() {
        guard !initializeRequiresMasterPassword || newMasterPassword == repeatedMasterPassword else {
            initializationError = "两次输入不一致"
            return
        }
        initializationError = nil
        credentialStore.initialize(masterPassword: newMasterPassword, requiresMasterPassword: initializeRequiresMasterPassword)
        newMasterPassword = ""
        repeatedMasterPassword = ""
    }

    private func openNewCredential() {
        guard credentialStore.isUnlocked else { return }
        credentialActions.notice = nil
        credentialActions.clearTransientModes()
        editorMode = .create(CredentialDraft())
    }

    private func saveEditorDraft(_ mode: CredentialEditorMode) {
        switch mode {
        case .create(let draft):
            if let item = credentialStore.addCredential(draft) {
                selectedCredentialID = item.id
                editorMode = nil
                credentialActions.clearTransientModes()
            }
        case .edit(let item, let draft):
            credentialStore.updateCredential(item, draft: draft)
            selectedCredentialID = item.id
            editorMode = nil
            credentialActions.clearTransientModes()
        }
    }

    private func copyToClipboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        let copiedValue = value
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            guard NSPasteboard.general.string(forType: .string) == copiedValue else { return }
            NSPasteboard.general.clearContents()
        }
    }
}

struct CredentialContextSidebar: View {
    @EnvironmentObject private var credentialStore: CredentialStore
    @State private var searchText = ""
    @State private var selectedType: CredentialType?

    var body: some View {
        CredentialSidebar(
            searchText: $searchText,
            selectedType: $selectedType,
            credentials: credentialStore.credentials,
            status: credentialStore.status
        )
        .frame(width: secondarySidebarWidth)
        .background(AppTheme.sidebar)
    }
}

struct CredentialSidebar: View {
    @Binding var searchText: String
    @Binding var selectedType: CredentialType?
    let credentials: [CredentialItem]
    let status: CredentialVaultStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("凭证")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("账号、密码、Key、证书")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.horizontal, 17)
            .padding(.top, 48)
            .padding(.bottom, 14)

            SearchField(text: $searchText)
                .padding(.horizontal, 17)

            VStack(alignment: .leading, spacing: 7) {
                SidebarSectionLabel("类型")
                CredentialTypeButton(
                    title: "全部凭证",
                    subtitle: "\(credentials.count) 条",
                    icon: "square.grid.2x2",
                    isSelected: selectedType == nil
                ) {
                    selectedType = nil
                }

                ForEach(CredentialType.allCases) { type in
                    let count = credentials.filter { $0.type == type }.count
                    CredentialTypeButton(
                        title: type.title,
                        subtitle: "\(count) 条",
                        icon: type.icon,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                    }
                }
            }
            .padding(.horizontal, 17)
            .padding(.top, 14)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                Text(statusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(2)
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 13)
        }
        .background(AppTheme.sidebar)
        .foregroundStyle(AppTheme.ink)
    }

    private var statusText: String {
        switch status {
        case .uninitialized: "尚未初始化凭证库"
        case .locked: "凭证库已锁定"
        case .unlocked: "已解锁，敏感字段默认隐藏"
        }
    }
}

struct CredentialTypeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? AppTheme.accentWarm : Color.clear)
                    .frame(width: 3, height: 30)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(navBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.24) : AppTheme.adaptiveWhite(isHovered ? 0.36 : 0.0))
            )
        }
        .buttonStyle(.tactilePlain)
        .onHover { isHovered = $0 }
        .animation(AppMotion.hover, value: isHovered)
        .animation(AppMotion.smooth, value: isSelected)
    }

    private var navBackground: Color {
        if isSelected {
            return AppTheme.sidebarSelected
        }
        if isHovered {
            return AppTheme.adaptiveWhite(0.46)
        }
        return Color.clear
    }
}

struct CredentialTopBar: View {
    let status: CredentialVaultStatus
    let count: Int
    let requiresMasterPassword: Bool
    let notice: CredentialNotice?
    let onNew: () -> Void
    let onLock: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("凭证")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            if status == .unlocked {
                if let notice {
                    Label(notice.message, systemImage: notice.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(notice.isError ? TodoPriority.high.displayColor : AppTheme.accent)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 260, alignment: .trailing)
                }

                if requiresMasterPassword {
                    Button(action: onLock) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 34, height: 30)
                            .background(AppTheme.adaptiveWhite(0.68), in: Capsule())
                    }
                    .buttonStyle(.tactilePlain)
                    .help("锁定凭证库")
                }

                Button(action: onNew) {
                    Label("录入", systemImage: "square.and.pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(height: 30)
                        .padding(.horizontal, 12)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.tactilePlain)
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
    }

    private var subtitle: String {
        switch status {
        case .uninitialized:
            return "设置凭证库后开始保存个人凭证"
        case .locked:
            return "输入主密码解锁；主密码不会被保存"
        case .unlocked:
            let security = requiresMasterPassword ? "已开启主密码" : "未开启主密码"
            return "\(count) 条凭证，\(security)"
        }
    }
}

struct CredentialInitializeView: View {
    @Binding var masterPassword: String
    @Binding var repeatedPassword: String
    @Binding var requiresMasterPassword: Bool
    let error: String?
    let onInitialize: () -> Void

    var body: some View {
        CredentialAccessPanel(
            icon: "lock.shield.fill",
            title: "初始化凭证库",
            subtitle: requiresMasterPassword ? "主密码无法找回。忘记后只能重置并清空凭证库。" : "关闭后打开凭证不再验证，仅适合个人可信设备。"
        ) {
            Toggle(isOn: $requiresMasterPassword) {
                Text("开启主密码验证")
                    .font(.system(size: 13, weight: .bold))
            }
            .toggleStyle(.switch)

            if requiresMasterPassword {
                SecureField("主密码，至少 8 位", text: $masterPassword)
                    .textFieldStyle(.roundedBorder)
                SecureField("再次输入主密码", text: $repeatedPassword)
                    .textFieldStyle(.roundedBorder)
            }

            if let error {
                Text(error)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TodoPriority.high.displayColor)
            }

            Button(action: onInitialize) {
                Text("创建并解锁")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.tactilePlain)
            .disabled(requiresMasterPassword && (masterPassword.isEmpty || repeatedPassword.isEmpty))
        }
    }
}

struct CredentialUnlockView: View {
    @Binding var password: String
    let error: String?
    let onUnlock: () -> Void
    let onReset: () -> Void

    var body: some View {
        CredentialAccessPanel(
            icon: "lock.fill",
            title: "凭证库已锁定",
            subtitle: "解锁后才能查看列表；敏感字段仍默认隐藏。"
        ) {
            SecureField("输入主密码", text: $password)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onUnlock)

            if let error {
                Text(error)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TodoPriority.high.displayColor)
            }

            Button(action: onUnlock) {
                Text("解锁")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.tactilePlain)
            .disabled(password.isEmpty)

            Button(role: .destructive, action: onReset) {
                Text("忘记主密码，重置凭证库")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TodoPriority.high.displayColor)
            }
            .buttonStyle(.plain)
        }
    }
}

struct CredentialAccessPanel<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                content()
            }
            .padding(24)
            .frame(width: 420)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.border)
            )
            .shadow(color: AppTheme.rowShadow, radius: 12, x: 0, y: 6)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.workSurface)
    }
}

struct CredentialWorkArea: View {
    let credentials: [CredentialItem]
    let selectedCredential: CredentialItem?
    @Binding var editorMode: CredentialEditorMode?
    @Binding var securityMode: CredentialSecurityMode?
    let error: String?
    let auditEvents: [CredentialAuditEvent]
    let onSelect: (CredentialItem) -> Void
    let onEdit: (CredentialItem) -> Void
    let onSaveDraft: (CredentialEditorMode) -> Void
    let onSaveSecurity: (String, String) -> Void
    let onImportDrafts: ([CredentialDraft]) -> Void
    let onDelete: (CredentialItem) -> Void
    let onReveal: (CredentialItem) -> CredentialSecretPayload?
    let onCopy: (CredentialItem, String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            CredentialListPane(
                credentials: credentials,
                selectedCredential: selectedCredential,
                onSelect: { item in
                    editorMode = nil
                    securityMode = nil
                    onSelect(item)
                }
            )
            .frame(width: 360)

            Divider()
                .overlay(AppTheme.hairline)

            if securityMode != nil {
                CredentialSecuritySettingsPane(
                    error: error,
                    onSave: onSaveSecurity,
                    onCancel: { self.securityMode = nil }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let editorMode {
                CredentialInlineEditor(
                    mode: editorMode,
                    error: error,
                    onChange: { self.editorMode = $0 },
                    onSave: onSaveDraft,
                    onCancel: { self.editorMode = nil },
                    onImportDrafts: onImportDrafts
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CredentialDetailPane(
                    item: selectedCredential,
                    error: error,
                    auditEvents: auditEvents,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onReveal: onReveal,
                    onCopy: onCopy
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct CredentialListPane: View {
    let credentials: [CredentialItem]
    let selectedCredential: CredentialItem?
    let onSelect: (CredentialItem) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if credentials.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "key.slash")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                        Text("没有匹配的凭证")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    ForEach(credentials) { item in
                        CredentialListRow(
                            item: item,
                            isSelected: selectedCredential?.id == item.id,
                            action: { onSelect(item) }
                        )
                    }
                }
            }
            .padding(18)
        }
        .background(AppTheme.workSurface)
    }
}

struct CredentialListRow: View {
    let item: CredentialItem
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: item.type.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk)
                    Text(item.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Spacer()
                    Text(item.type.title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppTheme.accentSoft, in: Capsule())
                }

                Text(item.displayService)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)

                if !item.tags.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(item.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.mutedInk)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.adaptiveWhite(0.58), in: Capsule())
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.28) : AppTheme.hairline.opacity(isHovered ? 0.92 : 0.55))
            )
        }
        .buttonStyle(.tactilePlain)
        .onHover { isHovered = $0 }
        .animation(AppMotion.hover, value: isHovered)
        .animation(AppMotion.smooth, value: isSelected)
    }

    private var rowBackground: Color {
        if isSelected {
            return AppTheme.accentSoft.opacity(0.86)
        }
        if isHovered {
            return AppTheme.panel.opacity(0.98)
        }
        return AppTheme.panel.opacity(0.76)
    }
}

struct CredentialDetailPane: View {
    let item: CredentialItem?
    let error: String?
    let auditEvents: [CredentialAuditEvent]
    let onEdit: (CredentialItem) -> Void
    let onDelete: (CredentialItem) -> Void
    let onReveal: (CredentialItem) -> CredentialSecretPayload?
    let onCopy: (CredentialItem, String) -> Void
    @State private var revealedSecret: CredentialSecretPayload?
    @State private var breachCheckSummary: CredentialBreachCheckSummary?
    @State private var isCheckingBreachRisk = false
    @State private var breachCheckMessage: String?
    @State private var breachCheckCredentialID: UUID?
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let item {
                detail(for: item)
            } else {
                Spacer()
                ContentUnavailableView("选择一条凭证", systemImage: "key", description: Text("凭证解锁后可查看摘要，敏感字段需要单独点击显示。"))
                Spacer()
            }
        }
        .padding(24)
        .onChange(of: item?.id) { _, _ in
            revealedSecret = nil
            resetBreachCheck()
        }
    }

    private func detail(for item: CredentialItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.type.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    Text(item.type.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }

                Spacer()

                Button { onEdit(item) } label: {
                    Label("编辑", systemImage: "pencil")
                }
                .buttonStyle(.tactilePlain)

                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.tactilePlain)
                .help("删除凭证")
            }

            if let error {
                Text(error)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TodoPriority.high.displayColor)
            }

            CredentialSecretSection(
                item: item,
                secret: revealedSecret,
                breachCheckSummary: breachCheckSummary,
                isCheckingBreachRisk: isCheckingBreachRisk,
                breachCheckMessage: breachCheckMessage,
                onReveal: {
                    revealedSecret = onReveal(item)
                    resetBreachCheck()
                },
                onHide: {
                    revealedSecret = nil
                    resetBreachCheck()
                },
                onCheckRisk: {
                    checkBreachRisk(for: item)
                },
                onCopy: { value in
                    onCopy(item, value)
                }
            )

            if !item.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(item.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.accentSoft, in: Capsule())
                    }
                }
            }

            Spacer(minLength: 12)

            CredentialAuditPanel(events: auditEvents)
        }
        .confirmationDialog(
            "删除「\(item.title)」？",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                onDelete(item)
                revealedSecret = nil
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后需要通过加密备份恢复。")
        }
    }

    private func resetBreachCheck() {
        breachCheckSummary = nil
        breachCheckMessage = nil
        isCheckingBreachRisk = false
        breachCheckCredentialID = nil
    }

    private func checkBreachRisk(for item: CredentialItem) {
        guard let secret = revealedSecret else {
            breachCheckMessage = "查看敏感字段后再检查"
            return
        }

        isCheckingBreachRisk = true
        breachCheckMessage = nil
        breachCheckSummary = nil
        breachCheckCredentialID = item.id

        let checkingCredentialID = item.id
        Task {
            let summary = await CredentialBreachChecker.checkCredential(
                username: item.username,
                password: secret.secretValue
            )
            await MainActor.run {
                guard breachCheckCredentialID == checkingCredentialID else {
                    return
                }
                breachCheckSummary = summary
                breachCheckMessage = summaryMessage(for: summary)
                isCheckingBreachRisk = false
            }
        }
    }

    private func summaryMessage(for summary: CredentialBreachCheckSummary) -> String {
        let emailAtRisk = summary.email.isExposed
        let passwordAtRisk = summary.password.isExposed
        if emailAtRisk || passwordAtRisk {
            return "发现泄露风险"
        }
        if case .failed = summary.password {
            return "部分检查失败"
        }
        if case .skippedEmpty = summary.password {
            return "账号检查完成，密码为空未检查"
        }
        return "未发现已知泄露"
    }
}

struct CredentialSecretSection: View {
    let item: CredentialItem
    let secret: CredentialSecretPayload?
    let breachCheckSummary: CredentialBreachCheckSummary?
    let isCheckingBreachRisk: Bool
    let breachCheckMessage: String?
    let onReveal: () -> Void
    let onHide: () -> Void
    let onCheckRisk: () -> Void
    let onCopy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("敏感字段")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                if secret == nil {
                    Button(action: onReveal) {
                        Label("查看", systemImage: "eye")
                    }
                    .buttonStyle(.tactilePlain)
                } else {
                    Button(action: onCheckRisk) {
                        Label(isCheckingBreachRisk ? "检查中" : "检查风险", systemImage: "shield.lefthalf.filled")
                    }
                    .buttonStyle(.tactilePlain)
                    .disabled(isCheckingBreachRisk)
                    Button(action: onHide) {
                        Label("隐藏", systemImage: "eye.slash")
                    }
                    .buttonStyle(.tactilePlain)
                }
            }

            if let secret {
                CredentialDetailFieldsTable(
                    item: item,
                    secret: secret,
                    onCopy: onCopy
                )
                CredentialBreachRiskPanel(
                    summary: breachCheckSummary,
                    isChecking: isCheckingBreachRisk,
                    message: breachCheckMessage
                )
            } else {
                CredentialDetailFieldsTable(
                    item: item,
                    secret: nil,
                    onCopy: onCopy
                )
            }
        }
    }
}

struct CredentialBreachRiskPanel: View {
    let summary: CredentialBreachCheckSummary?
    let isChecking: Bool
    let message: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(statusColor)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 5) {
                Text(message ?? "可检查邮箱泄露和密码泄露")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(statusColor)

                if let summary {
                    Text(detailText(for: summary))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("若账号是邮箱，会发送到 XposedOrNot；密码仅发送 SHA-1 前 5 位到 HIBP。")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(statusColor.opacity(0.18))
        )
        .animation(AppMotion.status, value: isChecking)
        .animation(AppMotion.status, value: summary)
    }

    private var iconName: String {
        if isChecking {
            return "arrow.triangle.2.circlepath"
        }
        if let summary, summary.email.isExposed || summary.password.isExposed {
            return "exclamationmark.shield.fill"
        }
        if let summary, case .failed = summary.password {
            return "exclamationmark.triangle.fill"
        }
        if summary != nil {
            return "checkmark.shield.fill"
        }
        return "shield"
    }

    private var statusColor: Color {
        if isChecking {
            return AppTheme.accent
        }
        if let summary, summary.email.isExposed || summary.password.isExposed {
            return TodoPriority.high.displayColor
        }
        if let summary, case .failed = summary.password {
            return TodoPriority.medium.displayColor
        }
        if summary != nil {
            return AppTheme.success
        }
        return AppTheme.mutedInk
    }

    private var panelFill: Color {
        if let summary, summary.email.isExposed || summary.password.isExposed {
            return TodoPriority.high.displayColor.opacity(0.08)
        }
        if let summary, case .failed = summary.password {
            return TodoPriority.medium.displayColor.opacity(0.08)
        }
        if summary != nil {
            return AppTheme.successSoft.opacity(0.70)
        }
        return AppTheme.adaptiveWhite(0.58)
    }

    private func detailText(for summary: CredentialBreachCheckSummary) -> String {
        [emailText(for: summary.email), passwordText(for: summary.password)]
            .compactMap { $0 }
            .joined(separator: "；")
    }

    private func emailText(for result: CredentialEmailBreachResult) -> String {
        switch result {
        case .skippedNotEmail:
            return "账号不是邮箱，已跳过邮箱检查"
        case .notFound:
            return "邮箱未命中 XposedOrNot 已知泄露"
        case .exposed(_, let breachNames):
            let preview = breachNames.prefix(3).joined(separator: "、")
            if preview.isEmpty {
                return "邮箱出现在已知泄露中"
            }
            let moreCount = breachNames.count - min(breachNames.count, 3)
            return moreCount > 0
                ? "邮箱出现在 \(preview) 等 \(breachNames.count) 个泄露中"
                : "邮箱出现在 \(preview) 泄露中"
        case .failed(let message):
            return "邮箱检查失败：\(message)"
        }
    }

    private func passwordText(for result: CredentialPasswordBreachResult) -> String {
        switch result {
        case .skippedEmpty:
            return "密码为空，已跳过密码检查"
        case .notFound:
            return "密码未命中 HIBP 已知泄露"
        case .exposed(let occurrenceCount):
            return "密码在 HIBP 中出现 \(occurrenceCount) 次"
        case .failed(let message):
            return "密码检查失败：\(message)"
        }
    }
}

struct CredentialDetailFieldsTable: View {
    let item: CredentialItem
    let secret: CredentialSecretPayload?
    let onCopy: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            CredentialCopyableFieldRow(label: "账号", value: item.username, onCopy: onCopy)
            CredentialCopyableFieldRow(label: "密码", value: secret?.secretValue ?? "", isPassword: true, isLocked: secret == nil, onCopy: onCopy)
            CredentialCopyableFieldRow(label: "网站", value: item.serviceURL, onCopy: onCopy)
            CredentialCopyableFieldRow(label: "修改日期", value: item.updatedAt.formatted(.dateTime.year().month().day()), canCopy: false, onCopy: onCopy)
            CredentialCopyableFieldRow(label: "备注", value: secret?.notes ?? "", canCopy: secret != nil, showsDivider: false, onCopy: onCopy)
        }
        .padding(.horizontal, 14)
        .background(AppTheme.adaptiveWhite(0.54), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.48))
        )
    }
}

struct CredentialCopyableFieldRow: View {
    let label: String
    let value: String
    var isPassword = false
    var isLocked = false
    var canCopy = true
    var showsDivider = true
    let onCopy: (String) -> Void
    @State private var isHovered = false
    @State private var didCopy = false

    private var displayValue: String {
        if isLocked {
            return "已隐藏"
        }
        if value.isEmpty {
            return "--"
        }
        if isPassword && !isHovered && !didCopy {
            return String(repeating: "•", count: min(max(value.count, 8), 18))
        }
        return value
    }

    var body: some View {
        Group {
            if isCopyEnabled {
                Button {
                    copyValue()
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .onHover { hovered in
            if isPassword {
                withAnimation(AppMotion.hover) {
                    isHovered = hovered
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(AppTheme.hairline.opacity(0.62))
                    .frame(height: 1)
            }
        }
        .help(helpText)
        .animation(AppMotion.status, value: didCopy)
    }

    private var isCopyEnabled: Bool {
        canCopy && !value.isEmpty && !isLocked
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(labelColor)
                .frame(width: 82, alignment: .leading)

            Spacer(minLength: 24)

            valueView
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var valueView: some View {
        if didCopy {
            HStack(spacing: 7) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("已拷贝")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(AppTheme.mutedInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppTheme.adaptiveWhite(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            if isPassword {
                Text(displayValue)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.disabled)
            } else {
                Text(displayValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(valueColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }
        }
    }

    private var labelColor: Color {
        isLocked ? AppTheme.mutedInk.opacity(0.82) : AppTheme.ink
    }

    private var valueColor: Color {
        if isLocked || value.isEmpty {
            return AppTheme.mutedInk.opacity(0.82)
        }
        return AppTheme.mutedInk
    }

    private var helpText: String {
        if isLocked {
            return "点击查看后可复制"
        }
        if !isCopyEnabled {
            return ""
        }
        if isPassword {
            return "悬停显示，点击复制"
        }
        return "点击复制"
    }

    private func copyValue() {
        guard isCopyEnabled else {
            return
        }
        onCopy(value)
        didCopy = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            didCopy = false
        }
    }
}

struct CredentialAuditPanel: View {
    let events: [CredentialAuditEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本地操作记录")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            if events.isEmpty {
                Text("暂无操作记录")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            } else {
                ForEach(events.prefix(5)) { event in
                    HStack {
                        Text(event.action)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text(event.credentialTitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.mutedInk)
                            .lineLimit(1)
                        Spacer()
                        Text(event.createdAt.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.adaptiveWhite(0.52), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct CredentialSecuritySettingsPane: View {
    let error: String?
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    @State private var masterPassword = ""
    @State private var repeatedPassword = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 46, height: 46)
                        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("开启主密码验证")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                        Text("开启后，每次进入凭证库都需要输入主密码。")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 12) {
                    CredentialField(label: "主密码") {
                        SecureField("至少 8 位", text: $masterPassword)
                            .textFieldStyle(.roundedBorder)
                    }
                    CredentialField(label: "确认") {
                        SecureField("再次输入主密码", text: $repeatedPassword)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(14)
                .background(AppTheme.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.78))
                )

                if let error {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TodoPriority.high.displayColor)
                }

                HStack {
                    Button("取消", action: onCancel)
                        .buttonStyle(.borderless)
                    Spacer()
                    Button {
                        onSave(masterPassword, repeatedPassword)
                    } label: {
                        Label("开启验证", systemImage: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(masterPassword.isEmpty || repeatedPassword.isEmpty)
                }
            }
            .padding(24)
        }
        .background(AppTheme.workSurface)
    }
}

struct CredentialInlineEditor: View {
    let mode: CredentialEditorMode
    let error: String?
    let onChange: (CredentialEditorMode) -> Void
    let onSave: (CredentialEditorMode) -> Void
    let onCancel: () -> Void
    let onImportDrafts: ([CredentialDraft]) -> Void
    @State private var pastedText = ""
    @State private var parseMessage: String?

    private var draft: CredentialDraft {
        switch mode {
        case .create(let draft), .edit(_, let draft):
            return draft
        }
    }

    private var title: String {
        switch mode {
        case .create: "录入凭证"
        case .edit: "编辑凭证"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 46, height: 46)
                        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                        Text("直接粘贴账号文本，或在下方字段里补充。保存后敏感字段加密落库。")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                    }

                    Spacer()
                }

                pasteCard
                formCard

                if let error {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TodoPriority.high.displayColor)
                }

                HStack {
                    Button("取消", action: onCancel)
                        .buttonStyle(.borderless)
                    Spacer()
                    Button {
                        onSave(mode)
                    } label: {
                        Label("保存凭证", systemImage: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.cleanedTitle.isEmpty)
                }
            }
            .padding(24)
        }
        .background(AppTheme.workSurface)
    }

    private var pasteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("粘贴解析")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Button {
                    parsePastedText()
                } label: {
                    Label("填入表单", systemImage: "wand.and.stars")
                }
                .buttonStyle(.tactilePlain)
                .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            TextEditor(text: $pastedText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(minHeight: 116)
                .padding(8)
                .background(AppTheme.adaptiveWhite(0.68), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.hairline.opacity(0.72))
                )

            Text(parseMessageText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(parseMessageColor)
        }
        .padding(14)
        .background(AppTheme.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border.opacity(0.78))
        )
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("字段")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            CredentialDraftFields(
                draft: draft,
                onChange: updateDraft
            )
        }
        .padding(14)
        .background(AppTheme.panel.opacity(0.86), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border.opacity(0.78))
        )
    }

    private func parsePastedText() {
        let drafts = CredentialImportParser.drafts(fromLooseText: pastedText)
        guard let first = drafts.first else {
            parseMessage = "错误：没有识别到可导入的凭证"
            return
        }

        if drafts.count == 1 {
            updateDraft(first)
            parseMessage = "已填入表单"
        } else {
            onImportDrafts(drafts)
            parseMessage = "已导入 \(drafts.count) 条凭证"
        }
    }

    private var parseMessageText: String {
        parseMessage ?? "支持：标题、网址、账号：xxx、密码：xxx。多条记录可用空行分隔。"
    }

    private var parseMessageColor: Color {
        guard let parseMessage else { return AppTheme.mutedInk }
        return parseMessage.hasPrefix("错误：") ? TodoPriority.high.displayColor : AppTheme.accent
    }

    private func updateDraft(_ draft: CredentialDraft) {
        switch mode {
        case .create:
            onChange(.create(draft))
        case .edit(let item, _):
            onChange(.edit(item, draft))
        }
    }
}

struct CredentialDraftFields: View {
    let draft: CredentialDraft
    let onChange: (CredentialDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CredentialField(label: "标题") {
                TextField("如：星邦（剪叉）", text: binding(\.title))
                    .textFieldStyle(.roundedBorder)
            }

            CredentialField(label: "类型") {
                Picker("", selection: binding(\.type)) {
                    ForEach(CredentialType.allCases) { type in
                        Label(type.title, systemImage: type.icon).tag(type)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220, alignment: .leading)
            }

            CredentialField(label: "账号") {
                TextField("账号 / 用户名", text: binding(\.username))
                    .textFieldStyle(.roundedBorder)
            }

            CredentialField(label: "网址/服务") {
                TextField("https://example.com", text: binding(\.serviceURL))
                    .textFieldStyle(.roundedBorder)
            }

            CredentialField(label: "密码/Key") {
                SecureField("密码、Token、Key", text: binding(\.secretValue))
                    .textFieldStyle(.roundedBorder)
            }

            CredentialField(label: "证书内容") {
                TextField("证书、license 或其他凭证", text: binding(\.certificateBody), axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
            }

            CredentialField(label: "备注") {
                TextField("补充说明", text: binding(\.notes), axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
            }

            CredentialField(label: "标签") {
                TextField("用逗号分隔", text: binding(\.tagsText))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<CredentialDraft, Value>) -> Binding<Value> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { value in
                var updated = draft
                updated[keyPath: keyPath] = value
                onChange(updated)
            }
        )
    }
}

struct CredentialField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 82, alignment: .leading)
                .padding(.top, 7)
            content()
        }
    }
}

struct CredentialBackupSheet: View {
    @EnvironmentObject private var credentialStore: CredentialStore
    @Environment(\.dismiss) private var dismiss
    @State private var backupPassword = ""
    @State private var backupText = ""
    @State private var importPassword = ""
    @State private var importText = ""
    @State private var replaceExisting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("加密备份")
                        .font(.system(size: 20, weight: .bold))
                    Text("导出的内容仍是密文；导入失败不会修改当前凭证库。")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
                Spacer()
                Button("关闭") { dismiss() }
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("导出")
                        .font(.system(size: 14, weight: .bold))
                    SecureField("备份密码，至少 8 位", text: $backupPassword)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        backupText = credentialStore.exportBackup(password: backupPassword) ?? ""
                    } label: {
                        Label("生成加密备份", systemImage: "lock.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    TextEditor(text: $backupText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .frame(height: 250)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(backupText, forType: .string)
                    } label: {
                        Label("复制备份文本", systemImage: "doc.on.doc")
                    }
                    .disabled(backupText.isEmpty)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("导入")
                        .font(.system(size: 14, weight: .bold))
                    SecureField("备份密码", text: $importPassword)
                        .textFieldStyle(.roundedBorder)
                    Toggle("替换当前凭证库", isOn: $replaceExisting)
                    TextEditor(text: $importText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .frame(height: 250)
                    Button {
                        credentialStore.importBackup(importText, password: importPassword, replaceExisting: replaceExisting)
                    } label: {
                        Label("导入备份", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || importPassword.isEmpty)
                }
            }

            if let error = credentialStore.lastError {
                Text(error)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TodoPriority.high.displayColor)
            }
        }
        .padding(22)
        .frame(width: 860)
        .frame(minHeight: 560)
        .background(AppTheme.workSurface)
    }
}
