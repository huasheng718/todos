import Foundation

struct AppUpdateDownloadProgress: Equatable, Sendable {
    let receivedBytes: Int64
    let expectedBytes: Int64?

    var fractionCompleted: Double? {
        guard let expectedBytes, expectedBytes > 0 else {
            return nil
        }
        return min(max(Double(receivedBytes) / Double(expectedBytes), 0), 1)
    }

    var percentText: String? {
        guard let fractionCompleted else {
            return nil
        }
        return "\(Int((fractionCompleted * 100).rounded(.down)))%"
    }

    var detailText: String {
        if let expectedBytes, expectedBytes > 0 {
            return "\(Self.formatByteCount(receivedBytes)) / \(Self.formatByteCount(expectedBytes))"
        }
        return "\(Self.formatByteCount(receivedBytes)) 已下载"
    }

    var statusText: String {
        if let percentText {
            return "\(percentText) · \(detailText)"
        }
        return detailText
    }

    private static func formatByteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
