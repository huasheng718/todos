import SwiftUI

/// 手记目录树节点
struct HandbookTreeNode: Identifiable {
    enum Kind {
        case allItems
        case category(HandbookCategory)
        case folder(String)
        case item(HandbookItem)
    }

    let id: String
    let kind: Kind
    let title: String
    let icon: String
    let count: Int
    var children: [HandbookTreeNode]?

    var isLeaf: Bool { children == nil }
}

/// 手记目录树视图
/// 替代 HandbookSidebarView + HandbookContentView 的列表部分
/// 使用 List + OutlineGroup 实现树形导航
struct HandbookTreeView: View {
    let items: [HandbookItem]
    @Binding var selectedCategory: HandbookCategory?
    @Binding var selectedFolder: String?
    @Binding var selectedItemID: UUID?
    let searchText: String
    let isLoaded: Bool
    @Binding var isSecondarySidebarCollapsed: Bool
    let onSelect: (HandbookItem) -> Void
    let onCreate: (HandbookCategory, String, String, String, [HandbookAttachment]) -> Void

    @State private var expandedNodeIDs: Set<String> = ["all", "cat-businessRule", "cat-research", "cat-meeting", "cat-inspiration"]
    @State private var draftTitle = ""
    @State private var draftBody = ""
    @FocusState private var focusField: HandbookFocusField?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader

            Divider()
                .overlay(AppTheme.hairline)

            // 快记输入栏
            handbookQuickCapture

            Divider()
                .overlay(AppTheme.hairline.opacity(0.56))

