import SwiftUI

struct HandbookSidebarView: View {
    @EnvironmentObject private var store: TodoStore
    @Binding var selectedCategory: HandbookCategory?
    @Binding var selectedFolder: String?
    var searchText: Binding<String>?
    @State private var metrics = HandbookSidebarMetrics.empty
    @State private var metricsTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if let searchText {
                        SearchField(text: searchText, placeholder: "搜索标题或正文")
                    }
                    categoryList(metrics: metrics)
                    folderList(metrics: metrics)
                }
                .padding(.horizontal, 17)
                .padding(.top, 48)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)

            Divider()
                .overlay(AppTheme.hairline.opacity(0.7))

            VStack(alignment: .leading, spacing: 4) {
                Text("手记")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("共 \(metrics.totalCount) 条沉淀")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 13)
        }
        .background(AppTheme.sidebar)
        .foregroundStyle(AppTheme.ink)
        .onAppear {
            rebuildMetrics()
        }
        .onChange(of: store.handbookItems) { _, _ in
            rebuildMetrics()
        }
        .onChange(of: selectedCategory) { _, _ in
            rebuildMetrics()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("手记")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.ink)
            Text("业务规则、调研、会议、灵感")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
    }

    private func categoryList(metrics: HandbookSidebarMetrics) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SidebarSectionLabel("分类")

            HandbookCategoryButton(
                title: "全部手记",
                subtitle: "完整知识池",
                systemImage: "tray.full",
                count: metrics.totalCount,
                isSelected: selectedCategory == nil
            ) {
                selectedCategory = nil
                selectedFolder = nil
            }

            ForEach(HandbookCategory.allCases) { category in
                HandbookCategoryButton(
                    title: category.title,
                    subtitle: category.subtitle,
                    systemImage: category.icon,
                    count: metrics.categoryCounts[category, default: 0],
                    isSelected: selectedCategory == category
                ) {
                    selectedCategory = category
                    selectedFolder = nil
                }
            }
        }
    }

    private func folderList(metrics: HandbookSidebarMetrics) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SidebarSectionLabel("二级目录")

            HandbookCategoryButton(
                title: "全部目录",
                subtitle: "不按目录过滤",
                systemImage: "folder",
                count: metrics.scopedCount,
                isSelected: selectedFolder == nil
            ) {
                selectedFolder = nil
            }

            if metrics.folders.isEmpty {
                Text("在快记或编辑中填写目录后自动归类")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.adaptiveWhite(0.34), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                ForEach(metrics.folders, id: \.self) { folder in
                    HandbookCategoryButton(
                        title: folder,
                        subtitle: "自定义归类",
                        systemImage: "folder.fill",
                        count: metrics.folderCounts[folder, default: 0],
                        isSelected: selectedFolder == folder
                    ) {
                        selectedFolder = folder
                    }
                }
            }
        }
    }


    private func rebuildMetrics() {
        metricsTask?.cancel()
        let items = store.handbookItems
        let category = selectedCategory

        metricsTask = Task {
            let newMetrics = await Task.detached(priority: .userInitiated) {
                HandbookSidebarMetrics(items: items, selectedCategory: category)
            }.value

            await MainActor.run {
                metrics = newMetrics
            }
        }
    }
}

struct HandbookCategoryButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? AppTheme.accentWarm : Color.clear)
                    .frame(width: 3, height: 30)

                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk)
                        .lineLimit(1)
                }

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isSelected ? .white : AppTheme.accent)
                        .frame(minWidth: 24, minHeight: 20)
                        .background(isSelected ? AppTheme.accent : AppTheme.accent.opacity(0.11), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(navBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.24) : AppTheme.adaptiveWhite(isHovered ? 0.36 : 0.0))
            )
        }
        .buttonStyle(.tactilePlain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { hovered in
            isHovered = hovered
        }
        .animation(AppMotion.hover, value: isHovered)
        .animation(AppMotion.smooth, value: isSelected)
    }

    private var navBackground: Color {
        if isSelected {
            return AppTheme.sidebarSelected
        }
        if isHovered {
            return AppTheme.adaptiveWhite(0.46)
        }
        return Color.clear
    }
}
