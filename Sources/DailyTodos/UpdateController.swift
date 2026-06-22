import AppKit
import Foundation

@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var isChecking = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var availableUpdate: AppUpdateManifest?
    @Published private(set) var lastCheckedAt: Date?

    private let lastAutoCheckKey = "dailyTodos.update.lastAutoCheck"
    private let autoCheckInterval: TimeInterval = 24 * 60 * 60
    private let minimumVisibleCheckDuration: TimeInterval = 0.35
    private let manifestClient = UpdateManifestClient()

    func checkForUpdates() {
        runUpdateCheck(isManual: true)
    }

    func checkForUpdatesIfNeeded() {
        guard shouldRunAutoCheck else { return }
        runUpdateCheck(isManual: false)
    }

    private func runUpdateCheck(isManual: Bool) {
        guard !isChecking else { return }

        isChecking = true
        statusMessage = nil
        let startedAt = Date()

        Task {
            do {
                let manifest = try await fetchManifest()
                let currentBuild = Int(AppVersion.build) ?? 0

                if manifest.build > currentBuild {
                    availableUpdate = manifest
                    statusMessage = "发现新版本 \(manifest.version) (\(manifest.build))"
                    presentUpdateAlert(manifest)
                } else {
                    availableUpdate = nil
                    statusMessage = isManual
                        ? "当前已是最新版本 v\(AppVersion.shortVersion) (\(AppVersion.build))，已检查远端 v\(manifest.version) (\(manifest.build))"
                        : nil
                }
            } catch {
                availableUpdate = nil
                    statusMessage = isManual ? readableStatus(for: error) : nil
            }

            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed < minimumVisibleCheckDuration {
                try? await Task.sleep(for: .seconds(minimumVisibleCheckDuration - elapsed))
            }
            lastCheckedAt = Date()
            if !isManual {
                UserDefaults.standard.set(Date(), forKey: lastAutoCheckKey)
            }
            isChecking = false
        }
    }

    private func fetchManifest() async throws -> AppUpdateManifest {
        guard let manifestURL else {
            throw UpdateError.missingManifestURL
        }

        return try await manifestClient.fetchManifest(from: manifestURL)
    }

    private func presentUpdateAlert(_ manifest: AppUpdateManifest) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 \(manifest.version)"
        alert.informativeText = [
            "当前版本：v\(AppVersion.shortVersion) (\(AppVersion.build))",
            "新版本：v\(manifest.version) (\(manifest.build))",
            manifest.releaseNotes
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "下载并打开安装包")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                await downloadAndOpenInstaller(for: manifest)
            }
        }
    }

    private func downloadAndOpenInstaller(for manifest: AppUpdateManifest) async {
        guard let url = URL(string: manifest.downloadURL) else { return }

        do {
            statusMessage = "正在下载 v\(manifest.version)..."
            let (temporaryURL, response) = try await URLSession.shared.download(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                throw UpdateError.invalidResponse(statusCode: statusCode)
            }

            let installerURL = try installerDestinationURL(for: manifest)
            try? FileManager.default.removeItem(at: installerURL)
            try FileManager.default.moveItem(at: temporaryURL, to: installerURL)
            statusMessage = "安装包已下载"
            NSWorkspace.shared.open(installerURL)
        } catch {
            statusMessage = "下载更新失败：\(error.localizedDescription)"
        }
    }

    private func installerDestinationURL(for manifest: AppUpdateManifest) throws -> URL {
        let baseURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("AntOrder-\(manifest.version).pkg")
    }

    private var manifestURL: URL? {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "YXUpdateManifestURL") as? String else {
            return nil
        }
        return URL(string: urlString)
    }

    private var shouldRunAutoCheck: Bool {
        guard !isChecking else { return false }
        guard let lastCheck = UserDefaults.standard.object(forKey: lastAutoCheckKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastCheck) >= autoCheckInterval
    }

    private func readableStatus(for error: Error) -> String {
        if let updateError = error as? UpdateError {
            return updateError.errorDescription ?? "检查更新失败"
        }
        if error is DecodingError {
            return "更新信息格式不正确，暂时无法检查。"
        }
        return "检查更新失败：\(error.localizedDescription)"
    }
}

