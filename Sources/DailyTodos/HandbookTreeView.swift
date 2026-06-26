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
    let onCreate: (HandbookCategory, String, String, String, [HandbookAttachment]) -> HandbookItem?
    let onMove: (HandbookItem, HandbookCategory, String) -> Void
    let onDelete: (HandbookItem) -> Void

    @State private var expandedNodeIDs: Set<String> = []
    @State private var snapshot = HandbookTreeSnapshot.empty
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
        .onAppear {
            rebuildSnapshot(expandInitialNodes: true)
        }
        .onChange(of: items) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: searchText) { _, _ in
            rebuildSnapshot()
        }
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
            LazyVStack(alignment: .leading, spacing: 4) {
                // 全部手记
                treeAllItemsNode

                // 按分类展开
                ForEach(snapshot.sections) { section in
                    treeCategoryNode(section)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    // "全部手记"节点
    private var treeAllItemsNode: some View {
        HandbookTreeRow(
            title: "全部手记",
            icon: "tray.full",
            count: snapshot.totalCount,
            level: 0,
            variant: .summary,
            accentColor: AppTheme.accent,
            isSelected: selectedItemID == nil && selectedCategory == nil && selectedFolder == nil,
            isExpandable: false,
            isExpanded: expandedNodeIDs.contains(HandbookTreeNodeID.all),
            onToggle: { toggleExpand(HandbookTreeNodeID.all) },
            onSelect: {
                selectedItemID = nil
                selectedCategory = nil
                selectedFolder = nil
            },
            onDrop: { _ in false }
        )
    }

    // 分类节点
    private func treeCategoryNode(_ section: HandbookTreeSection) -> some View {
        let category = section.category
        let nodeID = section.nodeID
        let isExpanded = expandedNodeIDs.contains(nodeID)
        let isSelected = selectedItemID == nil && selectedCategory == category && selectedFolder == nil

        return VStack(alignment: .leading, spacing: 0) {
            HandbookTreeRow(
                title: category.title,
                icon: category.icon,
                count: section.items.count,
                level: 0,
                variant: .category,
                accentColor: category.accentColor,
                isSelected: isSelected,
                isExpandable: !section.items.isEmpty,
                isExpanded: isExpanded,
                onToggle: { toggleExpand(nodeID) },
                onSelect: {
                    selectedItemID = nil
                    selectedCategory = category
                    selectedFolder = nil
                },
                onDrop: { itemIDs in
                    moveDraggedItems(itemIDs, to: category, folder: nil)
                }
            )

            if isExpanded {
                // 文件夹子节点
                ForEach(section.folders) { folder in
                    treeFolderNode(folder, category: category)
                }

                // 未归档的手记（没有文件夹的）
                if !section.unfiledItems.isEmpty {
                    treeUnfiledNode(items: section.unfiledItems, category: category)
                }
            }
        }
    }

    // 文件夹节点
    private func treeFolderNode(_ folder: HandbookTreeFolder, category: HandbookCategory) -> some View {
        let nodeID = folder.id
        let isExpanded = expandedNodeIDs.contains(nodeID)
        let isSelected = selectedItemID == nil && selectedCategory == category && selectedFolder == folder.name

        return VStack(alignment: .leading, spacing: 0) {
            HandbookTreeRow(
                title: folder.name,
                icon: "folder",
                count: folder.items.count,
                level: 1,
                variant: .folder,
                accentColor: category.accentColor,
                isSelected: isSelected,
                isExpandable: !folder.items.isEmpty,
                isExpanded: isExpanded,
                onToggle: { toggleExpand(nodeID) },
                onSelect: {
                    selectedItemID = nil
                    selectedCategory = category
                    selectedFolder = folder.name
                },
                onDrop: { _ in false }
            )

            if isExpanded {
                ForEach(folder.items) { item in
                    treeItemNode(item, level: 2)
                }
            }
        }
    }

    // 未归档节点
    private func treeUnfiledNode(items: [HandbookItem], category: HandbookCategory) -> some View {
        let nodeID = HandbookTreeNodeID.unfiled(category)
        let isExpanded = expandedNodeIDs.contains(nodeID)
        let isSelected = selectedItemID == nil && selectedCategory == category && selectedFolder == ""

        return VStack(alignment: .leading, spacing: 0) {
            HandbookTreeRow(
                title: "未归档",
                icon: "folder.badge.plus",
                count: items.count,
                level: 1,
                variant: .folder,
                accentColor: category.accentColor,
                isSelected: isSelected,
                isExpandable: !items.isEmpty,
                isExpanded: isExpanded,
                onToggle: { toggleExpand(nodeID) },
                onSelect: {
                    selectedItemID = nil
                    selectedCategory = category
                    selectedFolder = ""
                },
                onDrop: { _ in false }
            )

            if isExpanded {
                ForEach(items) { item in
                    treeItemNode(item, level: 2)
                }
            }
        }
    }

    // 手记条目节点（叶子节点）
    private func treeItemNode(_ item: HandbookItem, level: Int) -> some View {
        let isSelected = selectedItemID == item.id

        return HandbookTreeItemRow(
            item: item,
            isSelected: isSelected,
            level: level,
            onMove: { category, folder in
                move(item, to: category, folder: folder)
            },
            onDelete: {
                if selectedItemID == item.id {
                    selectedItemID = nil
                }
                onDelete(item)
            }
        ) {
            selectedItemID = item.id
            selectedCategory = item.category
            selectedFolder = item.trimmedFolder.isEmpty ? "" : item.trimmedFolder
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
        guard let createdItem = onCreate(category, folder, title, body, []) else { return }
        selectedItemID = createdItem.id
        selectedCategory = createdItem.category
        selectedFolder = createdItem.trimmedFolder.isEmpty ? "" : createdItem.trimmedFolder
        expandPath(to: createdItem)
        onSelect(createdItem)
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

    private func rebuildSnapshot(expandInitialNodes: Bool = false) {
        let newSnapshot = PerformanceMonitor.measure("HandbookTreeSnapshot.build") {
            HandbookTreeSnapshot(items: items, searchText: searchText)
        }
        guard newSnapshot.cacheKey != snapshot.cacheKey else {
            if expandInitialNodes {
                expandedNodeIDs.formUnion(newSnapshot.structureNodeIDs)
            }
            return
        }

        let previousNodeIDs = snapshot.structureNodeIDs
        let previousSignature = snapshot.structureSignature
        snapshot = newSnapshot

        if expandInitialNodes || previousSignature.isEmpty {
            expandedNodeIDs.formUnion(newSnapshot.structureNodeIDs)
        } else if previousSignature != newSnapshot.structureSignature {
            expandedNodeIDs.formUnion(newSnapshot.structureNodeIDs.subtracting(previousNodeIDs))
        }
    }

    private func expandPath(to item: HandbookItem) {
        expandedNodeIDs.insert(HandbookTreeNodeID.all)
        expandedNodeIDs.insert(HandbookTreeNodeID.category(item.category))
        if item.trimmedFolder.isEmpty {
            expandedNodeIDs.insert(HandbookTreeNodeID.unfiled(item.category))
        } else {
            expandedNodeIDs.insert(folderNodeID(category: item.category, folder: item.trimmedFolder))
        }
    }

    private func folderNodeID(category: HandbookCategory, folder: String) -> String {
        HandbookTreeNodeID.folder(category: category, folder: folder)
    }

    private func move(_ item: HandbookItem, to category: HandbookCategory, folder: String?) {
        let targetFolder = folder ?? item.trimmedFolder
        guard item.category != category || item.trimmedFolder != targetFolder else { return }
        withAnimation(AppMotion.smooth) {
            onMove(item, category, targetFolder)
            selectedItemID = item.id
            selectedCategory = category
            selectedFolder = targetFolder.isEmpty ? "" : targetFolder
            expandedNodeIDs.insert(HandbookTreeNodeID.category(category))
            if targetFolder.isEmpty {
                expandedNodeIDs.insert(HandbookTreeNodeID.unfiled(category))
            } else {
                expandedNodeIDs.insert(folderNodeID(category: category, folder: targetFolder))
            }
        }
    }

    private func moveDraggedItems(_ itemIDs: [String], to category: HandbookCategory, folder: String?) -> Bool {
        var didAccept = false
        for idString in itemIDs {
            guard let itemID = UUID(uuidString: idString),
                  let item = items.first(where: { $0.id == itemID }) else { continue }
            move(item, to: category, folder: folder)
            didAccept = true
        }
        return didAccept
    }
}

enum HandbookTreeRowVariant {
    case summary
    case category
    case folder
}

/// 树行（总入口/分类/文件夹级别）
struct HandbookTreeRow: View {
    let title: String
    let icon: String
    let count: Int
    var level: Int = 0
    var variant: HandbookTreeRowVariant = .folder
    var accentColor: Color = AppTheme.accent
    let isSelected: Bool
    var isExpandable = true
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    let onDrop: ([String]) -> Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: rowSpacing) {
            disclosureControl

            iconView

            Text(title)
                .font(titleFont)
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)

            Spacer(minLength: 0)

            countLabel
        }
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: rowRadius, style: .continuous))
        .overlay(rowBorder)
        .overlay(alignment: .leading) { selectedMarker }
        .contentShape(RoundedRectangle(cornerRadius: rowRadius, style: .continuous))
        .onTapGesture(perform: onSelect)
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
        .dropDestination(for: String.self) { items, _ in
            onDrop(items)
        }
    }

    @ViewBuilder
    private var disclosureControl: some View {
        if isExpandable {
            Button(action: onToggle) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(chevronColor)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: disclosureWidth, height: rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "折叠" : "展开")
        } else if variant != .summary {
            Color.clear
                .frame(width: disclosureWidth, height: rowHeight)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if variant == .summary {
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 18)
        }
    }

    private var countLabel: some View {
        Text("\(count)")
            .font(.system(size: countSize, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(countColor)
            .frame(minWidth: variant == .category ? 18 : 24, alignment: .trailing)
    }

    @ViewBuilder
    private var selectedMarker: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 3, height: markerHeight)
                .padding(.leading, markerLeadingPadding)
        }
    }

    private var rowBackground: Color {
        if isSelected {
            switch variant {
            case .summary:
                return AppTheme.sidebarSelected
            case .category:
                return accentColor.opacity(AppTheme.isDark ? 0.16 : 0.10)
            case .folder:
                return AppTheme.adaptiveWhite(AppTheme.isDark ? 0.12 : 0.46)
            }
        }
        if isHovered {
            return AppTheme.adaptiveWhite(AppTheme.isDark ? 0.10 : 0.36)
        }
        return variant == .summary ? AppTheme.adaptiveWhite(AppTheme.isDark ? 0.08 : 0.24) : .clear
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: rowRadius, style: .continuous)
            .stroke(borderColor, lineWidth: 1)
    }

    private var leadingPadding: CGFloat {
        switch variant {
        case .summary:
            return 8
        case .category:
            return 2
        case .folder:
            return 18 + CGFloat(level - 1) * 18
        }
    }

    private var trailingPadding: CGFloat {
        variant == .summary ? 10 : 8
    }

    private var rowHeight: CGFloat {
        switch variant {
        case .summary: return 38
        case .category: return 30
        case .folder: return 32
        }
    }

    private var rowRadius: CGFloat {
        variant == .summary ? 8 : 6
    }

    private var rowSpacing: CGFloat {
        variant == .summary ? 8 : 6
    }

    private var disclosureWidth: CGFloat {
        variant == .category ? 16 : 15
    }

    private var iconSize: CGFloat {
        variant == .category ? 11.5 : 12
    }

    private var countSize: CGFloat {
        variant == .category ? 10.5 : 11
    }

    private var titleFont: Font {
        switch variant {
        case .summary:
            return .system(size: 13.5, weight: .bold)
        case .category:
            return .system(size: 12.5, weight: .bold)
        case .folder:
            return .system(size: 12.5, weight: isSelected ? .bold : .semibold)
        }
    }

    private var chevronColor: Color {
        isHovered || isSelected ? AppTheme.mutedInk.opacity(0.86) : AppTheme.mutedInk.opacity(0.48)
    }

    private var iconColor: Color {
        if variant == .summary || variant == .category || isSelected {
            return accentColor
        }
        return AppTheme.mutedInk.opacity(isHovered ? 0.90 : 0.72)
    }

    private var titleColor: Color {
        if isSelected {
            return AppTheme.ink
        }
        switch variant {
        case .summary:
            return AppTheme.ink
        case .category:
            return AppTheme.ink.opacity(0.86)
        case .folder:
            return AppTheme.ink.opacity(0.82)
        }
    }

    private var countColor: Color {
        if isSelected {
            return AppTheme.ink.opacity(0.78)
        }
        return AppTheme.mutedInk.opacity(count == 0 ? 0.58 : 0.88)
    }

    private var borderColor: Color {
        if isSelected {
            return variant == .summary
                ? AppTheme.border.opacity(0.62)
                : accentColor.opacity(AppTheme.isDark ? 0.30 : 0.20)
        }
        return variant == .summary ? AppTheme.hairline.opacity(0.60) : .clear
    }

    private var markerHeight: CGFloat {
        variant == .category ? 16 : 20
    }

    private var markerLeadingPadding: CGFloat {
        variant == .summary ? 5 : max(3, leadingPadding - 4)
    }
}