            // 目录树
            if isLoaded {
                treeContent
            } else {
                // 加载中显示骨架
                handbookListSkeleton
            }
        }
        .background(AppTheme.sidebar)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("手记")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                Text("想法、机会、资料沉淀")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            SecondarySidebarCollapseButton(isCollapsed: $isSecondarySidebarCollapsed)
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .frame(height: 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 快记输入栏
    private var handbookQuickCapture: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("手记标题", text: $draftTitle, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1...2)
                    .focused($focusField, equals: .title)

                Spacer(minLength: 0)

                Button {
                    submit()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(canSubmit ? AppTheme.accent : AppTheme.mutedInk.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }

            TextField("从这里开始写手记，支持 Markdown...", text: $draftBody, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1...4)
                .focused($focusField, equals: .body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // 树内容
    private var treeContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                // 全部手记
                treeAllItemsNode

                // 按分类展开
                ForEach(HandbookCategory.allCases) { category in
                    treeCategoryNode(category)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    // "全部手记"节点
    private var treeAllItemsNode: some View {
        HandbookTreeRow(
            title: "全部手记",
            icon: "tray.full",
            count: items.count,
            isSelected: selectedCategory == nil && selectedFolder == nil,
            isExpanded: expandedNodeIDs.contains("all"),
            onToggle: { toggleExpand("all") },
            onSelect: {
                selectedCategory = nil
                selectedFolder = nil
            }
        )
    }

    // 分类节点
    private func treeCategoryNode(_ category: HandbookCategory) -> some View {
        let categoryItems = items.filter { $0.category == category }
        let nodeID = "cat-\(category.rawValue)"
        let isExpanded = expandedNodeIDs.contains(nodeID)
        let isSelected = selectedCategory == category && selectedFolder == nil

        return VStack(alignment: .leading, spacing: 0) {
            HandbookTreeRow(
                title: category.title,
                icon: category.icon,
                count: categoryItems.count,
                accentColor: category.accentColor,
                isSelected: isSelected,
                isExpanded: isExpanded,
                onToggle: { toggleExpand(nodeID) },
                onSelect: {
                    selectedCategory = category
                    selectedFolder = nil
                }
            )

            if isExpanded {
                // 文件夹子节点
                let folders = uniqueFolders(in: categoryItems)
                ForEach(folders, id: \.self) { folder in
                    treeFolderNode(folder, category: category, items: categoryItems)
                }

                // 未归档的手记（没有文件夹的）
                let unfiledItems = categoryItems.filter { $0.trimmedFolder.isEmpty }
                if !unfiledItems.isEmpty {
                    treeUnfiledNode(items: unfiledItems, category: category)
                }
            }
        }
        .padding(.leading, 8)
    }

    // 文件夹节点
    private func treeFolderNode(_ folder: String, category: HandbookCategory, items: [HandbookItem]) -> some View {
        let folderItems = items.filter { $0.trimmedFolder == folder }
        let nodeID = "folder-\(category.rawValue)-\(folder)"
        let isExpanded = expandedNodeIDs.contains(nodeID)
        let isSelected = selectedCategory == category && selectedFolder == folder

        return VStack(alignment: .leading, spacing: 0) {
            HandbookTreeRow(
                title: folder,
                icon: "folder",
                count: folderItems.count,
                isSelected: isSelected,
                isExpanded: isExpanded,
                onToggle: { toggleExpand(nodeID) },
                onSelect: {
                    selectedCategory = category
                    selectedFolder = folder
                }
            )

            if isExpanded {
                ForEach(folderItems) { item in
                    treeItemNode(item, indent: 28)
                }
            }
        }
        .padding(.leading, 8)
    }

    // 未归档节点
    private func treeUnfiledNode(items: [HandbookItem], category: HandbookCategory) -> some View {
        let nodeID = "unfiled-\(category.rawValue)"
        let isExpanded = expandedNodeIDs.contains(nodeID)

        return VStack(alignment: .leading, spacing: 0) {
            HandbookTreeRow(
                title: "未归档",
                icon: "folder.badge.plus",
                count: items.count,
                isSelected: false,
                isExpanded: isExpanded,
                onToggle: { toggleExpand(nodeID) },
                onSelect: {}
            )

            if isExpanded {
                ForEach(items) { item in
                    treeItemNode(item, indent: 28)
                }
            }
        }
        .padding(.leading, 8)
    }

    // 手记条目节点（叶子节点）
    private func treeItemNode(_ item: HandbookItem, indent: CGFloat) -> some View {
        let isSelected = selectedItemID == item.id

        return HandbookTreeItemRow(
            item: item,
            isSelected: isSelected,
            indent: indent
        ) {
            selectedItemID = item.id
            onSelect(item)
        }
    }

    // 骨架占位
    private var handbookListSkeleton: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.hairline.opacity(0.3))
                    .frame(height: 32)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // 工具方法
    private var canSubmit: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = draftBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !body.isEmpty else {
            focusField = .title
            return
        }
        let category = selectedCategory ?? HandbookCategory.infer(from: "\(title)\n\(body)")
        let folder = (selectedFolder ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        onCreate(category, folder, title, body, [])
        draftTitle = ""
        draftBody = ""
        focusField = .title
    }

    private func toggleExpand(_ id: String) {
        withAnimation(AppMotion.quick) {
            if expandedNodeIDs.contains(id) {
                expandedNodeIDs.remove(id)
            } else {
                expandedNodeIDs.insert(id)
            }
        }
    }

    private func uniqueFolders(in items: [HandbookItem]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in items {
            let folder = item.trimmedFolder
            if !folder.isEmpty && !seen.contains(folder) {
                seen.insert(folder)
                result.append(folder)
            }
        }
        return result.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}

/// 树行（分类/文件夹级别）
struct HandbookTreeRow: View {
    let title: String
    let icon: String
    let count: Int
    var accentColor: Color = AppTheme.mutedInk
    let isSelected: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // 展开/折叠箭头
            Button(action: onToggle) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.mutedInk.opacity(0.6))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 14)
            }
            .buttonStyle(.plain)

            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isSelected ? .white : accentColor)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? .white : AppTheme.ink)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(isSelected ? .white.opacity(0.8) : AppTheme.mutedInk)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return accentColor.opacity(0.88)
        }
        return isHovered ? AppTheme.adaptiveWhite(0.4) : .clear
    }
}

/// 树叶子行（手记条目）
struct HandbookTreeItemRow: View {
    let item: HandbookItem
    let isSelected: Bool
    let indent: CGFloat
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // 分类色条
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(item.category.accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.ink)
                    .lineLimit(1)

                if !item.attachments.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 9))
                        Text("\(item.attachments.count)")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(AppTheme.mutedInk)
                }
            }

            Spacer(minLength: 0)

            Text(item.updatedAt.formatted(.dateTime.month().day()))
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? item.category.accentColor.opacity(0.12) : (isHovered ? AppTheme.adaptiveWhite(0.3) : .clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isSelected ? item.category.accentColor.opacity(0.3) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
    }
}
