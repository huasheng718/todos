import Foundation

enum CredentialSecurityMode: Equatable, Sendable {
    case enableMasterPassword
}

struct CredentialNotice: Equatable, Sendable {
    let message: String
    let isError: Bool
}

enum CredentialType: String, CaseIterable, Codable, Identifiable, Sendable {
    case website
    case software
    case apiKey
    case certificate
    case server
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .website: "网站账号"
        case .software: "软件账号"
        case .apiKey: "API Key"
        case .certificate: "证书"
        case .server: "服务器"
        case .other: "其他"
        }
    }

    var icon: String {
        switch self {
        case .website: "globe"
        case .software: "app.badge"
        case .apiKey: "key.horizontal"
        case .certificate: "doc.badge.gearshape"
        case .server: "server.rack"
        case .other: "lock.rectangle"
        }
    }
}

struct CredentialItem: Identifiable, Equatable, Sendable {
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

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayService: String {
        let cleanedURL = serviceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedURL.isEmpty {
            return cleanedURL
        }
        let cleanedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedUsername.isEmpty ? "--" : cleanedUsername
    }

    func matches(query: String, type selectedType: CredentialType?) -> Bool {
        if let selectedType, type != selectedType {
            return false
        }

        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else { return true }

        return title.localizedCaseInsensitiveContains(cleanedQuery)
            || username.localizedCaseInsensitiveContains(cleanedQuery)
            || serviceURL.localizedCaseInsensitiveContains(cleanedQuery)
            || type.title.localizedCaseInsensitiveContains(cleanedQuery)
            || tags.contains { $0.localizedCaseInsensitiveContains(cleanedQuery) }
    }
}

struct CredentialEncryptedPayload: Codable, Equatable, Sendable {
    var nonce: Data
    var ciphertext: Data
    var tag: Data
}

struct CredentialSecretPayload: Codable, Equatable, Sendable {
    var secretValue: String
    var certificateBody: String
    var notes: String

    static let empty = CredentialSecretPayload(secretValue: "", certificateBody: "", notes: "")
}

struct CredentialDraft: Equatable, Sendable {
    var title: String = ""
    var type: CredentialType = .website
    var username: String = ""
    var serviceURL: String = ""
    var secretValue: String = ""
    var certificateBody: String = ""
    var notes: String = ""
    var tagsText: String = ""

    init() {}

    init(item: CredentialItem, secret: CredentialSecretPayload) {
        title = item.title
        type = item.type
        username = item.username
        serviceURL = item.serviceURL
        secretValue = secret.secretValue
        certificateBody = secret.certificateBody
        notes = secret.notes
        tagsText = item.tags.joined(separator: ", ")
    }

    var cleanedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanedServiceURL: String {
        serviceURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanedTags: [String] {
        tagsText
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "\n" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var secretPayload: CredentialSecretPayload {
        CredentialSecretPayload(
            secretValue: secretValue.trimmingCharacters(in: .whitespacesAndNewlines),
            certificateBody: certificateBody.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

enum CredentialVaultStatus: Equatable, Sendable {
    case uninitialized
    case locked
    case unlocked
}

struct CredentialAuditEvent: Identifiable, Equatable, Sendable {
    var id = UUID()
    var action: String
    var credentialTitle: String
    var createdAt: Date
}