/// 树叶子行（手记条目）
struct HandbookTreeItemRow: View {
    let item: HandbookItem
    let isSelected: Bool
    let level: Int
    let onMove: (HandbookCategory, String?) -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 7) {
                Circle()
                    .fill(item.category.accentColor)
                    .frame(width: isSelected ? 7 : 6, height: isSelected ? 7 : 6)
                    .draggable(item.id.uuidString)
                    .help("拖拽移动手记")

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? AppTheme.ink : AppTheme.ink.opacity(0.92))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    if !item.attachments.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 9))
                            Text("\(item.attachments.count)")
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(AppTheme.mutedInk.opacity(0.86))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                if !item.attachments.isEmpty {
                    Image(systemName: "paperclip")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(AppTheme.mutedInk.opacity(0.70))
                }

                Text(item.updatedAt.formatted(.dateTime.month().day()))
                    .font(.system(size: 10.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.mutedInk.opacity(isSelected ? 0.88 : 0.74))
                    .frame(width: 54, alignment: .trailing)
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isSelected ? item.category.accentColor.opacity(AppTheme.isDark ? 0.34 : 0.22) : .clear, lineWidth: 1)
        )
        .contextMenu {
            moveMenu
            Divider()
            HandbookTreeItemPreview(item: item)
        }
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
    }

    private var leadingPadding: CGFloat {
        34 + CGFloat(level - 2) * 18
    }

    private var rowBackground: Color {
        if isSelected {
            return item.category.accentColor.opacity(AppTheme.isDark ? 0.18 : 0.10)
        }
        return isHovered ? AppTheme.adaptiveWhite(AppTheme.isDark ? 0.08 : 0.30) : .clear
    }

    @ViewBuilder
    private var moveMenu: some View {
        Menu("移动到") {
            ForEach(HandbookCategory.allCases) { category in
                Button {
                    onMove(category, nil)
                } label: {
                    Label(category.title, systemImage: category.icon)
                }
            }
        }
        Divider()
        Button(role: .destructive, action: onDelete) {
            Label("删除手记", systemImage: "trash")
        }
    }
}

struct HandbookTreeItemPreview: View {
    let item: HandbookItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.displayTitle)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("最后修改于 \(item.updatedAt.formatted(.dateTime.year().month().day().hour().minute()))")
                Text("创建于 \(item.createdAt.formatted(.dateTime.year().month().day().hour().minute()))")
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white.opacity(0.92))
            .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 260, alignment: .leading)
        .background(AppTheme.adaptiveBlack(0.90), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
