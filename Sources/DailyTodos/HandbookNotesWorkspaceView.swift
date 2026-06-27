import SwiftUI

struct HandbookFolderSidebarView: View {
    let items: [HandbookItem]
    @Binding var selectedCategory: HandbookCategory?
    @Binding var selectedFolder: String?
    @Binding var isSecondarySidebarCollapsed: Bool
    let isLoaded: Bool
    let onMove: (HandbookItem, HandbookCategory, String) -> Void

    @State private var metrics = HandbookSidebarMetrics.empty
    @State private var metricsTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader

            Divider()
                .overlay(AppTheme.hairline.opacity(0.72))

            if isLoaded {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        sourceSection
                        categorySection
                        folderTagSection
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 18)
                }
                .scrollIndicators(.hidden)
            } else {
                notesSidebarSkeleton
            }

            Spacer(minLength: 0)
        }
        .background(notesSidebarBackground)
        .onAppear {
            rebuildMetrics(immediate: true)
        }
        .onChange(of: items) { _, _ in
            rebuildMetrics()
        }
        .onChange(of: selectedCategory) { _, _ in
            rebuildMetrics()
        }
        .onDisappear {
            metricsTask?.cancel()
        }
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("手记")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                Text("Mac")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            SecondarySidebarCollapseButton(isCollapsed: $isSecondarySidebarCollapsed)
        }
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .frame(height: 52)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HandbookNotesSectionLabel("Mac")

            HandbookFolderSidebarRow(
                title: "全部手记",
                icon: "folder",
                count: metrics.totalCount,
                accentColor: AppTheme.accent,
                isSelected: selectedCategory == nil && selectedFolder == nil,
                onSelect: {
                    selectedCategory = nil
                    selectedFolder = nil
                },
                onDrop: { itemIDs in
                    moveDraggedItems(itemIDs, category: nil, folder: nil)
                }
            )
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(HandbookCategory.allCases) { category in
                HandbookFolderSidebarRow(
                    title: category.title,
                    icon: "folder",
                    count: metrics.categoryCounts[category, default: 0],
                    accentColor: category.accentColor,
                    isSelected: selectedCategory == category && selectedFolder == nil,
                    onSelect: {
                        selectedCategory = category
                        selectedFolder = nil
                    },
                    onDrop: { itemIDs in
                        moveDraggedItems(itemIDs, category: category, folder: nil)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var folderTagSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HandbookNotesSectionLabel("标签")

            if metrics.folders.isEmpty {
                Text("暂无二级目录")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            } else {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(metrics.folders, id: \.self) { folder in
                        HandbookFolderTagButton(
                            title: folder,
                            count: metrics.folderCounts[folder, default: 0],
                            isSelected: selectedFolder == folder,
                            onSelect: {
                                selectedFolder = folder
                            },
                            onDrop: { itemIDs in
                                moveDraggedItems(itemIDs, category: selectedCategory, folder: folder)
                            }
                        )
                    }
                }
            }
        }
    }

    private var notesSidebarSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<8, id: \.self) { index in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppTheme.adaptiveWhite(index == 0 ? 0.66 : 0.42))
                    .frame(height: 28)
            }
        }
        .padding(14)
    }

    private var notesSidebarBackground: Color {
        AppTheme.sidebar
    }

    private func rebuildMetrics(immediate: Bool = false) {
        metricsTask?.cancel()
        let sourceItems = items
        let category = selectedCategory

        if immediate || metrics == .empty {
            metrics = PerformanceMonitor.measure("HandbookFolderSidebar.metrics.sync") {
                HandbookSidebarMetrics(items: sourceItems, selectedCategory: category)
            }
            return
        }

        metricsTask = Task {
            try? await Task.sleep(for: .milliseconds(24))
            guard !Task.isCancelled else { return }
            let newMetrics = await Task.detached(priority: .userInitiated) {
                PerformanceMonitor.measure("HandbookFolderSidebar.metrics") {
                    HandbookSidebarMetrics(items: sourceItems, selectedCategory: category)
                }
            }.value
            guard !Task.isCancelled else { return }
            metrics = newMetrics
        }
    }

    private func moveDraggedItems(_ itemIDs: [String], category: HandbookCategory?, folder: String?) -> Bool {
        var didAccept = false
        for idString in itemIDs {
            guard let itemID = UUID(uuidString: idString),
                  let item = items.first(where: { $0.id == itemID }) else { continue }
            onMove(item, category ?? item.category, folder ?? "")
            didAccept = true
        }
        return didAccept
    }
}

