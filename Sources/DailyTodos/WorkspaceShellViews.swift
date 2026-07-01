import SwiftUI

struct WorkspaceShell<ContextSidebar: View, Content: View>: View {
    let installedModules: [any AppModule]
    @Binding var activeModuleID: String
    @Binding var globalSearchText: String
    @Binding var isGlobalSearchPresented: Bool
    var isGlobalSearchFocused: FocusState<Bool>.Binding
    let globalSearchResults: [GlobalSearchModule: [GlobalSearchResult]]
    let globalSearchContext: GlobalCommandSearchContext
    let hasUpdate: Bool
    let onRefreshWorkspace: () -> Void
    let onOpenAccount: () -> Void
    @Binding var isPrimarySidebarVisible: Bool
    let onActivateModule: (String) -> Void
    let onGlobalSearchFocused: () -> Void
    let onGlobalSearchDismiss: () -> Void
    let onSelectGlobalSearchResult: (GlobalSearchResult) -> Void
    @ViewBuilder let contextSidebar: () -> ContextSidebar
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            if isPrimarySidebarVisible {
                ModuleRail(
                    activeModuleID: $activeModuleID,
                    installedModules: installedModules,
                    onActivateModule: onActivateModule
                )
                .transition(.move(edge: .leading).combined(with: .opacity))

                Divider()
                    .overlay(AppTheme.hairline)
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                GlobalTopBar(
                    workspaceName: "个人空间",
                    searchText: $globalSearchText,
                    isSearchPresented: $isGlobalSearchPresented,
                    isSearchFocused: isGlobalSearchFocused,
                    groupedResults: globalSearchResults,
                    searchContext: globalSearchContext,
                    hasUpdate: hasUpdate,
                    onRefreshWorkspace: onRefreshWorkspace,
                    onOpenAccount: onOpenAccount,
                    isPrimarySidebarVisible: $isPrimarySidebarVisible,
                    onSearchFocused: onGlobalSearchFocused,
                    onSearchDismiss: onGlobalSearchDismiss,
                    onSelectResult: onSelectGlobalSearchResult
                )
                .frame(height: 34)
                .zIndex(isGlobalSearchPresented ? 100 : 0)

                Divider()
                    .overlay(AppTheme.hairline)

                HStack(spacing: 0) {
                    contextSidebar()

                    Divider()
                        .overlay(AppTheme.hairline.opacity(0.82))

                    content()
                }
            }
        }
        .animation(AppMotion.reveal, value: isPrimarySidebarVisible)
        .background(AppTheme.workspaceTokens.canvas.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: .top)
        .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
        .font(.system(size: 13, weight: .regular, design: .default))
        .overlay {
            Button("搜索蚁序") {
                isGlobalSearchPresented = true
                isGlobalSearchFocused.wrappedValue = true
                onGlobalSearchFocused()
            }
            .keyboardShortcut("k", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }
}

struct GlobalTopBar: View {
    let workspaceName: String
    @Binding var searchText: String
    @Binding var isSearchPresented: Bool
    var isSearchFocused: FocusState<Bool>.Binding
    let groupedResults: [GlobalSearchModule: [GlobalSearchResult]]
    let searchContext: GlobalCommandSearchContext
    let hasUpdate: Bool
    let onRefreshWorkspace: () -> Void
    let onOpenAccount: () -> Void
    @Binding var isPrimarySidebarVisible: Bool
    let onSearchFocused: () -> Void
    let onSearchDismiss: () -> Void
    let onSelectResult: (GlobalSearchResult) -> Void
    @State private var selectedGlobalSearchResultID: GlobalSearchResult.ID?

    private var displayedResults: [GlobalSearchResult] {
        GlobalSearchModule.allCases.flatMap { groupedResults[$0] ?? [] }
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                WorkspaceIconButton(
                    systemName: isPrimarySidebarVisible ? "sidebar.leading" : "sidebar.left",
                    title: isPrimarySidebarVisible ? "隐藏模块侧栏" : "显示模块侧栏",
                    action: togglePrimarySidebar
                )

                WorkspaceIconButton(
                    systemName: hasUpdate ? "arrow.down.circle.fill" : "arrow.triangle.2.circlepath",
                    title: hasUpdate ? "有可用更新" : "刷新当前模块",
                    action: onRefreshWorkspace
                )
                .overlay(alignment: .topTrailing) {
                    if hasUpdate {
                        UpdateDot(size: 7)
                            .offset(x: -1, y: 2)
                            .transition(.scale.combined(with: .opacity))
                        }
                }
            }

