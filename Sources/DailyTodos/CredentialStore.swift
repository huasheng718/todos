import CryptoKit
import Foundation
import SQLite3

@MainActor
final class CredentialStore: ObservableObject {
    @Published private(set) var status: CredentialVaultStatus = .locked
    @Published private(set) var credentials: [CredentialItem] = []
    @Published private(set) var lastError: String?
    @Published private(set) var auditEvents: [CredentialAuditEvent] = []

    private let databaseURL: URL
    private let autoLockInterval: TimeInterval
    private var isDatabasePrepared = false
    private var vaultMetadata: CredentialVaultMetadata?
    private var sessionKey: SymmetricKey?
    private var lastActivityAt = Date()
    nonisolated(unsafe) private var db: OpaquePointer?

    var isUnlocked: Bool {
        status == .unlocked && sessionKey != nil
    }

    init(storageURL: URL? = nil, autoLockInterval: TimeInterval = 10 * 60) {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let appDirectory = baseURL.appendingPathComponent("DailyTodos", isDirectory: true)
        databaseURL = storageURL ?? appDirectory.appendingPathComponent("credentials.sqlite")
        self.autoLockInterval = autoLockInterval
    }

    deinit {
        sqlite3_close(db)
    }

    func load() {
        do {
            try prepareDatabase()
            vaultMetadata = try fetchVaultMetadata()
            status = vaultMetadata == nil ? .uninitialized : .locked
            credentials = []
            lastError = nil
        } catch {
            lastError = "读取凭证库失败：\(error.localizedDescription)"
        }
    }

    func initialize(masterPassword: String) {
        let password = masterPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard password.count >= 8 else {
            lastError = "主密码至少需要 8 个字符"
            return
        }

        do {
            try prepareDatabase()
            let (metadata, key) = try CredentialCrypto.createVaultMetadata(masterPassword: password)
            try saveVaultMetadata(metadata)
            vaultMetadata = metadata
            sessionKey = key
            status = .unlocked
            lastActivityAt = Date()
            credentials = try fetchCredentials()
            lastError = nil
            recordAudit(action: "初始化凭证库", credentialTitle: "凭证库")
        } catch {
            lastError = "初始化凭证库失败：\(error.localizedDescription)"
        }
    }

    func unlock(masterPassword: String) {
        do {
            try prepareDatabase()
            let metadata = try fetchVaultMetadata()
            guard let metadata else {
                status = .uninitialized
                return
            }
            sessionKey = try CredentialCrypto.unlock(masterPassword: masterPassword, metadata: metadata)
            vaultMetadata = metadata
            status = .unlocked
            lastActivityAt = Date()
            credentials = try fetchCredentials()
            lastError = nil
            recordAudit(action: "解锁凭证库", credentialTitle: "凭证库")
        } catch {
            sessionKey = nil
            credentials = []
            status = .locked
            lastError = "解锁失败：\(error.localizedDescription)"
        }
    }

    func lock() {
        sessionKey = nil
        credentials = []
        if vaultMetadata == nil {
            status = .uninitialized
        } else {
            status = .locked
        }
        recordAudit(action: "锁定凭证库", credentialTitle: "凭证库")
    }

    func resetVault() {
        do {
            try prepareDatabase()
            try execute("DELETE FROM credentials")
            try execute("DELETE FROM credential_vault")
            vaultMetadata = nil
            sessionKey = nil
            credentials = []
            status = .uninitialized
            lastError = nil
            recordAudit(action: "重置凭证库", credentialTitle: "凭证库")
        } catch {
            lastError = "重置凭证库失败：\(error.localizedDescription)"
        }
    }

    func ensureAutoLock() {
        guard isUnlocked else { return }
        if Date().timeIntervalSince(lastActivityAt) >= autoLockInterval {
            lock()
        }
    }

