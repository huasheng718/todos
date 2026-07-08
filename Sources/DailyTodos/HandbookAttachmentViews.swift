import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct HandbookAttachmentStrip: View {
    @Binding var attachments: [HandbookAttachment]
    let isEditing: Bool

    init(attachments: Binding<[HandbookAttachment]>, isEditing: Bool) {
        _attachments = attachments
        self.isEditing = isEditing
    }

    init(attachments: [HandbookAttachment], isEditing: Bool) {
        _attachments = .constant(attachments)
        self.isEditing = isEditing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Label("附件", systemImage: "paperclip")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                if !attachments.isEmpty {
                    Text("\(attachments.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(AppTheme.accentSoft, in: Capsule())
                }

                Spacer()

            }

            if !attachments.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 7)], alignment: .leading, spacing: 7) {
                    ForEach(attachments) { attachment in
                        HandbookAttachmentChip(
                            attachment: attachment,
                            isEditing: isEditing,
                            onOpen: { open(attachment) },
                            onDelete: { remove(attachment) }
                        )
                    }
                }
            }
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.hairline.opacity(0.62))
                .frame(height: 1)
        }
    }

    private func open(_ attachment: HandbookAttachment) {
        guard !attachment.path.isEmpty,
              FileManager.default.fileExists(atPath: attachment.path) else {
            return
        }
        let url = URL(fileURLWithPath: attachment.path)
        NSWorkspace.shared.open(url)
    }

    private func remove(_ attachment: HandbookAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }
}

struct HandbookAttachmentChip: View {
    let attachment: HandbookAttachment
    let isEditing: Bool
    let onOpen: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.kind.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(attachment.kind.color)
                .frame(width: 24, height: 24)
                .background(attachment.kind.softColor, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text(attachment.kind.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer(minLength: 0)

            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .help("移除附件")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(AppTheme.adaptiveWhite(isHovered ? 0.92 : 0.74), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.border.opacity(isHovered ? 0.96 : 0.66))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
    }
}

enum HandbookAttachmentPicker {
    @MainActor
    static func pick() -> [HandbookAttachment] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.item]
        panel.prompt = "添加"

        guard panel.runModal() == .OK else { return [] }

        return panel.urls.map { url in
            HandbookAttachment(
                kind: HandbookAttachmentKind(fileURL: url),
                name: url.lastPathComponent,
                path: url.path
            )
        }
    }
}

extension HandbookAttachmentKind {
    init(fileURL url: URL) {
        let pathExtension = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp"].contains(pathExtension) {
            self = .image
        } else if ["mov", "mp4", "m4v", "avi", "mkv", "webm"].contains(pathExtension) {
            self = .video
        } else {
            self = .file
        }
    }

    var color: Color {
        switch self {
        case .file:
            Color(red: 0.30, green: 0.40, blue: 0.54)
        case .image:
            Color(red: 0.18, green: 0.52, blue: 0.38)
        case .video:
            Color(red: 0.62, green: 0.30, blue: 0.68)
        }
    }

    var softColor: Color {
        switch self {
        case .file:
            Color(red: 0.91, green: 0.94, blue: 0.98)
        case .image:
            Color(red: 0.88, green: 0.96, blue: 0.91)
        case .video:
            Color(red: 0.96, green: 0.90, blue: 0.98)
        }
    }
}
