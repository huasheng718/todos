import Foundation
import Security

enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case deepSeek

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "deepSeek":
            self = .deepSeek
        default:
            self = .deepSeek
        }
    }

    var title: String {
        switch self {
        case .deepSeek: "DeepSeek"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .deepSeek: "https://api.deepseek.com"
        }
    }

    var defaultModel: String {
        switch self {
        case .deepSeek: "deepseek-v4-flash"
        }
    }
}

struct AIConfiguration: Codable, Equatable {
    var isEnabled: Bool
    var provider: AIProvider
    var baseURL: String
    var model: String

    static let storageKey = "dailyTodos.aiConfiguration"
    static let `default` = AIConfiguration(
        isEnabled: false,
        provider: .deepSeek,
        baseURL: AIProvider.deepSeek.defaultBaseURL,
        model: AIProvider.deepSeek.defaultModel
    )

    var cleanedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanedModel: String {
        let value = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? provider.defaultModel : value
    }

    var hasEndpoint: Bool {
        !cleanedBaseURL.isEmpty && !cleanedModel.isEmpty
    }

    var canUse: Bool {
        isEnabled && hasEndpoint
    }
}

@MainActor
final class AISettingsStore: ObservableObject {
    @Published var configuration: AIConfiguration {
        didSet {
            save()
        }
    }
    @Published var apiKey: String {
        didSet {
            if apiKey != oldValue {
                connectionMessage = nil
                connectionSucceeded = false
                persistAPIKeyQuietly()
            }
        }
    }
    @Published private(set) var isTestingConnection = false
    @Published private(set) var connectionMessage: String?
    @Published private(set) var connectionSucceeded = false

    init() {
        configuration = Self.loadConfiguration()
        apiKey = (try? KeychainSecretStore.read(service: Self.keychainService, account: Self.keychainAccount)) ?? ""
    }

    func resetForSelectedProvider() {
        configuration.baseURL = configuration.provider.defaultBaseURL
        configuration.model = configuration.provider.defaultModel
        connectionMessage = nil
        connectionSucceeded = false
    }

    func testConnection() async {
        isTestingConnection = true
        connectionMessage = nil
        connectionSucceeded = false
        var currentConfiguration = configuration
        currentConfiguration.isEnabled = true
        let currentAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try saveAPIKey()
            let reply = try await AIClient.shared.testConnection(configuration: currentConfiguration, apiKey: currentAPIKey)
            connectionSucceeded = true
            connectionMessage = reply.isEmpty ? "连接成功" : "连接成功：\(reply)"
        } catch {
            connectionSucceeded = false
            connectionMessage = "连接失败：\(error.localizedDescription)"
        }

        isTestingConnection = false
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canUseAI: Bool {
        configuration.canUse && hasAPIKey
    }

    func saveAPIKey() throws {
        let cleaned = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            try KeychainSecretStore.delete(service: Self.keychainService, account: Self.keychainAccount)
        } else {
            try KeychainSecretStore.save(cleaned, service: Self.keychainService, account: Self.keychainAccount)
        }
    }

    private func persistAPIKeyQuietly() {
        try? saveAPIKey()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.standard.set(data, forKey: AIConfiguration.storageKey)
    }

    private static func loadConfiguration() -> AIConfiguration {
        guard let data = UserDefaults.standard.data(forKey: AIConfiguration.storageKey),
              var configuration = try? JSONDecoder().decode(AIConfiguration.self, from: data) else {
            return .default
        }
        if configuration.provider == .deepSeek,
           configuration.baseURL.contains("127.0.0.1") || configuration.baseURL.contains("39.170.58.150") {
            configuration.baseURL = AIProvider.deepSeek.defaultBaseURL
            configuration.model = AIProvider.deepSeek.defaultModel
        }
        return configuration
    }

    private static let keychainService = "com.cuke-think.todos.deepseek"
    private static let keychainAccount = "api-key"
}

enum KeychainSecretStore {
    static func save(_ secret: String, service: String, account: String) throws {
        let data = Data(secret.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainSecretStoreError.unhandled(status: addStatus)
            }
            return
        }
        throw KeychainSecretStoreError.unhandled(status: status)
    }

    static func read(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainSecretStoreError.unhandled(status: status)
        }
        guard let data = item as? Data else {
            throw KeychainSecretStoreError.invalidData
        }
        return String(data: data, encoding: .utf8)
    }

    static func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSecretStoreError.unhandled(status: status)
        }
    }
}

private enum KeychainSecretStoreError: LocalizedError {
    case invalidData
    case unhandled(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "钥匙串中的密钥数据无法读取"
        case .unhandled(let status):
            return "钥匙串操作失败：\(status)"
        }
    }
}