struct HandbookNotesListView: View {
    let items: [HandbookItem]
    @Binding var selectedCategory: HandbookCategory?
    @Binding var selectedFolder: String?
    @Binding var searchText: String
    let debouncedSearchText: String
    let selectedItemID: UUID?
    let isLoaded: Bool
    let onSelect: (HandbookItem) -> Void
    let onVisibleItemsChange: ([HandbookItem]) -> Void
    let onCreateDraft: () -> Void
    let onDelete: (HandbookItem) -> Void

    @State private var snapshot = HandbookNotesListSnapshot.empty
    @State private var snapshotTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            notesListHeader

            Divider()
                .overlay(AppTheme.hairline.opacity(0.64))

            if isLoaded {
                notesListContent
            } else {
                notesListSkeleton
            }
        }
        .background(notesListBackground)
        .onAppear {
            rebuildSnapshot(immediate: true)
        }
        .onChange(of: items) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: selectedCategory) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: selectedFolder) { _, _ in
            rebuildSnapshot()
        }
        .onChange(of: debouncedSearchText) { _, _ in
            rebuildSnapshot()
        }
        .onDisappear {
            snapshotTask?.cancel()
        }
    }

    private var notesListHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contextTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)

                    Text("\(snapshot.visibleCount) 条手记")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                Button(action: onCreateDraft) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 30)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.secondaryText)
                .help("新建手记")
            }

            SearchField(text: $searchText, placeholder: "搜索标题或正文")
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var notesListContent: some View {
        if snapshot.visibleCount == 0 {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "当前没有手记" : "没有匹配的手记")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                Text("点击右上角新建，或切换左侧分类。")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                        ForEach(snapshot.groups) { group in
                            HandbookNotesGroupView(
                                group: group,
                                selectedItemID: selectedItemID,
                                onSelect: onSelect,
                                onDelete: onDelete
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .onChange(of: selectedItemID) { _, newValue in
                    guard let newValue else { return }
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private var notesListSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppTheme.adaptiveWhite(index == 0 ? 0.72 : 0.48))
                    .frame(height: index == 0 ? 64 : 56)
            }
        }
        .padding(10)
    }

    private var contextTitle: String {
        if let selectedFolder, !selectedFolder.isEmpty {
            return selectedFolder
        }
        if selectedFolder == "" {
            return "未归档"
        }
        return selectedCategory?.title ?? "全部手记"
    }

    private var notesListBackground: Color {
        AppTheme.workSurface
    }

    private func rebuildSnapshot(immediate: Bool = false) {
        let newKey = HandbookNotesListSnapshotKey(
            items: items,
            selectedCategory: selectedCategory,
            selectedFolder: selectedFolder,
            searchText: debouncedSearchText
        )
        guard newKey != snapshot.cacheKey else { return }

        snapshotTask?.cancel()
        let category = selectedCategory
        let folder = selectedFolder
        let query = debouncedSearchText
        let sourceItems = items

        let applySnapshot: @MainActor (HandbookNotesListSnapshot) -> Void = { newSnapshot in
            let previousCount = snapshot.visibleCount
            snapshot = newSnapshot
            onVisibleItemsChange(newSnapshot.visibleItems)
            if previousCount != newSnapshot.visibleCount {
                PerformanceMonitor.event("HandbookNotesListSnapshot.count", detail: "\(newSnapshot.visibleCount)")
            }
        }

        if immediate || snapshot.cacheKey == .empty {
            let newSnapshot = PerformanceMonitor.measure("HandbookNotesListSnapshot.build.sync") {
                HandbookNotesListSnapshot(
                    items: sourceItems,
                    selectedCategory: category,
                    selectedFolder: folder,
                    searchText: query
                )
            }
            snapshot = newSnapshot
            onVisibleItemsChange(newSnapshot.visibleItems)
            return
        }

        snapshotTask = Task {
            try? await Task.sleep(for: .milliseconds(32))
            guard !Task.isCancelled else { return }
            let newSnapshot = await Task.detached(priority: .userInitiated) {
                PerformanceMonitor.measure("HandbookNotesListSnapshot.build") {
                    HandbookNotesListSnapshot(
                        items: sourceItems,
                        selectedCategory: category,
                        selectedFolder: folder,
                        searchText: query
                    )
                }
            }.value
            guard !Task.isCancelled else { return }
            applySnapshot(newSnapshot)
        }
    }
}

