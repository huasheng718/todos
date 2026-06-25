import SwiftUI

struct HandbookContentView: View {
    let allItems: [HandbookItem]
    let isLoaded: Bool
    let selectedCategory: HandbookCategory?
    let selectedFolder: String?
    let searchText: String
    let onCreate: (HandbookCategory, String, String, String, [HandbookAttachment]) -> Void
    let onUpdate: (HandbookItem, HandbookCategory, String, String, String, [HandbookAttachment]) -> Void
    let onDelete: (HandbookItem) -> Void

    @State private var draftTitle = ""
    @State private var draftBody = ""
    @State private var selectedItemID: UUID?
    @State private var shouldSelectLatestAfterCreate = false
    @State private var activeFilter: HandbookListFilter = .all
    @State private var showsLoadingState = false
    @State private var scopedItemsCache: [HandbookItem] = []
    @State private var visibleItemsCache: [HandbookItem] = []
    @State private var visibleItemsCacheKey: HandbookListCacheKey?
    @State private var rebuildTask: Task<Void, Never>?
    @FocusState private var focusedField: HandbookFocusField?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HandbookCaptureBar(
                title: $draftTitle,
                content: $draftBody,
                focusedField: $focusedField,
                suggestedCategory: selectedCategory,
                suggestedFolder: selectedFolder,
                onCreate: submit
            )