    func credentials(matching query: String, type: CredentialType?) -> [CredentialItem] {
        ensureAutoLock()
        guard isUnlocked else { return [] }
        return credentials
            .filter { $0.matches(query: query, type: type) }
            .sorted(by: sortCredentials)
    }

    @discardableResult
    func addCredential(_ draft: CredentialDraft) -> CredentialItem? {
        guard let key = activeKey() else { return nil }
        guard !draft.cleanedTitle.isEmpty else {
            lastError = "凭证标题不能为空"
            return nil
        }

        do {
            let now = Date()
            let item = CredentialItem(
                id: UUID(),
                title: draft.cleanedTitle,
                type: draft.type,
                username: draft.cleanedUsername,
                serviceURL: draft.cleanedServiceURL,
                tags: draft.cleanedTags,
                encryptedPayload: try CredentialCrypto.seal(draft.secretPayload, using: key),
                createdAt: now,
                updatedAt: now,
                lastViewedAt: nil,
                lastCopiedAt: nil,
                encryptionVersion: CredentialCrypto.version
            )
            try insert(item)
            credentials.insert(item, at: insertionIndex(for: item))
            touchActivity()
            lastError = nil
            return item
        } catch {
            lastError = "保存凭证失败：\(error.localizedDescription)"
            return nil
        }
    }

    func updateCredential(_ item: CredentialItem, draft: CredentialDraft) {
        guard let key = activeKey() else { return }
        guard let index = credentials.firstIndex(where: { $0.id == item.id }) else { return }
        guard !draft.cleanedTitle.isEmpty else {
            lastError = "凭证标题不能为空"
            return
        }

        do {
            var updated = credentials[index]
            updated.title = draft.cleanedTitle
            updated.type = draft.type
            updated.username = draft.cleanedUsername
            updated.serviceURL = draft.cleanedServiceURL
            updated.tags = draft.cleanedTags
            updated.encryptedPayload = try CredentialCrypto.seal(draft.secretPayload, using: key)
            updated.updatedAt = Date()
            updated.encryptionVersion = CredentialCrypto.version

            try update(updated)
            credentials.remove(at: index)
            credentials.insert(updated, at: insertionIndex(for: updated))
            touchActivity()
            lastError = nil
        } catch {
            lastError = "更新凭证失败：\(error.localizedDescription)"
        }
    }

    @discardableResult
    func importCredentials(_ drafts: [CredentialDraft]) -> Int {
        guard !drafts.isEmpty else { return 0 }
        var importedCount = 0
        for draft in drafts {
            if addCredential(draft) != nil {
                importedCount += 1
            }
        }
        if importedCount > 0 {
            recordAudit(action: "导入凭证", credentialTitle: "\(importedCount) 条")
        }
        return importedCount
    }