struct HandbookNotesGroupView: View {
    let group: HandbookNotesGroup
    let selectedItemID: UUID?
    let onSelect: (HandbookItem) -> Void
    let onDelete: (HandbookItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(group.rows) { row in
                HandbookNotesRow(
                    row: row,
                    isSelected: selectedItemID == row.id,
                    onSelect: {
                        onSelect(row.item)
                    },
                    onDelete: {
                        onDelete(row.item)
                    }
                )
                .id(row.id)
            }
        }
    }
}

struct HandbookNotesRow: View {
    let row: HandbookNotesRowData
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(row.dateText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .monospacedDigit()
                            .lineLimit(1)

                        Text(row.preview)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    HStack(spacing: 6) {
                        if !row.folder.isEmpty {
                            Label(row.folder, systemImage: "tag")
                                .lineLimit(1)
                        } else {
                            Label("未归档", systemImage: "tag")
                                .lineLimit(1)
                        }

                        if row.attachmentCount > 0 {
                            Label("\(row.attachmentCount)", systemImage: "paperclip")
                        }
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if row.attachmentCount > 0 {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(row.category.softColor.opacity(AppTheme.isDark ? 0.34 : 0.92))
                        .frame(width: 46, height: 38)
                        .overlay {
                            Image(systemName: "paperclip")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(row.category.accentColor)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(row.category.accentColor.opacity(0.16))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(rowBorder, lineWidth: isSelected ? 1 : 0.5)
        )
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("删除手记", systemImage: "trash")
            }
        }
        .draggable(row.id.uuidString)
        .onHover { hovered in
            isHovered = hovered
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return AppTheme.isDark ? AppTheme.adaptiveWhite(0.18) : Color(red: 0.858, green: 0.858, blue: 0.850)
        }
        if isHovered {
            return AppTheme.isDark ? AppTheme.adaptiveWhite(0.11) : Color(red: 0.922, green: 0.922, blue: 0.916)
        }
        return Color.clear
    }

    private var rowBorder: Color {
        if isSelected {
            return AppTheme.isDark ? AppTheme.border.opacity(0.52) : Color.black.opacity(0.04)
        }
        return AppTheme.hairline.opacity(isHovered ? 0.45 : 0)
    }
}

struct HandbookFolderSidebarRow: View {
    let title: String
    let icon: String
    let count: Int
    let accentColor: Color
    let isSelected: Bool
    let onSelect: () -> Void
    let onDrop: ([String]) -> Bool

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? accentColor : AppTheme.secondaryText)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? accentColor : AppTheme.ink)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .dropDestination(for: String.self) { itemIDs, _ in
            onDrop(itemIDs)
        }
        .onHover { hovered in
            isHovered = hovered
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return AppTheme.isDark ? accentColor.opacity(0.18) : Color(red: 0.884, green: 0.884, blue: 0.878)
        }
        if isHovered {
            return AppTheme.adaptiveWhite(AppTheme.isDark ? 0.10 : 0.42)
        }
        return Color.clear
    }
}

struct HandbookFolderTagButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onDrop: ([String]) -> Bool

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 5) {
                Image(systemName: "tag")
                    .font(.system(size: 10.5, weight: .bold))

                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)

                Text("\(count)")
                    .font(.system(size: 10.5, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.secondaryText)
            }
            .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.ink)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(tagBackground, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? AppTheme.accent.opacity(0.22) : AppTheme.hairline.opacity(0.60))
            )
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { itemIDs, _ in
            onDrop(itemIDs)
        }
    }

    private var tagBackground: Color {
        if isSelected {
            return AppTheme.accentSoft.opacity(0.92)
        }
        return AppTheme.adaptiveWhite(AppTheme.isDark ? 0.10 : 0.50)
    }
}

struct HandbookNotesSectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var measuredWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0 && currentX + size.width > maxWidth {
                currentY += lineHeight + lineSpacing
                currentX = 0
                lineHeight = 0
            }
            measuredWidth = max(measuredWidth, currentX + size.width)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth > 0 ? maxWidth : measuredWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > bounds.minX && currentX + size.width > bounds.maxX {
                currentY += lineHeight + lineSpacing
                currentX = bounds.minX
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
