import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum CredentialEditorMode: Equatable {
    case create(CredentialDraft)
    case edit(CredentialItem, CredentialDraft)
}

enum CredentialSecurityMode: Equatable {
    case enableMasterPassword
}

struct CredentialNotice: Equatable {
    let message: String
    let isError: Bool
}

struct CredentialsModuleView: View {
    @EnvironmentObject private var credentialStore: CredentialStore
    @State private var searchText = ""
    @State private var selectedType: CredentialType?
    @State private var selectedCredentialID: UUID?
    @State private var editorMode: CredentialEditorMode?
    @State private var isBackupSheetPresented = false
    @State private var isResetConfirmationPresented = false
    @State private var unlockPassword = ""
    @State private var newMasterPassword = ""
    @State private var repeatedMasterPassword = ""
    @State private var initializationError: String?
    @State private var importNotice: CredentialNotice?
    @State private var initializeRequiresMasterPassword = true
    @State private var securityMode: CredentialSecurityMode?

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
                    notice: importNotice,
                    onNew: openNewCredential,
                    onImportFile: importCredentialsFromFile,
                    onLock: { credentialStore.lock() },
                    onBackup: { isBackupSheetPresented = true },
                    onSecurityModeChange: updateMasterPasswordRequirement
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
        .sheet(isPresented: $isBackupSheetPresented) {
            CredentialBackupSheet()
                .environmentObject(credentialStore)
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
                securityMode: $securityMode,
                error: credentialStore.lastError,
                auditEvents: credentialStore.auditEvents,
                onSelect: { selectedCredentialID = $0.id },
                onEdit: { item in
                    let secret = credentialStore.secretPayload(for: item, auditAction: "编辑凭证") ?? .empty
                    editorMode = .edit(item, CredentialDraft(item: item, secret: secret))
                },
                onSaveDraft: saveEditorDraft,
                onSaveSecurity: enableMasterPassword,
                onImportDrafts: importDrafts,
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
        importNotice = nil
        securityMode = nil
        editorMode = .create(CredentialDraft())
    }

    private func saveEditorDraft(_ mode: CredentialEditorMode) {
        switch mode {
        case .create(let draft):
            if let item = credentialStore.addCredential(draft) {
                selectedCredentialID = item.id
                editorMode = nil
                securityMode = nil
            }
        case .edit(let item, let draft):
            credentialStore.updateCredential(item, draft: draft)
            selectedCredentialID = item.id
            editorMode = nil
            securityMode = nil
        }
    }

    private func enableMasterPassword(_ password: String, repeatedPassword: String) {
        guard password == repeatedPassword else {
            importNotice = CredentialNotice(message: "两次主密码输入不一致", isError: true)
            return
        }
        credentialStore.setMasterPasswordRequired(true, newMasterPassword: password)
        if credentialStore.requiresMasterPassword {
            securityMode = nil
            importNotice = CredentialNotice(message: "已开启主密码验证", isError: false)
        }
    }

    private func updateMasterPasswordRequirement(_ required: Bool) {
        importNotice = nil
        editorMode = nil
        if required {
            securityMode = .enableMasterPassword
        } else {
            credentialStore.setMasterPasswordRequired(false)
            if !credentialStore.requiresMasterPassword {
                securityMode = nil
                importNotice = CredentialNotice(message: "已关闭主密码验证", isError: false)
            }
        }
    }

    private func importDrafts(_ drafts: [CredentialDraft]) {
        guard !drafts.isEmpty else {
            importNotice = CredentialNotice(message: "没有识别到可导入的凭证", isError: true)
            return
        }
        let importedCount = credentialStore.importCredentials(drafts)
        if importedCount > 0 {
            selectedCredentialID = credentialStore.credentials.first?.id
            editorMode = nil
            securityMode = nil
            importNotice = CredentialNotice(message: "已导入 \(importedCount) 条凭证", isError: false)
        } else {
            importNotice = CredentialNotice(message: credentialStore.lastError ?? "导入失败，请检查文件内容", isError: true)
        }
    }