    func deleteCredential(_ item: CredentialItem) {
        guard activeKey() != nil else { return }
        do {
            try withPreparedStatement("DELETE FROM credentials WHERE id = ?") { statement in
                bindText(item.id.uuidString, to: statement, at: 1)
                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw CredentialSQLiteError.execute(message: databaseErrorMessage)
                }
            }
            credentials.removeAll { $0.id == item.id }
            touchActivity()
            lastError = nil
            recordAudit(action: "删除凭证", credentialTitle: item.title)
        } catch {
            lastError = "删除凭证失败：\(error.localizedDescription)"
        }
    }

    func secretPayload(for item: CredentialItem, auditAction: String? = nil) -> CredentialSecretPayload? {
        guard let key = activeKey() else { return nil }
        do {
            let secret = try CredentialCrypto.open(item.encryptedPayload, as: CredentialSecretPayload.self, using: key)
            if let auditAction {
                markAccess(item, action: auditAction)
            }
            touchActivity()
            lastError = nil
            return secret
        } catch {
            lastError = "读取敏感字段失败：\(error.localizedDescription)"
            return nil
        }
    }

    func exportBackup(password: String) -> String? {
        guard isUnlocked else {
            lastError = "请先解锁凭证库"
            return nil
        }
        let cleanedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedPassword.count >= 8 else {
            lastError = "备份密码至少需要 8 个字符"
            return nil
        }

        do {
            let backup = CredentialBackupEnvelope(
                version: CredentialCrypto.version,
                exportedAt: Date(),
                vaultMetadata: vaultMetadata,
                credentials: credentials.map(CredentialBackupRecord.init)
            )
            let salt = try CredentialCrypto.randomData(byteCount: 16)
            let key = try CredentialCrypto.deriveKey(password: cleanedPassword, salt: salt, iterations: CredentialCrypto.defaultIterations)
            let payload = try CredentialCrypto.seal(backup, using: key)
            let file = CredentialBackupFile(
                version: CredentialCrypto.version,
                kdf: CredentialCrypto.kdfName,
                iterations: CredentialCrypto.defaultIterations,
                salt: salt,
                payload: payload
            )
            let data = try JSONEncoder.credentialBackupEncoder.encode(file)
            touchActivity()
            lastError = nil
            recordAudit(action: "导出加密备份", credentialTitle: "凭证库")
            return String(data: data, encoding: .utf8)
        } catch {
            lastError = "导出备份失败：\(error.localizedDescription)"
            return nil
        }
    }

    func importBackup(_ json: String, password: String, replaceExisting: Bool = false) {
        do {
            let data = Data(json.utf8)
            let file = try JSONDecoder.credentialBackupDecoder.decode(CredentialBackupFile.self, from: data)
            guard file.version == CredentialCrypto.version, file.kdf == CredentialCrypto.kdfName else {
                throw CredentialCryptoError.unsupportedVersion
            }

            let key = try CredentialCrypto.deriveKey(password: password, salt: file.salt, iterations: file.iterations)
            let backup = try CredentialCrypto.open(file.payload, as: CredentialBackupEnvelope.self, using: key)

            try prepareDatabase()
            try execute("BEGIN TRANSACTION")
            do {
                if replaceExisting {
                    try execute("DELETE FROM credentials")
                    try execute("DELETE FROM credential_vault")
                }
                if let metadata = backup.vaultMetadata {
                    try saveVaultMetadata(metadata)
                    vaultMetadata = metadata
                }
                for record in backup.credentials {
                    try insert(record.item)
                }
                try execute("COMMIT")
            } catch {
                try? execute("ROLLBACK")
                throw error
            }

            if isUnlocked {
                credentials = try fetchCredentials()
            } else {
                status = vaultMetadata == nil ? .uninitialized : .locked
            }
            touchActivity()
            lastError = nil
            recordAudit(action: "导入加密备份", credentialTitle: "凭证库")
        } catch {
            lastError = "导入备份失败：\(error.localizedDescription)"
        }
    }

    private func activeKey() -> SymmetricKey? {
        ensureAutoLock()
        guard let sessionKey, status == .unlocked else {
            lastError = "请先解锁凭证库"
            return nil
        }
        return sessionKey
    }

    private func touchActivity() {
        lastActivityAt = Date()
    }

    private func markAccess(_ item: CredentialItem, action: String) {
        guard let index = credentials.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = credentials[index]
        let now = Date()
        if action.contains("复制") {
            updated.lastCopiedAt = now
        } else {
            updated.lastViewedAt = now
        }
        do {
            try updateAccessMetadata(updated)
            credentials[index] = updated
            recordAudit(action: action, credentialTitle: item.title)
        } catch {
            lastError = "记录凭证操作失败：\(error.localizedDescription)"
        }
    }

    private func recordAudit(action: String, credentialTitle: String) {
        auditEvents.insert(
            CredentialAuditEvent(action: action, credentialTitle: credentialTitle, createdAt: Date()),
            at: 0
        )
        if auditEvents.count > 30 {
            auditEvents.removeLast(auditEvents.count - 30)
        }
    }

    private func openDatabase() throws {
        if db != nil { return }

        let directory = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            throw CredentialSQLiteError.open(message: databaseErrorMessage)
        }

        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
    }

    private func prepareDatabase() throws {
        try openDatabase()
        guard !isDatabasePrepared else { return }
        try createSchema()
        isDatabasePrepared = true
    }

    private func createSchema() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS credential_vault (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                metadata_json TEXT NOT NULL
            )
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS credentials (
                id TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                type TEXT NOT NULL,
                username TEXT NOT NULL DEFAULT '',
                service_url TEXT NOT NULL DEFAULT '',
                tags_json TEXT NOT NULL DEFAULT '[]',
                payload_nonce TEXT NOT NULL,
                payload_ciphertext TEXT NOT NULL,
                payload_tag TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                last_viewed_at REAL,
                last_copied_at REAL,
                encryption_version INTEGER NOT NULL DEFAULT 1
            )
            """
        )
        try execute("CREATE INDEX IF NOT EXISTS idx_credentials_updated ON credentials(updated_at)")
        try execute("CREATE INDEX IF NOT EXISTS idx_credentials_type_updated ON credentials(type, updated_at)")
    }

    private func saveVaultMetadata(_ metadata: CredentialVaultMetadata) throws {
        let data = try JSONEncoder.credentialBackupEncoder.encode(metadata)
        guard let json = String(data: data, encoding: .utf8) else {
            throw CredentialSQLiteError.decode
        }
        try withPreparedStatement("INSERT OR REPLACE INTO credential_vault (id, metadata_json) VALUES (1, ?)") { statement in
            bindText(json, to: statement, at: 1)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw CredentialSQLiteError.execute(message: databaseErrorMessage)
            }
        }
    }

    private func fetchVaultMetadata() throws -> CredentialVaultMetadata? {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, "SELECT metadata_json FROM credential_vault WHERE id = 1", -1, &statement, nil) == SQLITE_OK else {
            throw CredentialSQLiteError.prepare(message: databaseErrorMessage)
        }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }
        guard let json = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
              let data = json.data(using: .utf8) else {
            throw CredentialSQLiteError.decode
        }
        return try JSONDecoder.credentialBackupDecoder.decode(CredentialVaultMetadata.self, from: data)
    }

    private func fetchCredentials() throws -> [CredentialItem] {
        let sql =
            """
            SELECT id, title, type, username, service_url, tags_json, payload_nonce, payload_ciphertext, payload_tag,
                   created_at, updated_at, last_viewed_at, last_copied_at, encryption_version
            FROM credentials
            """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CredentialSQLiteError.prepare(message: databaseErrorMessage)
        }

        var result: [CredentialItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(try credential(from: statement))
        }
        return result.sorted(by: sortCredentials)
    }

    private func insert(_ item: CredentialItem) throws {
        let sql =
            """
            INSERT OR REPLACE INTO credentials
            (id, title, type, username, service_url, tags_json, payload_nonce, payload_ciphertext, payload_tag,
             created_at, updated_at, last_viewed_at, last_copied_at, encryption_version)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        try withPreparedStatement(sql) { statement in
            bind(item, to: statement)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw CredentialSQLiteError.execute(message: databaseErrorMessage)
            }
        }
    }

    private func update(_ item: CredentialItem) throws {
        let sql =
            """
            UPDATE credentials
            SET title = ?, type = ?, username = ?, service_url = ?, tags_json = ?,
                payload_nonce = ?, payload_ciphertext = ?, payload_tag = ?,
                updated_at = ?, last_viewed_at = ?, last_copied_at = ?, encryption_version = ?
            WHERE id = ?
            """
        try withPreparedStatement(sql) { statement in
            bindText(item.title, to: statement, at: 1)
            bindText(item.type.rawValue, to: statement, at: 2)
            bindText(item.username, to: statement, at: 3)
            bindText(item.serviceURL, to: statement, at: 4)
            bindText(tagsJSON(for: item.tags), to: statement, at: 5)
            bindText(item.encryptedPayload.nonce.base64EncodedString(), to: statement, at: 6)
            bindText(item.encryptedPayload.ciphertext.base64EncodedString(), to: statement, at: 7)
            bindText(item.encryptedPayload.tag.base64EncodedString(), to: statement, at: 8)
            sqlite3_bind_double(statement, 9, item.updatedAt.timeIntervalSince1970)
            bindOptionalDate(item.lastViewedAt, to: statement, at: 10)
            bindOptionalDate(item.lastCopiedAt, to: statement, at: 11)
            sqlite3_bind_int(statement, 12, Int32(item.encryptionVersion))
            bindText(item.id.uuidString, to: statement, at: 13)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw CredentialSQLiteError.execute(message: databaseErrorMessage)
            }
        }
    }

    private func updateAccessMetadata(_ item: CredentialItem) throws {
        let sql =
            """
            UPDATE credentials
            SET last_viewed_at = ?, last_copied_at = ?
            WHERE id = ?
            """
        try withPreparedStatement(sql) { statement in
            bindOptionalDate(item.lastViewedAt, to: statement, at: 1)
            bindOptionalDate(item.lastCopiedAt, to: statement, at: 2)
            bindText(item.id.uuidString, to: statement, at: 3)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw CredentialSQLiteError.execute(message: databaseErrorMessage)
            }
        }
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw CredentialSQLiteError.execute(message: databaseErrorMessage)
        }
    }

    private func withPreparedStatement(_ sql: String, _ body: (OpaquePointer?) throws -> Void) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw CredentialSQLiteError.prepare(message: databaseErrorMessage)
        }
        try body(statement)
    }

    private func bind(_ item: CredentialItem, to statement: OpaquePointer?) {
        bindText(item.id.uuidString, to: statement, at: 1)
        bindText(item.title, to: statement, at: 2)
        bindText(item.type.rawValue, to: statement, at: 3)
        bindText(item.username, to: statement, at: 4)
        bindText(item.serviceURL, to: statement, at: 5)
        bindText(tagsJSON(for: item.tags), to: statement, at: 6)
        bindText(item.encryptedPayload.nonce.base64EncodedString(), to: statement, at: 7)
        bindText(item.encryptedPayload.ciphertext.base64EncodedString(), to: statement, at: 8)
        bindText(item.encryptedPayload.tag.base64EncodedString(), to: statement, at: 9)
        sqlite3_bind_double(statement, 10, item.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 11, item.updatedAt.timeIntervalSince1970)
        bindOptionalDate(item.lastViewedAt, to: statement, at: 12)
        bindOptionalDate(item.lastCopiedAt, to: statement, at: 13)
        sqlite3_bind_int(statement, 14, Int32(item.encryptionVersion))
    }

    private func bindText(_ value: String, to statement: OpaquePointer?, at index: Int32) {
        sqlite3_bind_text(statement, index, value, -1, CREDENTIAL_SQLITE_TRANSIENT)
    }

    private func bindOptionalDate(_ value: Date?, to statement: OpaquePointer?, at index: Int32) {
        if let value {
            sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func credential(from statement: OpaquePointer?) throws -> CredentialItem {
        guard
            let idText = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
            let id = UUID(uuidString: idText),
            let title = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
            let typeText = sqlite3_column_text(statement, 2).map({ String(cString: $0) }),
            let username = sqlite3_column_text(statement, 3).map({ String(cString: $0) }),
            let serviceURL = sqlite3_column_text(statement, 4).map({ String(cString: $0) }),
            let tagsJSON = sqlite3_column_text(statement, 5).map({ String(cString: $0) }),
            let nonceText = sqlite3_column_text(statement, 6).map({ String(cString: $0) }),
            let nonce = Data(base64Encoded: nonceText),
            let ciphertextText = sqlite3_column_text(statement, 7).map({ String(cString: $0) }),
            let ciphertext = Data(base64Encoded: ciphertextText),
            let tagText = sqlite3_column_text(statement, 8).map({ String(cString: $0) }),
            let tag = Data(base64Encoded: tagText)
        else {
            throw CredentialSQLiteError.decode
        }

        return CredentialItem(
            id: id,
            title: title,
            type: CredentialType(rawValue: typeText) ?? .other,
            username: username,
            serviceURL: serviceURL,
            tags: decodeTags(from: tagsJSON),
            encryptedPayload: CredentialEncryptedPayload(nonce: nonce, ciphertext: ciphertext, tag: tag),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 9)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 10)),
            lastViewedAt: optionalDate(from: statement, column: 11),
            lastCopiedAt: optionalDate(from: statement, column: 12),
            encryptionVersion: Int(sqlite3_column_int(statement, 13))
        )
    }

    private func optionalDate(from statement: OpaquePointer?, column: Int32) -> Date? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, column))
    }

    private func tagsJSON(for tags: [String]) -> String {
        guard let data = try? JSONEncoder.credentialBackupEncoder.encode(tags),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func decodeTags(from json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let tags = try? JSONDecoder.credentialBackupDecoder.decode([String].self, from: data) else {
            return []
        }
        return tags
    }

    private func insertionIndex(for item: CredentialItem) -> Int {
        credentials.firstIndex { sortCredentials(item, $0) } ?? credentials.endIndex
    }

    private func sortCredentials(_ lhs: CredentialItem, _ rhs: CredentialItem) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    private var databaseErrorMessage: String {
        guard let message = sqlite3_errmsg(db) else {
            return "unknown SQLite error"
        }
        return String(cString: message)
    }
}