struct AIClient {
    static let shared = AIClient()

    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    func testConnection(configuration: AIConfiguration, apiKey: String) async throws -> String {
        let content = try await complete(
            configuration: configuration,
            apiKey: apiKey,
            systemPrompt: "你是连接测试服务。只回复 OK。",
            userPrompt: "ping",
            temperature: 0,
            maxTokens: 16
        )
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parseQuickInput(
        rawTitle: String,
        rawNotes: String,
        fallback: ParsedTodoInput,
        configuration: AIConfiguration,
        apiKey: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> ParsedTodoInput {
        let referenceText = Self.referenceDateText(for: now)
        let fallbackDate = Self.formatISODate(fallback.date)
        let userPrompt =
            """
            当前时间：\(referenceText)
            原始待办：\(rawTitle)
            原始备注：\(rawNotes)
            本地规则结果：
            {
              "title": "\(Self.escapeForPrompt(fallback.title))",
              "notes": "\(Self.escapeForPrompt(fallback.notes))",
              "priority": "\(fallback.priority.rawValue)",
              "progress": "\(fallback.progress.rawValue)",
              "date": "\(fallbackDate)",
              "isWeekly": \(fallback.isWeekly)
            }

            请只输出 JSON，不要解释。
            """

        let content = try await complete(
            configuration: configuration,
            apiKey: apiKey,
            systemPrompt: quickParseSystemPrompt,
            userPrompt: userPrompt,
            temperature: 0.1,
            maxTokens: 520
        )

        let payload = try decodeJSON(AIParsedTodoPayload.self, from: content)
        return ParsedTodoInput(
            title: fallback.title,
            notes: clean(payload.notes) ?? fallback.notes,
            priority: Self.priority(from: payload.priority) ?? fallback.priority,
            date: Self.date(from: payload.date, fallback: fallback.date, calendar: calendar),
            progress: Self.progress(from: payload.progress) ?? fallback.progress,
            isWeekly: payload.isWeekly ?? fallback.isWeekly
        )
    }

    func dailySuggestion(
        todos: [TodoItem],
        configuration: AIConfiguration,
        apiKey: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> String {
        let activeTodos = todos
            .filter { $0.progress != .done }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.priority.sortRank < rhs.priority.sortRank
            }
            .prefix(36)
        let todoLines = activeTodos.map { todo in
            let dateText = Self.formatISODate(todo.date)
            let notes = todo.trimmedNotes.isEmpty ? "" : "；备注：\(todo.trimmedNotes.prefix(120))"
            return "- [\(todo.priority.rawValue)/\(todo.progress.rawValue)] \(dateText)：\(todo.trimmedTitle)\(notes)"
        }.joined(separator: "\n")

        let content = try await complete(
            configuration: configuration,
            apiKey: apiKey,
            systemPrompt: dailySuggestionSystemPrompt,
            userPrompt:
                """
                当前时间：\(Self.referenceDateText(for: now))
                待办列表：
                \(todoLines.isEmpty ? "暂无未完成待办" : todoLines)
                """,
            temperature: 0.2,
            maxTokens: 360
        )
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func summarizeNotes(
        title: String,
        notes: String,
        configuration: AIConfiguration,
        apiKey: String
    ) async throws -> String {
        let content = try await complete(
            configuration: configuration,
            apiKey: apiKey,
            systemPrompt: notesSummarySystemPrompt,
            userPrompt:
                """
                待办：\(title)
                备注：
                \(notes)
                """,
            temperature: 0.15,
            maxTokens: 180
        )
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func complete(
        configuration: AIConfiguration,
        apiKey: String,
        systemPrompt: String,
        userPrompt: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        guard configuration.canUse else {
            throw AIClientError.disabled
        }
        let cleanedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedAPIKey.isEmpty else {
            throw AIClientError.missingAPIKey
        }

        let url = try chatCompletionsURL(from: configuration.cleanedBaseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(cleanedAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body = ChatCompletionRequest(
            model: configuration.cleanedModel,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userPrompt)
            ],
            temperature: temperature,
            maxTokens: maxTokens
        )
        request.httpBody = try jsonEncoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AIClientError.http(status: httpResponse.statusCode, body: String(bodyText.prefix(320)))
        }

        let decoded = try jsonDecoder.decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AIClientError.emptyResponse
        }
        return content
    }

    private func chatCompletionsURL(from baseURL: String) throws -> URL {
        var value = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") {
            value.removeLast()
        }
        if value.hasSuffix("/chat/completions") {
            guard let url = URL(string: value) else { throw AIClientError.invalidURL }
            return url
        }
        if value.hasSuffix("/v1") || value.hasSuffix("/beta") || value == "https://api.deepseek.com" {
            value += "/chat/completions"
        } else {
            value += "/v1/chat/completions"
        }
        guard let url = URL(string: value) else {
            throw AIClientError.invalidURL
        }
        return url
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from content: String) throws -> T {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let decoded = try? jsonDecoder.decode(T.self, from: data) {
            return decoded
        }

        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start <= end else {
            throw AIClientError.invalidJSON
        }
        let jsonText = String(trimmed[start...end])
        guard let data = jsonText.data(using: .utf8) else {
            throw AIClientError.invalidJSON
        }
        return try jsonDecoder.decode(T.self, from: data)
    }

    private func clean(_ text: String?) -> String? {
        guard let text else { return nil }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func priority(from value: String?) -> TodoPriority? {
        guard let value = value?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if ["high", "高", "高优", "紧急", "重要"].contains(value) { return .high }
        if ["medium", "mid", "normal", "中", "中优", "普通", "一般"].contains(value) { return .medium }
        if ["low", "低", "低优", "不急"].contains(value) { return .low }
        return TodoPriority(rawValue: value)
    }

    private static func progress(from value: String?) -> TodoProgress? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if ["pending", "待处理", "待办"].contains(value) { return .pending }
        if ["inProgress", "in_progress", "推进中", "处理中", "进行中"].contains(value) { return .inProgress }
        if ["waiting", "等待", "等待他人", "等待反馈", "等反馈"].contains(value) { return .waiting }
        if ["done", "已完成", "完成"].contains(value) { return .done }
        return TodoProgress(rawValue: value)
    }

    private static func date(from value: String?, fallback: Date, calendar: Calendar) -> Date {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        if let date = parseISODate(value) {
            return date
        }
        let formatters = ["yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"]
        for format in formatters {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                if format == "yyyy-MM-dd" {
                    return preserveTime(from: fallback, on: date, calendar: calendar)
                }
                return date
            }
        }
        return fallback
    }

