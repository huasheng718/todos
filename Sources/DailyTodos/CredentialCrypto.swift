import CryptoKit
import Foundation
import Security

enum CredentialCryptoError: LocalizedError {
    case invalidPassword
    case invalidEnvelope
    case randomBytesFailed
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .invalidPassword:
            return "主密码错误或数据已损坏"
        case .invalidEnvelope:
            return "加密数据格式无效"
        case .randomBytesFailed:
            return "生成安全随机数失败"
        case .unsupportedVersion:
            return "不支持的加密版本"
        }
    }
}

struct CredentialVaultMetadata: Codable, Equatable {
    var version: Int
    var kdf: String
    var iterations: Int
    var salt: Data
    var verifier: CredentialEncryptedPayload
    var createdAt: Date
    var updatedAt: Date
    var requiresMasterPassword: Bool

    init(
        version: Int,
        kdf: String,
        iterations: Int,
        salt: Data,
        verifier: CredentialEncryptedPayload,
        createdAt: Date,
        updatedAt: Date,
        requiresMasterPassword: Bool
    ) {
        self.version = version
        self.kdf = kdf
        self.iterations = iterations
        self.salt = salt
        self.verifier = verifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.requiresMasterPassword = requiresMasterPassword
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case kdf
        case iterations
        case salt
        case verifier
        case createdAt
        case updatedAt
        case requiresMasterPassword
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        kdf = try container.decode(String.self, forKey: .kdf)
        iterations = try container.decode(Int.self, forKey: .iterations)
        salt = try container.decode(Data.self, forKey: .salt)
        verifier = try container.decode(CredentialEncryptedPayload.self, forKey: .verifier)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        requiresMasterPassword = try container.decodeIfPresent(Bool.self, forKey: .requiresMasterPassword) ?? true
    }
}

enum CredentialCrypto {
    static let version = 1
    static let kdfName = "PBKDF2-HMAC-SHA256"
    static let defaultIterations = 120_000
    private static let keyByteCount = 32
    private static let saltByteCount = 16
    private static let verifierPlaintext = Data("DailyTodos.CredentialVault.v1".utf8)
    private static let localVaultPassword = "DailyTodos.CredentialVault.LocalMode.v1"

    static func createVaultMetadata(masterPassword: String, requiresMasterPassword: Bool = true, now: Date = Date()) throws -> (CredentialVaultMetadata, SymmetricKey) {
        let salt = try randomData(byteCount: saltByteCount)
        let key = try deriveKey(password: masterPassword, salt: salt, iterations: defaultIterations)
        let verifier = try seal(verifierPlaintext, using: key)
        let metadata = CredentialVaultMetadata(
            version: version,
            kdf: kdfName,
            iterations: defaultIterations,
            salt: salt,
            verifier: verifier,
            createdAt: now,
            updatedAt: now,
            requiresMasterPassword: requiresMasterPassword
        )
        return (metadata, key)
    }

    static func createLocalVaultMetadata(now: Date = Date()) throws -> (CredentialVaultMetadata, SymmetricKey) {
        try createVaultMetadata(masterPassword: localVaultPassword, requiresMasterPassword: false, now: now)
    }

    static func unlockLocal(metadata: CredentialVaultMetadata) throws -> SymmetricKey {
        try unlock(masterPassword: localVaultPassword, metadata: metadata)
    }

    static func unlock(masterPassword: String, metadata: CredentialVaultMetadata) throws -> SymmetricKey {
        guard metadata.version == version, metadata.kdf == kdfName else {
            throw CredentialCryptoError.unsupportedVersion
        }

        let key = try deriveKey(password: masterPassword, salt: metadata.salt, iterations: metadata.iterations)
        let opened = try open(metadata.verifier, using: key)
        guard opened == verifierPlaintext else {
            throw CredentialCryptoError.invalidPassword
        }
        return key
    }

    static func seal<T: Encodable>(_ value: T, using key: SymmetricKey) throws -> CredentialEncryptedPayload {
        let data = try JSONEncoder.credentialEncoder.encode(value)
        return try seal(data, using: key)
    }

    static func open<T: Decodable>(_ payload: CredentialEncryptedPayload, as type: T.Type, using key: SymmetricKey) throws -> T {
        let data = try open(payload, using: key)
        return try JSONDecoder.credentialDecoder.decode(type, from: data)
    }

    static func seal(_ data: Data, using key: SymmetricKey) throws -> CredentialEncryptedPayload {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return CredentialEncryptedPayload(
            nonce: Data(sealedBox.nonce),
            ciphertext: sealedBox.ciphertext,
            tag: sealedBox.tag
        )
    }

    static func open(_ payload: CredentialEncryptedPayload, using key: SymmetricKey) throws -> Data {
        do {
            let nonce = try AES.GCM.Nonce(data: payload.nonce)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: payload.ciphertext, tag: payload.tag)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw CredentialCryptoError.invalidPassword
        }
    }

    static func deriveKey(password: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        guard iterations > 0 else { throw CredentialCryptoError.invalidEnvelope }
        let passwordBytes = Array(password.utf8)
        let saltBytes = Array(salt)
        let derived = pbkdf2SHA256(password: passwordBytes, salt: saltBytes, iterations: iterations, keyByteCount: keyByteCount)
        return SymmetricKey(data: Data(derived))
    }

    static func randomData(byteCount: Int) throws -> Data {
        var data = Data(count: byteCount)
        let status = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, byteCount, bytes.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw CredentialCryptoError.randomBytesFailed
        }
        return data
    }

    private static func pbkdf2SHA256(password: [UInt8], salt: [UInt8], iterations: Int, keyByteCount: Int) -> [UInt8] {
        let hashByteCount = 32
        let blockCount = Int(ceil(Double(keyByteCount) / Double(hashByteCount)))
        var derived: [UInt8] = []
        derived.reserveCapacity(blockCount * hashByteCount)

        for blockIndex in 1...blockCount {
            var blockSalt = salt
            blockSalt.append(UInt8((blockIndex >> 24) & 0xff))
            blockSalt.append(UInt8((blockIndex >> 16) & 0xff))
            blockSalt.append(UInt8((blockIndex >> 8) & 0xff))
            blockSalt.append(UInt8(blockIndex & 0xff))

            var u = hmacSHA256(key: password, message: blockSalt)
            var t = u
            if iterations > 1 {
                for _ in 2...iterations {
                    u = hmacSHA256(key: password, message: u)
                    for index in 0..<t.count {
                        t[index] ^= u[index]
                    }
                }
            }
            derived.append(contentsOf: t)
        }

        return Array(derived.prefix(keyByteCount))
    }

    private static func hmacSHA256(key: [UInt8], message: [UInt8]) -> [UInt8] {
        let key = SymmetricKey(data: Data(key))
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: Data(message), using: key)
        return Array(authenticationCode)
    }
}

private extension JSONEncoder {
    static var credentialEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.dataEncodingStrategy = .base64
        return encoder
    }
}

private extension JSONDecoder {
    static var credentialDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.dataDecodingStrategy = .base64
        return decoder
    }
}