private struct CredentialBackupRecord: Codable {
    var id: UUID
    var title: String
    var type: CredentialType
    var username: String
    var serviceURL: String
    var tags: [String]
    var encryptedPayload: CredentialEncryptedPayload
    var createdAt: Date
    var updatedAt: Date
    var lastViewedAt: Date?
    var lastCopiedAt: Date?
    var encryptionVersion: Int

    init(_ item: CredentialItem) {
        id = item.id
        title = item.title
        type = item.type
        username = item.username
        serviceURL = item.serviceURL
        tags = item.tags
        encryptedPayload = item.encryptedPayload
        createdAt = item.createdAt
        updatedAt = item.updatedAt
        lastViewedAt = item.lastViewedAt
        lastCopiedAt = item.lastCopiedAt
        encryptionVersion = item.encryptionVersion
    }

    var item: CredentialItem {
        CredentialItem(
            id: id,
            title: title,
            type: type,
            username: username,
            serviceURL: serviceURL,
            tags: tags,
            encryptedPayload: encryptedPayload,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastViewedAt: lastViewedAt,
            lastCopiedAt: lastCopiedAt,
            encryptionVersion: encryptionVersion
        )
    }
}

private struct CredentialBackupEnvelope: Codable {
    var version: Int
    var exportedAt: Date
    var vaultMetadata: CredentialVaultMetadata?
    var credentials: [CredentialBackupRecord]
}

private struct CredentialBackupFile: Codable {
    var version: Int
    var kdf: String
    var iterations: Int
    var salt: Data
    var payload: CredentialEncryptedPayload
}

private enum CredentialSQLiteError: LocalizedError {
    case open(message: String)
    case prepare(message: String)
    case execute(message: String)
    case decode

    var errorDescription: String? {
        switch self {
        case .open(let message):
            return "打开 SQLite 数据库失败：\(message)"
        case .prepare(let message):
            return "准备 SQLite 语句失败：\(message)"
        case .execute(let message):
            return "执行 SQLite 语句失败：\(message)"
        case .decode:
            return "解析 SQLite 数据失败"
        }
    }
}

private extension JSONEncoder {
    static var credentialBackupEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.dataEncodingStrategy = .base64
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var credentialBackupDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.dataDecodingStrategy = .base64
        return decoder
    }
}

private let CREDENTIAL_SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
