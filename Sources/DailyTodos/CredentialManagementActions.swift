import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class CredentialManagementActions: ObservableObject {
    @Published var notice: CredentialNotice?
    @Published var isBackupSheetPresented = false
    @Published var securityMode: CredentialSecurityMode?

    func enableMasterPassword(
        store: CredentialStore,
        password: String,
        repeatedPassword: String
    ) {
        guard password == repeatedPassword else {
            notice = CredentialNotice(message: "两次主密码输入不一致", isError: true)
            return
        }
        store.setMasterPasswordRequired(true, newMasterPassword: password)
        if store.requiresMasterPassword {
            securityMode = nil
            notice = CredentialNotice(message: "已开启主密码验证", isError: false)
        }
    }

    func updateMasterPasswordRequirement(store: CredentialStore, required: Bool) {
        notice = nil
        if required {
            securityMode = .enableMasterPassword
        } else {
            store.setMasterPasswordRequired(false)
            if !store.requiresMasterPassword {
                securityMode = nil
                notice = CredentialNotice(message: "已关闭主密码验证", isError: false)
            }
        }
    }

    func importDrafts(_ drafts: [CredentialDraft], store: CredentialStore) -> Int {
        guard !drafts.isEmpty else {
            notice = CredentialNotice(message: "没有识别到可导入的凭证", isError: true)
            return 0
        }
        let importedCount = store.importCredentials(drafts)
        if importedCount > 0 {
            securityMode = nil
            notice = CredentialNotice(message: "已导入 \(importedCount) 条凭证", isError: false)
        } else {
            notice = CredentialNotice(message: store.lastError ?? "导入失败，请检查文件内容", isError: true)
        }
        return importedCount
    }

    func importCredentialsFromFile(store: CredentialStore) {
        guard store.isUnlocked else {
            notice = CredentialNotice(message: "请先解锁凭证库", isError: true)
            return
        }
        notice = nil
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.commaSeparatedText, .plainText, .text]
        panel.begin { [weak self, weak store] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                guard let self, let store else { return }
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    let drafts = CredentialImportParser.drafts(fromFileText: text)
                    _ = self.importDrafts(drafts, store: store)
                } catch {
                    self.notice = CredentialNotice(message: "读取文件失败：\(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    func showBackupSheet(store: CredentialStore) {
        guard store.isUnlocked else {
            notice = CredentialNotice(message: "请先解锁凭证库", isError: true)
            return
        }
        isBackupSheetPresented = true
    }

    func clearTransientModes() {
        securityMode = nil
    }
}
