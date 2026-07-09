import AppKit
import UniformTypeIdentifiers

enum HandbookPasteboardImageReader {
    static func image(from pasteboard: NSPasteboard) -> NSImage? {
        if let image = NSImage(pasteboard: pasteboard) {
            return image
        }

        for identifier in imageTypeIdentifiers {
            let type = NSPasteboard.PasteboardType(identifier)
            if let data = pasteboard.data(forType: type),
               let image = NSImage(data: data) {
                return image
            }
        }

        return nil
    }

    private static let imageTypeIdentifiers = [
        UTType.png.identifier,
        UTType.jpeg.identifier,
        UTType.tiff.identifier
    ]
}