    private func importCredentialsFromFile() {
        guard credentialStore.isUnlocked else { return }
        importNotice = nil
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.commaSeparatedText, .plainText, .text]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let drafts = CredentialImportParser.drafts(fromFileText: text)
                importDrafts(drafts)
            } catch {
                importNotice = CredentialNotice(message: "读取文件失败：\(error.localizedDescription)", isError: true)
            }
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
    let onImportFile: () -> Void
    let onLock: () -> Void
    let onBackup: () -> Void
    let onSecurityModeChange: (Bool) -> Void

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

                Menu {
                    Button(action: onImportFile) {
                        Label("从 Chrome 导出的 CSV 或电脑文本导入", systemImage: "folder")
                    }
                    Button(action: onBackup) {
                        Label("加密备份 / 恢复", systemImage: "externaldrive.badge.checkmark")
                    }
                    Divider()
                    Toggle(isOn: Binding(
                        get: { requiresMasterPassword },
                        set: { value in onSecurityModeChange(value) }
                    )) {
                        Label("主密码验证", systemImage: requiresMasterPassword ? "lock.fill" : "lock.open")
                    }
                } label: {
                    Label("管理", systemImage: "ellipsis.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(height: 30)
                        .padding(.horizontal, 10)
                        .background(AppTheme.adaptiveWhite(0.68), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .menuStyle(.borderlessButton)

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
                onReveal: {
                    revealedSecret = onReveal(item)
                },
                onHide: {
                    revealedSecret = nil
                },
                onCopy: { value in
                    onCopy(item, value)
                }
            )

            VStack(alignment: .leading, spacing: 10) {
                CredentialInfoRow(label: "网址/服务", value: item.serviceURL.isEmpty ? "--" : item.serviceURL)
                CredentialInfoRow(label: "更新时间", value: item.updatedAt.formatted(.dateTime.year().month().day().hour().minute()))
            }

            Divider()
                .overlay(AppTheme.hairline)

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
}

struct CredentialInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .textSelection(.enabled)
            Spacer()
        }
    }
}

struct CredentialSecretSection: View {
    let item: CredentialItem
    let secret: CredentialSecretPayload?
    let onReveal: () -> Void
    let onHide: () -> Void
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
                    Button(action: onHide) {
                        Label("隐藏", systemImage: "eye.slash")
                    }
                    .buttonStyle(.tactilePlain)
                }
            }

            if let secret {
                CredentialSensitiveValue(label: "账号", value: item.username, onCopy: onCopy, isSensitive: false)
                CredentialSensitiveValue(label: "密码 / Key / Token", value: secret.secretValue, onCopy: onCopy)
                CredentialSensitiveValue(label: "证书内容", value: secret.certificateBody, onCopy: onCopy)
                CredentialSensitiveValue(label: "备注", value: secret.notes, onCopy: onCopy)
            } else {
                CredentialSensitiveValue(label: "账号", value: item.username, onCopy: onCopy, isSensitive: false)
                CredentialHiddenValue()
            }
        }
    }
}

struct CredentialHiddenValue: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("密码 / Key / Token")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 112, alignment: .leading)
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .bold))
            Text("已隐藏，点击查看后显示")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(AppTheme.mutedInk)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.adaptiveWhite(0.62), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct CredentialSensitiveValue: View {
    let label: String
    let value: String
    let onCopy: (String) -> Void
    var isSensitive = true

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 112, alignment: .leading)
                .padding(.top, 7)
            Text(value.isEmpty ? "--" : value)
                .font(.system(size: 12, weight: .medium, design: isSensitive ? .monospaced : .default))
                .foregroundStyle(AppTheme.ink)
                .textSelection(.enabled)
                .lineLimit(4)
                .padding(.vertical, 7)
            Spacer()
            Button {
                onCopy(value)
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.tactilePlain)
            .disabled(value.isEmpty)
            .help("复制")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.adaptiveWhite(0.66), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