            contentArea
        }
        .animation(AppMotion.smooth, value: selectedItemID)
        .onChange(of: allItems) { _, newItems in
            rebuildVisibleItems(from: newItems)
        }
        .onChange(of: selectedCategory) { _, _ in
            rebuildVisibleItems()
        }
        .onChange(of: selectedFolder) { _, _ in
            rebuildVisibleItems()
        }
        .onChange(of: searchText) { _, _ in
            rebuildVisibleItems()
        }
        .onChange(of: activeFilter) { _, _ in
            rebuildVisibleItems()
        }
        .onChange(of: isLoaded) { _, newValue in
            if newValue {
                showsLoadingState = false
            } else {
                scheduleLoadingStateIfNeeded()
            }
        }
        .onAppear {
            rebuildVisibleItems()
            scheduleLoadingStateIfNeeded()
        }
    }

    private func submit() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = draftBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !body.isEmpty else {
            focusedField = .title
            return
        }
        let category = selectedCategory ?? HandbookCategory.infer(from: "\(title)\n\(body)")
        let folder = (selectedFolder ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        onCreate(category, folder, title, body, [])
        shouldSelectLatestAfterCreate = true
        activeFilter = .all
        draftTitle = ""
        draftBody = ""
        focusedField = .title
    }

    private func selectedItem(in visibleItems: [HandbookItem]) -> HandbookItem? {
        guard let selectedItemID else {
            return visibleItems.first
        }
        return visibleItems.first { $0.id == selectedItemID } ?? visibleItems.first
    }

    private func scopedItems(from sourceItems: [HandbookItem]) -> [HandbookItem] {
        let cleanedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return sourceItems.filter { item in
            (selectedCategory == nil || item.category == selectedCategory)
                && matchesFolder(item)
                && matchesSearch(item, query: cleanedQuery)
        }
    }

    private func visibleItems(from sourceItems: [HandbookItem]) -> [HandbookItem] {
        activeFilter.filter(scopedItems(from: sourceItems))
    }

    private var currentListSnapshot: (scopedItems: [HandbookItem], visibleItems: [HandbookItem]) {
        if visibleItemsCacheKey == listCacheKey(from: allItems) {
            return (scopedItemsCache, visibleItemsCache)
        }

        let scopedItems = scopedItems(from: allItems)
        return (scopedItems, activeFilter.filter(scopedItems))
    }

    private func matchesFolder(_ item: HandbookItem) -> Bool {
        Self.matchesFolderStatic(item, folder: selectedFolder?.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func matchesSearch(_ item: HandbookItem, query: String) -> Bool {
        Self.matchesSearchStatic(item, query: query)
    }

    nonisolated private static func matchesFolderStatic(_ item: HandbookItem, folder: String?) -> Bool {
        guard let folder, !folder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        return item.trimmedFolder == folder.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func matchesSearchStatic(_ item: HandbookItem, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return item.title.localizedCaseInsensitiveContains(query)
            || item.body.localizedCaseInsensitiveContains(query)
            || item.folder.localizedCaseInsensitiveContains(query)
            || item.category.title.localizedCaseInsensitiveContains(query)
            || item.attachments.contains { $0.name.localizedCaseInsensitiveContains(query) }
    }

    @ViewBuilder
    private var contentArea: some View {
        let snapshot = currentListSnapshot
        let items = snapshot.scopedItems
        let visibleItems = snapshot.visibleItems
        let selectedItem = selectedItem(in: visibleItems)

        if !isLoaded && showsLoadingState {
            HStack(alignment: .top, spacing: 10) {
                handbookListCard(itemsCount: 0, visibleItems: [], selectedItem: nil)
                    .frame(minWidth: 230, idealWidth: 260, maxWidth: 300, maxHeight: .infinity)

                HandbookLoadingState()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .transition(AppMotion.viewTransition)
        } else if !isLoaded {
            HStack(alignment: .top, spacing: 10) {
                handbookListCard(itemsCount: 0, visibleItems: [], selectedItem: nil)
                    .frame(minWidth: 230, idealWidth: 260, maxWidth: 300, maxHeight: .infinity)

                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if items.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                handbookListCard(itemsCount: items.count, visibleItems: visibleItems, selectedItem: selectedItem)
                    .frame(minWidth: 230, idealWidth: 260, maxWidth: 300, maxHeight: .infinity)

                HandbookEmptyState(category: selectedCategory)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .transition(AppMotion.viewTransition)
        } else if visibleItems.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                handbookListCard(itemsCount: items.count, visibleItems: visibleItems, selectedItem: selectedItem)
                    .frame(minWidth: 230, idealWidth: 260, maxWidth: 300, maxHeight: .infinity)

                HandbookFilteredEmptyState(filter: activeFilter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .transition(AppMotion.viewTransition)
        } else {
            HStack(alignment: .top, spacing: 10) {
                handbookListCard(itemsCount: items.count, visibleItems: visibleItems, selectedItem: selectedItem)
                    .frame(minWidth: 230, idealWidth: 260, maxWidth: 300, maxHeight: .infinity)

                HandbookDetailPanel(
                    item: selectedItem,
                    onUpdate: onUpdate,
                    onDelete: { item in
                        onDelete(item)
                        if selectedItemID == item.id {
                            selectedItemID = nil
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(AppMotion.inlineTransition)
            }
            .transition(AppMotion.viewTransition)
        }
    }

    private func scheduleLoadingStateIfNeeded() {
        guard !isLoaded else {
            showsLoadingState = false
            return
        }

        let delay: Duration = .milliseconds(120)
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !isLoaded else { return }
            withAnimation(AppMotion.quick) {
                showsLoadingState = true
            }
        }
    }

    private func handbookListCard(itemsCount: Int, visibleItems: [HandbookItem], selectedItem: HandbookItem?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HandbookListCardHeader(
                selectedCategory: selectedCategory,
                selectedFolder: selectedFolder,
                totalCount: itemsCount,
                visibleCount: visibleItems.count,
                activeFilter: $activeFilter
            )

            Divider()
                .overlay(AppTheme.hairline.opacity(0.56))

            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(visibleItems) { item in
                        HandbookRow(
                            displayData: HandbookRowDisplayData(
                                item: item,
                                cardSummary: item.cardSummary,
                                bodyCharacterCount: item.bodyCharacterCount,
                                lengthKind: item.lengthKind
                            ),
                            isSelected: selectedItem?.id == item.id,
                            onSelect: {
                                withAnimation(AppMotion.smooth) {
                                    selectedItemID = item.id
                                }
                            }
                        )
                        .transition(AppMotion.rowTransition)
                    }
                }
                .padding(7)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppTheme.panel.opacity(0.74), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.72))
        )
        .shadow(color: AppTheme.rowShadow.opacity(0.22), radius: 5, x: 0, y: 2)
    }

    private func syncSelection(with currentItems: [HandbookItem]) {
        if shouldSelectLatestAfterCreate {
            selectedItemID = currentItems.first?.id
            shouldSelectLatestAfterCreate = false
            return
        }

        guard !currentItems.isEmpty else {
            selectedItemID = nil
            return
        }

        if let selectedItemID, currentItems.contains(where: { $0.id == selectedItemID }) {
            return
        }

        selectedItemID = currentItems.first?.id
    }

    private func rebuildVisibleItems(from sourceItems: [HandbookItem]? = nil) {
        rebuildTask?.cancel()
        let items = sourceItems ?? allItems
        let category = selectedCategory
        let folder = selectedFolder?.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filter = activeFilter

        rebuildTask = Task {
            let scoped = await Task.detached(priority: .userInitiated) {
                let cleanedQuery = query
                return items.filter { item in
                    (category == nil || item.category == category)
                        && HandbookContentView.matchesFolderStatic(item, folder: folder)
                        && HandbookContentView.matchesSearchStatic(item, query: cleanedQuery)
                }
            }.value

            let visible = filter.filter(scoped)
            let cacheKey = HandbookContentView.listCacheKeyStatic(
                from: items,
                selectedCategory: category,
                selectedFolder: folder,
                searchText: query,
                activeFilter: filter
            )

            await MainActor.run {
                scopedItemsCache = scoped
                visibleItemsCache = visible
                visibleItemsCacheKey = cacheKey
                syncSelection(with: visible)
                PerformanceMonitor.event("Handbook.visibleItems.count", detail: "\(visible.count)")
            }
        }
    }

    private func listCacheKey(from sourceItems: [HandbookItem]) -> HandbookListCacheKey {
        Self.listCacheKeyStatic(
            from: sourceItems,
            selectedCategory: selectedCategory,
            selectedFolder: selectedFolder?.trimmingCharacters(in: .whitespacesAndNewlines),
            searchText: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            activeFilter: activeFilter
        )
    }

    nonisolated private static func listCacheKeyStatic(
        from sourceItems: [HandbookItem],
        selectedCategory: HandbookCategory?,
        selectedFolder: String?,
        searchText: String,
        activeFilter: HandbookListFilter
    ) -> HandbookListCacheKey {
        HandbookListCacheKey(
            itemCount: sourceItems.count,
            firstItemID: sourceItems.first?.id,
            firstUpdatedAt: sourceItems.first?.updatedAt,
            lastItemID: sourceItems.last?.id,
            lastUpdatedAt: sourceItems.last?.updatedAt,
            selectedCategory: selectedCategory,
            selectedFolder: selectedFolder,
            searchText: searchText,
            activeFilter: activeFilter
        )
    }
}



struct HandbookListCardHeader: View {
    let selectedCategory: HandbookCategory?
    let selectedFolder: String?
    let totalCount: Int
    let visibleCount: Int
    @Binding var activeFilter: HandbookListFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(contextTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ink)

                Text(contextSubtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                ForEach(HandbookListFilter.allCases) { filter in
                    HandbookFilterChip(
                        filter: filter,
                        isActive: activeFilter == filter,
                        onSelect: {
                            withAnimation(AppMotion.modeSwitch) {
                                activeFilter = filter
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 11)
        .padding(.top, 10)
        .padding(.bottom, 9)
        .background(AppTheme.panel.opacity(0.84))
    }

    private var contextTitle: String {
        if let selectedFolder, !selectedFolder.isEmpty {
            return selectedFolder
        }
        return selectedCategory?.title ?? "手记工作台"
    }

    private var contextSubtitle: String {
        let scope = selectedCategory?.subtitle ?? "规则、调研、会议与灵感的收集沉淀"
        if activeFilter == .all {
            return "\(scope) · \(totalCount) 条沉淀"
        }
        return "\(scope) · \(activeFilter.title) \(visibleCount)/\(totalCount)"
    }
}

struct HandbookFilterChip: View {
    let filter: HandbookListFilter
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 5) {
                Image(systemName: filter.icon)
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 15)

                if isActive {
                    Text(filter.title)
                        .font(.system(size: 11, weight: .bold))
                        .transition(AppMotion.inlineTransition)
                }
            }
            .padding(.horizontal, isActive ? 8 : 6)
            .frame(minWidth: isActive ? 58 : 30, minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.tactilePlain)
        .foregroundStyle(isActive ? AppTheme.accent : AppTheme.mutedInk)
        .background(isActive ? AppTheme.accentSoft.opacity(0.92) : AppTheme.adaptiveWhite(0.48), in: Capsule())
        .overlay(
            Capsule()
                .stroke(isActive ? AppTheme.accent.opacity(0.22) : AppTheme.hairline.opacity(0.56))
        )
        .help(filter.title)
    }
}

struct HandbookCaptureBar: View {
    @Binding var title: String
    @Binding var content: String
    var focusedField: FocusState<HandbookFocusField?>.Binding
    let suggestedCategory: HandbookCategory?
    let suggestedFolder: String?
    let onCreate: () -> Void
    @State private var isHovered = false
    @State private var isExpanded = false

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var inferredCategory: HandbookCategory {
        suggestedCategory ?? HandbookCategory.infer(from: "\(title)\n\(content)")
    }

    private var categoryTone: HandbookCategory {
        inferredCategory
    }

    private var hasInput: Bool {
        canCreate
    }

    private var shouldShowContextLine: Bool {
        isExpanded || !content.isEmpty || suggestedFolder?.isEmpty == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded || !content.isEmpty ? 8 : 6) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(categoryTone.accentColor)
                    .frame(width: 28, height: 28)
                    .background(categoryTone.softColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                if hasInput || suggestedCategory != nil {
                    HandbookInferenceBadge(category: inferredCategory, isLocked: suggestedCategory != nil)
                        .transition(AppMotion.inlineTransition)
                }

                TextField("快速收集：会议结论、业务规则、调研发现或灵感", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .focused(focusedField, equals: .title)
                    .submitLabel(.done)
                    .onSubmit {
                        submitIfReady()
                    }

                Button {
                    withAnimation(AppMotion.reveal) {
                        isExpanded.toggle()
                        if isExpanded {
                            focusedField.wrappedValue = .body
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "text.alignleft")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(AppTheme.mutedInk)
                .help(isExpanded ? "收起正文" : "展开正文")

                Button {
                    onCreate()
                    if canCreate {
                        withAnimation(AppMotion.capture) {
                            isExpanded = false
                        }
                    }
                } label: {
                    Label("收集", systemImage: "tray.and.arrow.down")
                        .font(.caption.weight(.semibold))
                        .frame(width: 72, height: 30)
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(.white)
                .background(canCreate ? AppTheme.accentWarm : AppTheme.adaptiveBlack(0.28), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(canCreate ? AppTheme.adaptiveWhite(0.42) : AppTheme.adaptiveBlack(0.05))
                )
                .interactionHitArea()
                .disabled(!canCreate)
            }

            if shouldShowContextLine {
                captureContextLine
                    .padding(.leading, 36)
                    .padding(.trailing, 2)
                    .transition(AppMotion.inlineTransition)
            }

            if isExpanded || !content.isEmpty {
                HandbookBodyEditor(
                    "补充正文：记录背景、证据、结论或可复用口径",
                    text: $content,
                    minHeight: 66,
                    maxHeight: 150
                )
                    .focused(focusedField, equals: .body)
                    .transition(AppMotion.inlineTransition)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, isExpanded || !content.isEmpty ? 9 : 7)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(AppTheme.panel)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(canCreate ? categoryTone.accentColor : AppTheme.accent)
                        .frame(width: 3)
                        .opacity(canCreate ? 0.95 : 0.34)
                        .padding(.vertical, 9)
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(isHovered ? categoryTone.accentColor.opacity(0.30) : AppTheme.border.opacity(0.70))
        )
        .shadow(color: AppTheme.rowShadow.opacity(isHovered ? 0.72 : 0.42), radius: isHovered ? 10 : 5, x: 0, y: isHovered ? 5 : 2)
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
        .animation(AppMotion.reveal, value: isExpanded)
        .animation(AppMotion.quick, value: hasInput)
    }

    private var captureContextLine: some View {
        HStack(spacing: 6) {
            Label("输入后自动判断主类型", systemImage: "wand.and.sparkles")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.mutedInk)

            if let suggestedFolder, !suggestedFolder.isEmpty {
                Text("· 将归入 \(suggestedFolder)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            } else {
                Text("· 二级目录可在整理时补充")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private func submitIfReady() {
        guard canCreate else { return }
        onCreate()
        withAnimation(AppMotion.capture) {
            isExpanded = false
        }
    }

}

struct HandbookInferenceBadge: View {
    let category: HandbookCategory
    let isLocked: Bool

    var body: some View {
        Label(isLocked ? category.title : "推断：\(category.title)", systemImage: isLocked ? "pin.fill" : category.icon)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(category.accentColor)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(category.softColor, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(category.accentColor.opacity(0.22))
            )
            .help(isLocked ? "当前由左侧分类决定" : "根据输入内容自动判断，后续可在编辑中调整")
    }
}

struct HandbookRowDisplayData: Equatable {
    let item: HandbookItem
    let cardSummary: String?
    let bodyCharacterCount: Int
    let lengthKind: HandbookLengthKind
}

struct HandbookRow: View {
    let displayData: HandbookRowDisplayData
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    private var item: HandbookItem { displayData.item }

    var body: some View {
        let lengthKind = displayData.lengthKind
        let characterCount = displayData.bodyCharacterCount

        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(item.category.accentColor)
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: item.category.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(item.category.accentColor)
                        .frame(width: 16)

                    Text(item.category.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(item.category.accentColor)

                    Spacer(minLength: 8)

                    Text(item.updatedAt.formatted(.dateTime.month().day().hour().minute()))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Text(item.displayTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineSpacing(1)
                    .lineLimit(2)

                if let summary = displayData.cardSummary {
                    Text(summary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineSpacing(2)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 6) {
                    if !item.trimmedFolder.isEmpty {
                        Image(systemName: "folder")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                        Text(item.trimmedFolder)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                            .lineLimit(1)
                    }

                    Text(lengthKind.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(lengthKind.color)

                    if !item.attachments.isEmpty {
                        Image(systemName: "paperclip")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                        Text("\(item.attachments.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                    }

                    Text("\(characterCount) 字")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.mutedInk)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? item.category.accentColor.opacity(0.42) : AppTheme.hairline.opacity(isHovered ? 0.92 : 0.62))
        )
        .shadow(color: AppTheme.rowShadow.opacity(isSelected ? 0.70 : (isHovered ? 0.56 : 0.24)), radius: isSelected ? 8 : (isHovered ? 6 : 2), x: 0, y: isSelected ? 3 : 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
        .animation(AppMotion.hover, value: isHovered)
        .animation(AppMotion.smooth, value: isSelected)
    }

    private var rowBackground: Color {
        if isSelected {
            return item.category.softColor.opacity(0.92)
        }
        if isHovered {
            return AppTheme.panel
        }
        return AppTheme.panel.opacity(0.82)
    }
}

struct HandbookCategoryTag: View {
    let category: HandbookCategory

    var body: some View {
        Label(category.title, systemImage: category.icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(category.accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(category.softColor, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(category.accentColor.opacity(0.22))
            )
    }
}

struct HandbookFolderTag: View {
    let folder: String

    var body: some View {
        Label(folder, systemImage: "folder")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(AppTheme.ink.opacity(0.82))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(AppTheme.adaptiveWhite(0.68), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.border.opacity(0.82))
            )
    }
}

struct HandbookLengthTag: View {
    let kind: HandbookLengthKind

    var body: some View {
        Label(kind.title, systemImage: kind.icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(kind.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(kind.softColor, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(kind.color.opacity(0.22))
            )
    }
}

struct HandbookAttachmentCountTag: View {
    let count: Int

    var body: some View {
        Label("\(count)", systemImage: "paperclip")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(AppTheme.accentSoft.opacity(0.72), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.accent.opacity(0.20))
            )
    }
}

extension HandbookCategory {
    static func infer(from text: String) -> HandbookCategory {
        let normalized = text.lowercased()
        let scores: [(category: HandbookCategory, score: Int)] = HandbookCategory.allCases.map { category in
            (category, category.inferenceKeywords.reduce(0) { score, keyword in
                normalized.contains(keyword) ? score + 1 : score
            })
        }
        return scores.max { lhs, rhs in lhs.score < rhs.score }?.score == 0
            ? .businessRule
            : scores.max { lhs, rhs in lhs.score < rhs.score }?.category ?? .businessRule
    }

    private var inferenceKeywords: [String] {
        switch self {
        case .businessRule:
            ["规则", "口径", "流程", "审批", "规范", "要求", "制度", "边界", "权限", "配置", "字段", "规则"]
        case .research:
            ["调研", "竞品", "用户", "访谈", "观察", "数据", "资料", "摘录", "报告", "分析", "样本"]
        case .meeting:
            ["会议", "纪要", "对接", "同步", "讨论", "结论", "行动项", "参会", "复盘", "评审", "会"]
        case .inspiration:
            ["灵感", "想法", "机会", "假设", "创意", "可以", "尝试", "也许", "思路", "idea", "验证"]
        }
    }

    var accentColor: Color {
        switch self {
        case .businessRule:
            Color(red: 0.18, green: 0.48, blue: 0.35)
        case .research:
            Color(red: 0.22, green: 0.40, blue: 0.74)
        case .meeting:
            Color(red: 0.76, green: 0.42, blue: 0.16)
        case .inspiration:
            Color(red: 0.50, green: 0.34, blue: 0.78)
        }
    }

    var softColor: Color {
        switch self {
        case .businessRule:
            Color(red: 0.90, green: 0.96, blue: 0.92)
        case .research:
            Color(red: 0.90, green: 0.94, blue: 1.0)
        case .meeting:
            Color(red: 1.0, green: 0.94, blue: 0.86)
        case .inspiration:
            Color(red: 0.95, green: 0.91, blue: 1.0)
        }
    }
}

extension HandbookLengthKind {
    var color: Color {
        switch self {
        case .snippet:
            Color(red: 0.36, green: 0.46, blue: 0.58)
        case .medium:
            Color(red: 0.16, green: 0.50, blue: 0.52)
        case .article:
            Color(red: 0.64, green: 0.34, blue: 0.16)
        }
    }

    var softColor: Color {
        switch self {
        case .snippet:
            Color(red: 0.92, green: 0.95, blue: 0.98)
        case .medium:
            Color(red: 0.88, green: 0.96, blue: 0.95)
        case .article:
            Color(red: 0.99, green: 0.92, blue: 0.85)
        }
    }
}