    private static func preserveTime(from source: Date, on target: Date, calendar: Calendar) -> Date {
        var targetComponents = calendar.dateComponents([.year, .month, .day], from: target)
        let sourceComponents = calendar.dateComponents([.hour, .minute, .second], from: source)
        targetComponents.hour = sourceComponents.hour
        targetComponents.minute = sourceComponents.minute
        targetComponents.second = sourceComponents.second
        return calendar.date(from: targetComponents) ?? target
    }

    private static func referenceDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm EEEE ZZZZ"
        return formatter.string(from: date)
    }

    private static func escapeForPrompt(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func formatISODate(_ date: Date) -> String {
        isoDateFormatter().string(from: date)
    }

    private static func parseISODate(_ value: String) -> Date? {
        isoDateFormatter().date(from: value)
    }

    private static func isoDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = .current
        return formatter
    }

    private var quickParseSystemPrompt: String {
        """
        你是中文个人待办解析器。根据原始输入识别结构化字段，输出 JSON：
        {"title":"string","notes":"string","priority":"high|medium|low","progress":"pending|inProgress|waiting|done","date":"ISO8601","isWeekly":true|false}
        规则：
        1. title 保持原始待办的完整语义，不要因为识别出时间、优先级、状态、固定周期而切掉标题。
        2. notes 只放补充信息、携带物、背景、判断依据；不要重复整句标题。
        3. 识别“19点半、下午4点、明早、下周三、每周一次、每周固定、等反馈、高优”等中文表达。
        4. 日期必须输出 ISO8601，无法确定时沿用本地规则结果。
        5. 只输出 JSON。
        """
    }

    private var dailySuggestionSystemPrompt: String {
        """
        你是部门经理的个人推进助手。基于待办列表给今日行动建议。
        要求：
        1. 用中文，最多三条，每条不超过 34 个字。
        2. 先指出逾期/今天/等待反馈的关键风险，再给推进顺序。
        3. 不要泛泛鼓励，不要解释方法论。
        """
    }

    private var notesSummarySystemPrompt: String {
        """
        你是待办备注摘要助手。把备注压缩成便于扫读的一句话。
        要求：中文，30-60 字，保留对象、动作、风险、等待项或交付物；不要添加原文没有的信息。
        """
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}

private struct AIParsedTodoPayload: Decodable {
    let title: String?
    let notes: String?
    let priority: String?
    let progress: String?
    let date: String?
    let isWeekly: Bool?
}

private enum AIClientError: LocalizedError {
    case disabled
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case emptyResponse
    case invalidJSON
    case http(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "AI 未启用或配置不完整"
        case .missingAPIKey:
            return "请先填写 DeepSeek API Key"
        case .invalidURL:
            return "代理 URL 无效"
        case .invalidResponse:
            return "代理返回无效响应"
        case .emptyResponse:
            return "模型没有返回内容"
        case .invalidJSON:
            return "模型返回的 JSON 无法解析"
        case .http(let status, let body):
            return body.isEmpty ? "HTTP \(status)" : "HTTP \(status)：\(body)"
        }
    }
}
