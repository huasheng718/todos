import AppKit
import Foundation

struct HandbookAttachmentStorage {
    let rootDirectory: URL

    init(rootDirectory: URL = Self.defaultRoot()) {
        self.rootDirectory = rootDirectory
    }

    static func defaultRoot() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return baseURL
            .appendingPathComponent("DailyTodos", isDirectory: true)
            .appendingPathComponent("HandbookAttachments", isDirectory: true)
    }

    @MainActor
    func savePastedImage(
        _ image: NSImage,
        noteID: UUID,
        now: Date = Date()
    ) throws -> HandbookAttachment {
        guard let data = Self.pngData(from: image) else {
            throw HandbookAttachmentStorageError.unreadableImage
        }

        let noteDirectory = rootDirectory.appendingPathComponent(noteID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: noteDirectory, withIntermediateDirectories: true)

        let timestamp = Int(now.timeIntervalSince1970)
        let suffix = UUID().uuidString.prefix(8).lowercased()
        let filename = "pasted-\(timestamp)-\(suffix).png"
        let url = noteDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)

        return HandbookAttachment(kind: .image, name: filename, path: url.path)
    }

    static func markdownImageLine(for attachment: HandbookAttachment) -> String {
        let url = URL(fileURLWithPath: attachment.path).absoluteString
        return "![\(attachment.name)](\(url))"
    }

    static func appendingMarkdownImage(to body: String, attachment: HandbookAttachment) -> String {
        let line = markdownImageLine(for: attachment)
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return line }
        return "\(body.trimmingCharacters(in: .newlines))\n\n\(line)"
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}

enum HandbookAttachmentStorageError: LocalizedError {
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "无法读取剪贴板图片"
        }
    }
}