            ZStack(alignment: .topLeading) {
                TextField("", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused(isSearchFocused)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .accessibilityLabel("搜索蚁序")
                .onChange(of: isSearchFocused.wrappedValue) { _, focused in
                    if focused {
                        isSearchPresented = true
                        onSearchFocused()
                        syncSelectedSearchResult()
                    }
                }
                .onChange(of: searchText) { _, newValue in
                    if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        isSearchPresented = true
                        onSearchFocused()
                    }
                    syncSelectedSearchResult()
                }
                .onExitCommand {
                    searchText = ""
                    isSearchPresented = false
                    isSearchFocused.wrappedValue = false
                    onSearchDismiss()
                    selectedGlobalSearchResultID = nil
                }

                if isSearchPresented {
                    GlobalCommandSearchPanel(
                        query: searchText,
                        groupedResults: groupedResults,
                        selectedResultID: selectedGlobalSearchResultID,
                        didLoadHandbookItems: searchContext.didLoadHandbookItems,
                        isLoadingHandbookItems: searchContext.isLoadingHandbookItems,
                        isCredentialVaultUnlocked: searchContext.isCredentialVaultUnlocked,
                        onSelect: { result in
                            selectedGlobalSearchResultID = result.id
                            handleSelectedResult(result)
                        }
                    )
                    .offset(y: 28)
                    .zIndex(20)
                }
            }
            .frame(width: 1, height: 1)
            .onMoveCommand(perform: handleMoveCommand)
            .onSubmit(handleSubmit)
            .onChange(of: groupedResults) { _, _ in
                syncSelectedSearchResult()
            }
            .onChange(of: isSearchPresented) { _, presented in
                if presented {
                    syncSelectedSearchResult()
                } else {
                    selectedGlobalSearchResultID = nil
                }
            }

            Spacer(minLength: 10)

            Button(action: onOpenAccount) {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .overlay(Text("我").font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.accent))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("账户")
        }
        .padding(.leading, isPrimarySidebarVisible ? 14 : 92)
        .padding(.trailing, 14)
        .background(AppTheme.workspaceTokens.topBar)
    }

    private func togglePrimarySidebar() {
        withAnimation(AppMotion.reveal) {
            isPrimarySidebarVisible.toggle()
        }
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard isSearchPresented, !displayedResults.isEmpty else { return }
        syncSelectedSearchResult()
        guard let currentIndex = displayedResults.firstIndex(where: { $0.id == selectedGlobalSearchResultID }) else {
            selectedGlobalSearchResultID = displayedResults.first?.id
            return
        }

        switch direction {
        case .down:
            selectedGlobalSearchResultID = displayedResults[min(currentIndex + 1, displayedResults.count - 1)].id
        case .up:
            selectedGlobalSearchResultID = displayedResults[max(currentIndex - 1, 0)].id
        default:
            break
        }
    }

    private func handleSubmit() {
        guard isSearchPresented,
              let selectedResult = displayedResults.first(where: { $0.id == selectedGlobalSearchResultID })
        else { return }
        handleSelectedResult(selectedResult)
    }

    private func handleSelectedResult(_ result: GlobalSearchResult) {
        onSelectResult(result)
        searchText = ""
        isSearchPresented = false
        isSearchFocused.wrappedValue = false
        selectedGlobalSearchResultID = nil
    }

    private func syncSelectedSearchResult() {
        guard isSearchPresented else {
            selectedGlobalSearchResultID = nil
            return
        }

        guard !displayedResults.isEmpty else {
            selectedGlobalSearchResultID = nil
            return
        }

        if let selectedGlobalSearchResultID,
           displayedResults.contains(where: { $0.id == selectedGlobalSearchResultID }) {
            return
        }

        self.selectedGlobalSearchResultID = displayedResults.first?.id
    }
}

struct ModuleRail: View {
    @Binding var activeModuleID: String
    let installedModules: [any AppModule]
    let onActivateModule: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                AppLogoImage(size: 26, shadowRadius: 2)

                VStack(alignment: .leading, spacing: 1) {
                    Text("蚁序")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.workspaceTokens.textPrimary)

                    Text("个人空间")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.workspaceTokens.textMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)

            ForEach(installedModules, id: \.id) { module in
                ModuleRailButton(module: module, isSelected: activeModuleID == module.id) {
                    PerformanceMonitor.event("ModuleRail.activate", detail: module.id)
                    onActivateModule(module.id)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 32)
        .padding(.horizontal, 9)
        .frame(width: primarySidebarWidth)
        .frame(maxHeight: .infinity)
        .background(AppTheme.workspaceTokens.moduleRail)
    }
}

struct ModuleRailButton: View {
    let module: any AppModule
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: module.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18, height: 20)

                Text(module.displayName)
                    .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? AppTheme.workspaceTokens.accent : AppTheme.workspaceTokens.textSecondary)
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(Rectangle())
            .background(rowFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(module.description)
        .onHover { isHovered = $0 }
        .animation(AppMotion.hover, value: isHovered)
        .animation(AppMotion.smooth, value: isSelected)
    }

    private var rowFill: Color {
        if isSelected {
            return AppTheme.workspaceTokens.accentSoft
        }
        if isHovered {
            return AppTheme.adaptiveWhite(0.50)
        }
        return Color.clear
    }
}

