import SwiftUI

struct MarkdownOutlineEntry: Identifiable, Equatable {
    let id = UUID()
    let level: Int
    let title: String

    static func extract(from text: String) -> [MarkdownOutlineEntry] {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> MarkdownOutlineEntry? in
                let rawLine = String(line).trimmingCharacters(in: .whitespaces)
                guard rawLine.hasPrefix("#") else { return nil }
                let level = rawLine.prefix(while: { $0 == "#" }).count
                guard (1...3).contains(level) else { return nil }
                let title = rawLine
                    .dropFirst(level)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                return MarkdownOutlineEntry(level: level, title: title)
            }
    }
}

struct HandbookOutlineStrip: View {
    let entries: [MarkdownOutlineEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("结构", systemImage: "list.bullet.indent")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.ink)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(entries.prefix(8)) { entry in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(AppTheme.accent.opacity(entry.level == 1 ? 0.88 : 0.48))
                            .frame(width: entry.level == 1 ? 6 : 4, height: entry.level == 1 ? 6 : 4)

                        Text(entry.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.mutedInk)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(AppTheme.adaptiveWhite(0.62), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.hairline.opacity(0.52))
                    )
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
}
