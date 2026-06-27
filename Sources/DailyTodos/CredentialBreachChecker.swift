import CryptoKit
import Foundation

enum CredentialEmailBreachResult: Equatable, Sendable {
    case skippedNotEmail
    case notFound(email: String)
    case exposed(email: String, breachNames: [String])
    case failed(message: String)

    var isExposed: Bool {
        if case .exposed = self {
            return true
        }
        return false
    }
}

enum CredentialPasswordBreachResult: Equatable, Sendable {
    case skippedEmpty
    case notFound
    case exposed(occurrenceCount: Int)
    case failed(message: String)

    var isExposed: Bool {
        if case .exposed = self {
            return true
        }
        return false
    }
}

struct CredentialBreachCheckSummary: Equatable, Sendable {
    var email: CredentialEmailBreachResult
    var password: CredentialPasswordBreachResult
}

enum CredentialBreachChecker {
    private static let userAgent = "DailyTodos/1.2 CredentialBreachCheck"
    private static let xposedOrNotBaseURL = "https://api.xposedornot.com/v1/check-email/"
    private static let pwnedPasswordsBaseURL = "https://api.pwnedpasswords.com/range/"

    static func checkCredential(username: String, password: String) async -> CredentialBreachCheckSummary {
        async let emailResult = checkEmailIfPossible(username)
        async let passwordResult = checkPasswordIfPossible(password)
        return await CredentialBreachCheckSummary(email: emailResult, password: passwordResult)
    }

    static func checkEmailIfPossible(_ value: String) async -> CredentialEmailBreachResult {
        guard let email = emailAddress(in: value) else {
            return .skippedNotEmail
        }

        do {
            return try await checkEmail(email)
        } catch {
            return .failed(message: readableMessage(for: error))
        }
    }

    static func checkPasswordIfPossible(_ password: String) async -> CredentialPasswordBreachResult {
        let cleanedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedPassword.isEmpty else {
            return .skippedEmpty
        }

        do {
            return try await checkPassword(cleanedPassword)
        } catch {
            return .failed(message: readableMessage(for: error))
        }
    }

    static func emailAddress(in value: String) -> String? {
        let pattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
        guard let match = value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        return String(value[match]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func passwordSHA1PrefixSuffix(_ password: String) -> (prefix: String, suffix: String) {
        let digest = Insecure.SHA1.hash(data: Data(password.utf8))
        let hash = digest.map { String(format: "%02X", $0) }.joined()
        let splitIndex = hash.index(hash.startIndex, offsetBy: 5)
        return (String(hash[..<splitIndex]), String(hash[splitIndex...]))
    }

    static func parsePwnedPasswordRangeResponse(_ text: String, matching suffix: String) -> Int {
        let expectedSuffix = suffix.uppercased()
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, parts[0].uppercased() == expectedSuffix else {
                continue
            }
            return Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        }
        return 0
    }

    static func parseXposedOrNotEmailResponse(_ data: Data, email: String) throws -> CredentialEmailBreachResult {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            throw CredentialBreachCheckerError.invalidResponse
        }
        guard let dictionary = jsonObject as? [String: Any] else {
            throw CredentialBreachCheckerError.invalidResponse
        }

        if let error = dictionary["Error"] as? String,
           error.localizedCaseInsensitiveContains("not found") {
            return .notFound(email: email)
        }

        let breachNames = breachNames(from: dictionary["breaches"])
        if !breachNames.isEmpty {
            return .exposed(email: email, breachNames: breachNames)
        }

        return .notFound(email: email)
    }

    private static func checkEmail(_ email: String) async throws -> CredentialEmailBreachResult {
        guard let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: xposedOrNotBaseURL + encodedEmail) else {
            throw CredentialBreachCheckerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CredentialBreachCheckerError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try parseXposedOrNotEmailResponse(data, email: email)
        case 404:
            return .notFound(email: email)
        case 403, 503:
            throw CredentialBreachCheckerError.serviceUnavailable
        case 429:
            throw CredentialBreachCheckerError.rateLimited
        default:
            throw CredentialBreachCheckerError.httpStatus(httpResponse.statusCode)
        }
    }

    private static func checkPassword(_ password: String) async throws -> CredentialPasswordBreachResult {
        let hashParts = passwordSHA1PrefixSuffix(password)
        guard let url = URL(string: pwnedPasswordsBaseURL + hashParts.prefix) else {
            throw CredentialBreachCheckerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("text/plain", forHTTPHeaderField: "Accept")
        request.setValue("true", forHTTPHeaderField: "Add-Padding")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CredentialBreachCheckerError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw CredentialBreachCheckerError.httpStatus(httpResponse.statusCode)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw CredentialBreachCheckerError.invalidResponse
        }

        let occurrenceCount = parsePwnedPasswordRangeResponse(text, matching: hashParts.suffix)
        if occurrenceCount > 0 {
            return .exposed(occurrenceCount: occurrenceCount)
        }
        return .notFound
    }

    private static func breachNames(from value: Any?) -> [String] {
        var names: [String] = []

        func collect(_ item: Any?) {
            if let name = item as? String {
                let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanedName.isEmpty {
                    names.append(cleanedName)
                }
                return
            }
            if let array = item as? [Any] {
                for child in array {
                    collect(child)
                }
            }
        }

        collect(value)
        return Array(Set(names)).sorted()
    }

    private static func readableMessage(for error: Error) -> String {
        if let breachError = error as? CredentialBreachCheckerError {
            return breachError.errorDescription ?? "风险检查失败"
        }
        return "风险检查失败"
    }
}

private enum CredentialBreachCheckerError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serviceUnavailable
    case rateLimited
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "检查地址无效"
        case .invalidResponse:
            "检查结果无法解析"
        case .serviceUnavailable:
            "XposedOrNot 暂不可用"
        case .rateLimited:
            "检查过于频繁，稍后再试"
        case .httpStatus:
            "风险检查服务暂不可用"
        }
    }
}
