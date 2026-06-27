import AppKit
import SwiftUI

struct CredentialsModuleView: View {
    @EnvironmentObject private var credentialStore: CredentialStore
    @State private var searchText = ""
    @State private var selectedType: CredentialType?
    @State private var selectedCredentialID: UUID?
    @State private var isEditorPresented = false
    @State private var editingCredential: CredentialItem?
    @State private var isBackupSheetPresented = false
    @State private var isResetConfirmationPresented = false
    @State private var unlockPassword = ""
    @State private var newMasterPassword = ""
    @State private var repeatedMasterPassword = ""
    @State private var initializationError: String?

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
                status: credentialStore.status,
                onNew: openNewCredential
            )
            .frame(width: 280)
            .background(AppTheme.sidebar)

            VStack(spacing: 0) {
                CredentialTopBar(
                    status: credentialStore.status,
                    count: credentialStore.credentials.count,
                    onNew: openNewCredential,
                    onLock: { credentialStore.lock() },
                    onBackup: { isBackupSheetPresented = true }
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
        .sheet(isPresented: $isEditorPresented) {
            CredentialEditorSheet(
                item: editingCredential,
                initialSecret: editingCredential.flatMap { credentialStore.secretPayload(for: $0, auditAction: "编辑凭证") },
                onSave: { item, draft in
                    if let item {
                        credentialStore.updateCredential(item, draft: draft)
                    } else {
                        credentialStore.addCredential(draft)
                    }
                    isEditorPresented = false
                    editingCredential = nil
                },
                onCancel: {
                    isEditorPresented = false
                    editingCredential = nil
                }
            )
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
                error: credentialStore.lastError,
                auditEvents: credentialStore.auditEvents,
                onSelect: { selectedCredentialID = $0.id },
                onNew: openNewCredential,
                onEdit: { item in
                    editingCredential = item
                    isEditorPresented = true
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
        guard newMasterPassword == repeatedMasterPassword else {
            initializationError = "两次输入不一致"
            return
        }
        initializationError = nil
        credentialStore.initialize(masterPassword: newMasterPassword)
        newMasterPassword = ""
        repeatedMasterPassword = ""
    }

    private func openNewCredential() {
        guard credentialStore.isUnlocked else { return }
        editingCredential = nil
        isEditorPresented = true
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
    let onNew: () -> Void

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
                if status == .unlocked {
                    Button(action: onNew) {
                        Label("新建凭证", systemImage: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.tactilePlain)
                }

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
    let onNew: () -> Void
    let onLock: () -> Void
    let onBackup: () -> Void

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
                Button(action: onBackup) {
                    Label("备份", systemImage: "externaldrive.badge.checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(height: 30)
                        .padding(.horizontal, 10)
                        .background(AppTheme.adaptiveWhite(0.68), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.tactilePlain)

                Button(action: onLock) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 34, height: 30)
                        .background(AppTheme.adaptiveWhite(0.68), in: Capsule())
                }
                .buttonStyle(.tactilePlain)
                .help("锁定凭证库")

                Button(action: onNew) {
                    Label("新建", systemImage: "plus")
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
        case .uninitialized: "设置主密码后开始保存个人凭证"
        case .locked: "输入主密码解锁；主密码不会被保存"
        case .unlocked: "\(count) 条凭证，敏感字段仅显式查看"
        }
    }
}

struct CredentialInitializeView: View {
    @Binding var masterPassword: String
    @Binding var repeatedPassword: String
    let error: String?
    let onInitialize: () -> Void

    var body: some View {
        CredentialAccessPanel(
            icon: "lock.shield.fill",
            title: "初始化凭证库",
            subtitle: "主密码无法找回。忘记后只能重置并清空凭证库。"
        ) {
            SecureField("主密码，至少 8 位", text: $masterPassword)
                .textFieldStyle(.roundedBorder)
            SecureField("再次输入主密码", text: $repeatedPassword)
                .textFieldStyle(.roundedBorder)

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
            .disabled(masterPassword.isEmpty || repeatedPassword.isEmpty)
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
    let error: String?
    let auditEvents: [CredentialAuditEvent]
    let onSelect: (CredentialItem) -> Void
    let onNew: () -> Void
    let onEdit: (CredentialItem) -> Void
    let onDelete: (CredentialItem) -> Void
    let onReveal: (CredentialItem) -> CredentialSecretPayload?
    let onCopy: (CredentialItem, String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            CredentialListPane(
                credentials: credentials,
                selectedCredential: selectedCredential,
                onSelect: onSelect,
                onNew: onNew
            )
            .frame(width: 360)

            Divider()
                .overlay(AppTheme.hairline)

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

struct CredentialListPane: View {
    let credentials: [CredentialItem]
    let selectedCredential: CredentialItem?
    let onSelect: (CredentialItem) -> Void
    let onNew: () -> Void

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
                        Button(action: onNew) {
                            Label("新建凭证", systemImage: "plus")
                        }
                        .buttonStyle(.tactilePlain)
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

            VStack(alignment: .leading, spacing: 10) {
                CredentialInfoRow(label: "账号", value: item.username.isEmpty ? "--" : item.username)
                CredentialInfoRow(label: "网址/服务", value: item.serviceURL.isEmpty ? "--" : item.serviceURL)
                CredentialInfoRow(label: "更新时间", value: item.updatedAt.formatted(.dateTime.year().month().day().hour().minute()))
            }

            Divider()
                .overlay(AppTheme.hairline)

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
                CredentialSensitiveValue(label: "密码 / Key / Token", value: secret.secretValue, onCopy: onCopy)
                CredentialSensitiveValue(label: "证书内容", value: secret.certificateBody, onCopy: onCopy)
                CredentialSensitiveValue(label: "备注", value: secret.notes, onCopy: onCopy)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    Text("已隐藏。点击查看后才会解密显示。")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.adaptiveWhite(0.62), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

struct CredentialSensitiveValue: View {
    let label: String
    let value: String
    let onCopy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.mutedInk)
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
            Text(value.isEmpty ? "--" : value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.ink)
                .textSelection(.enabled)
                .lineLimit(4)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.adaptiveWhite(0.66), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

struct CredentialEditorSheet: View {
    let item: CredentialItem?
    let initialSecret: CredentialSecretPayload?
    let onSave: (CredentialItem?, CredentialDraft) -> Void
    let onCancel: () -> Void
    @State private var draft: CredentialDraft

    init(
        item: CredentialItem?,
        initialSecret: CredentialSecretPayload?,
        onSave: @escaping (CredentialItem?, CredentialDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.item = item
        self.initialSecret = initialSecret
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: item.map { CredentialDraft(item: $0, secret: initialSecret ?? .empty) } ?? CredentialDraft())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item == nil ? "新建凭证" : "编辑凭证")
                        .font(.system(size: 20, weight: .bold))
                    Text("敏感字段会加密后保存，普通搜索不会索引明文。")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
                Spacer()
            }

            Form {
                TextField("标题", text: $draft.title)
                Picker("类型", selection: $draft.type) {
                    ForEach(CredentialType.allCases) { type in
                        Label(type.title, systemImage: type.icon).tag(type)
                    }
                }
                TextField("账号", text: $draft.username)
                TextField("网址 / 服务", text: $draft.serviceURL)
                SecureField("密码 / Key / Token", text: $draft.secretValue)
                TextField("证书内容", text: $draft.certificateBody, axis: .vertical)
                    .lineLimit(3...6)
                TextField("备注", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...6)
                TextField("标签，用逗号分隔", text: $draft.tagsText)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .buttonStyle(.borderless)
                Button("保存") {
                    onSave(item, draft)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.cleanedTitle.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 560)
        .frame(minHeight: 560)
        .background(AppTheme.workSurface)
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