struct AppUpdateManifest: Decodable, Equatable {
    let version: String
    let build: Int
    let downloadURL: String
    let releaseNotes: String?
}

struct UpdateManifestClient {
    func fetchManifest(from manifestURL: URL) async throws -> AppUpdateManifest {
        var firstError: Error?

        if Self.isGitHubContentsURL(manifestURL) {
            do {
                return try await fetchGitHubContentsManifest(from: manifestURL)
            } catch {
                firstError = error
            }
        } else if let contentsURL = Self.githubContentsURL(for: manifestURL) {
            do {
                return try await fetchGitHubContentsManifest(from: contentsURL)
            } catch {
                firstError = error
            }
        }

        do {
            return try await fetchRawManifest(from: manifestURL)
        } catch {
            throw firstError ?? error
        }
    }

    private func fetchGitHubContentsManifest(from url: URL) async throws -> AppUpdateManifest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let data = try await responseData(for: request)
        return try Self.decodeGitHubContentsManifest(from: data)
    }

    private func fetchRawManifest(from url: URL) async throws -> AppUpdateManifest {
        var request = URLRequest(url: Self.cacheBustedURL(url))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        let data = try await responseData(for: request)
        return try JSONDecoder().decode(AppUpdateManifest.self, from: data)
    }

    private func responseData(for request: URLRequest) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 18
        configuration.urlCache = nil

        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            throw UpdateError.invalidResponse(statusCode: statusCode)
        }
        return data
    }

    static func githubContentsURL(for rawURL: URL) -> URL? {
        guard rawURL.host == "raw.githubusercontent.com" else {
            return nil
        }

        let parts = rawURL.path.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 4 else {
            return nil
        }

        let owner = String(parts[0])
        let repo = String(parts[1])
        let ref = String(parts[2])
        let filePath = parts.dropFirst(3).joined(separator: "/")

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = "/repos/\(owner)/\(repo)/contents/\(filePath)"
        components.queryItems = [
            URLQueryItem(name: "ref", value: ref)
        ]
        return components.url
    }

    static func isGitHubContentsURL(_ url: URL) -> Bool {
        guard url.host == "api.github.com" else {
            return false
        }
        return url.path.contains("/contents/")
    }

    static func cacheBustedURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "_yxcb", value: String(Int(Date().timeIntervalSince1970 * 1000))))
        components.queryItems = queryItems
        return components.url ?? url
    }

    static func decodeGitHubContentsManifest(from data: Data) throws -> AppUpdateManifest {
        let contents = try JSONDecoder().decode(GitHubContentsResponse.self, from: data)
        guard contents.encoding.lowercased() == "base64" else {
            throw UpdateError.unsupportedEncoding(contents.encoding)
        }

        let normalizedContent = contents.content.filter { !$0.isWhitespace }
        guard let manifestData = Data(base64Encoded: normalizedContent) else {
            throw UpdateError.invalidManifestPayload
        }

        return try JSONDecoder().decode(AppUpdateManifest.self, from: manifestData)
    }
}

private struct GitHubContentsResponse: Decodable {
    let content: String
    let encoding: String
}

enum UpdateError: LocalizedError {
    case missingManifestURL
    case invalidResponse(statusCode: Int?)
    case invalidManifestPayload
    case unsupportedEncoding(String)

    var errorDescription: String? {
        switch self {
        case .missingManifestURL:
            return "缺少更新地址配置"
        case .invalidResponse(let statusCode):
            if statusCode == 404 {
                return "更新源不可访问；私有仓库需改为公开发布源。"
            }
            if let statusCode {
                return "更新服务暂不可用（HTTP \(statusCode)）。"
            }
            return "更新服务暂不可用。"
        case .invalidManifestPayload:
            return "更新信息内容不完整，暂时无法检查。"
        case .unsupportedEncoding:
            return "更新信息格式不受支持，暂时无法检查。"
        }
    }
}
