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
                    statusMessage = isManual ? "当前已是最新版本 v\(AppVersion.shortVersion)" : nil
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

        var request = URLRequest(url: manifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            throw UpdateError.invalidResponse(statusCode: statusCode)
        }

        return try JSONDecoder().decode(AppUpdateManifest.self, from: data)
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

private enum UpdateError: LocalizedError {
    case missingManifestURL
    case invalidResponse(statusCode: Int?)

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
        }
    }
}