struct WorkspaceContentContainer<Header: View, Toolbar: View, BodyContent: View>: View {
    let headerHeight: CGFloat
    let showsHeader: Bool
    let showsToolbar: Bool
    @ViewBuilder let header: () -> Header
    @ViewBuilder let toolbar: () -> Toolbar
    @ViewBuilder let bodyContent: () -> BodyContent

    init(
        headerHeight: CGFloat = 50,
        showsHeader: Bool = true,
        showsToolbar: Bool = true,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder toolbar: @escaping () -> Toolbar,
        @ViewBuilder bodyContent: @escaping () -> BodyContent
    ) {
        self.headerHeight = headerHeight
        self.showsHeader = showsHeader
        self.showsToolbar = showsToolbar
        self.header = header
        self.toolbar = toolbar
        self.bodyContent = bodyContent
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                header()
                    .frame(height: headerHeight)
                Divider().overlay(AppTheme.hairline)
            }
            if showsToolbar {
                toolbar()
                    .frame(minHeight: 40)
                Divider().overlay(AppTheme.hairline.opacity(0.72))
            }
            bodyContent()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.workspaceTokens.contentSurface)
    }
}

struct WorkspaceContextHeader: View {
    let title: String
    let subtitle: String
    @Binding var isCollapsed: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.workspaceTokens.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            SecondarySidebarCollapseButton(isCollapsed: $isCollapsed)
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .frame(height: 46)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.workspaceTokens.contextSidebar)
    }
}

struct WorkspaceContentHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let actions: () -> Actions

    init(title: String, subtitle: String, @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.workspaceTokens.textMuted)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 16)
            actions()
        }
        .padding(.horizontal, 20)
        .frame(height: 50)
        .background(AppTheme.workspaceTokens.contentSurface)
    }
}

struct WorkspaceLocalToolbar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
        .frame(minHeight: 40)
        .background(AppTheme.workspaceTokens.contentSurface)
    }
}

struct WorkspaceSearchField: View {
    @Binding var text: String
    var placeholder = "搜索"
    var shortcutHint: String?
    var isFocused: FocusState<Bool>.Binding?
    @FocusState private var localFocus: Bool
    @State private var isHovered = false

    private var focusBinding: FocusState<Bool>.Binding {
        isFocused ?? $localFocus
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(text.isEmpty ? AppTheme.workspaceTokens.textMuted : AppTheme.workspaceTokens.accent)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused(focusBinding)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.workspaceTokens.textPrimary)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.workspaceTokens.textMuted)
            } else if let shortcutHint {
                Text(shortcutHint)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.workspaceTokens.textMuted)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            AppTheme.adaptiveWhite(focusBinding.wrappedValue || isHovered ? 0.96 : 0.84),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(focusBinding.wrappedValue ? AppTheme.workspaceTokens.focusRing.opacity(0.45) : AppTheme.workspaceTokens.hairline)
        )
        .onHover { isHovered = $0 }
    }
}

protocol WorkspaceSegmentedOption: Identifiable, CaseIterable, Hashable {
    var label: String { get }
    var icon: String { get }
}

struct WorkspaceSegmentedControl<Option: WorkspaceSegmentedOption>: View {
    @Binding var selection: Option
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(Option.allCases), id: \.self) { option in
                Button {
                    withAnimation(AppMotion.modeSwitch) {
                        selection = option
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: option.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(option.label)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(selection == option ? .white : AppTheme.workspaceTokens.textMuted)
                    .frame(height: 28)
                    .frame(maxWidth: .infinity)
                    .background(selectionBackground(for: option))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(AppTheme.adaptiveWhite(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.workspaceTokens.hairline.opacity(0.82))
        )
    }

    @ViewBuilder
    private func selectionBackground(for option: Option) -> some View {
        if selection == option {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(AppTheme.workspaceTokens.accent)
                .matchedGeometryEffect(id: "workspaceSegmentedSelection", in: selectionNamespace)
        }
    }
}

struct WorkspaceListRowSurface<Content: View>: View {
    let isSelected: Bool
    let isHovered: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? AppTheme.workspaceTokens.accent.opacity(0.28) : AppTheme.workspaceTokens.hairline.opacity(isHovered ? 0.92 : 0.55))
            )
    }

    private var background: Color {
        if isSelected { return AppTheme.workspaceTokens.listRowSelected }
        if isHovered { return AppTheme.workspaceTokens.listRowHover }
        return AppTheme.workspaceTokens.listRow
    }
}

struct ContentHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        WorkspaceContentHeader(title: title, subtitle: subtitle)
    }
}

struct ContentToolbar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        WorkspaceLocalToolbar(content: content)
    }
}

struct WorkspaceIconButton: View {
    let systemName: String
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 30, height: 30)
                .foregroundStyle(AppTheme.workspaceTokens.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered ? AppTheme.adaptiveWhite(0.62) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover { isHovered = $0 }
    }
}

struct EmptyWorkspaceContextSidebar: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
            Text("当前模块暂无二级导航")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.workspaceTokens.textMuted)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .frame(width: secondarySidebarWidth)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.workspaceTokens.contextSidebar)
    }
}
