import SwiftUI

struct WorkspaceShell<ContextSidebar: View, Content: View>: View {
    let installedModules: [any AppModule]
    @Binding var activeModuleID: String
    @Binding var globalSearchText: String
    var isGlobalSearchFocused: FocusState<Bool>.Binding
    let hasUpdate: Bool
    let onOpenSettings: () -> Void
    let onActivateModule: (String) -> Void
    @ViewBuilder let contextSidebar: () -> ContextSidebar
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            GlobalTopBar(
                workspaceName: "个人空间",
                searchText: $globalSearchText,
                isSearchFocused: isGlobalSearchFocused,
                hasUpdate: hasUpdate,
                onOpenSettings: onOpenSettings
            )
            .frame(height: 52)

            Divider()
                .overlay(AppTheme.hairline)

            HStack(spacing: 0) {
                ModuleRail(
                    activeModuleID: $activeModuleID,
                    installedModules: installedModules,
                    onActivateModule: onActivateModule
                )

                Divider()
                    .overlay(AppTheme.hairline)

                contextSidebar()

                Divider()
                    .overlay(AppTheme.hairline.opacity(0.82))

                content()
            }
        }
        .background(AppTheme.workspaceTokens.canvas.ignoresSafeArea())
        .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
        .font(.system(size: 13, weight: .regular, design: .default))
    }
}

struct GlobalTopBar: View {
    let workspaceName: String
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    let hasUpdate: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 9) {
                AppLogoImage()
                    .frame(width: 30, height: 30)
                Text("蚁序")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
                Text(workspaceName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.workspaceTokens.textMuted)
            }
            .frame(width: 220, alignment: .leading)

            WorkspaceSearchField(
                text: $searchText,
                placeholder: "搜索蚁序",
                shortcutHint: "⌘K",
                isFocused: isSearchFocused
            )
            .frame(maxWidth: 520)

            Spacer(minLength: 16)

            WorkspaceIconButton(systemName: "sparkles", title: "AI Assistant") {}
            ZStack(alignment: .topTrailing) {
                WorkspaceIconButton(
                    systemName: hasUpdate ? "arrow.down.circle.fill" : "arrow.triangle.2.circlepath",
                    title: "更新",
                    action: onOpenSettings
                )

                if hasUpdate {
                    UpdateDot(size: 7)
                        .offset(x: -1, y: 2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            WorkspaceIconButton(systemName: "gearshape", title: "设置", action: onOpenSettings)
            Circle()
                .fill(AppTheme.accentSoft)
                .overlay(Text("我").font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.accent))
                .frame(width: 30, height: 30)
        }
        .background {
            Button("搜索蚁序") {
                isSearchFocused.wrappedValue = true
            }
            .keyboardShortcut("k", modifiers: [.command])
            .labelsHidden()
            .opacity(0.001)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .background(AppTheme.workspaceTokens.topBar)
    }
}

struct ModuleRail: View {
    @Binding var activeModuleID: String
    let installedModules: [any AppModule]
    let onActivateModule: (String) -> Void

    var body: some View {
        VStack(spacing: 6) {
            ForEach(installedModules, id: \.id) { module in
                ModuleRailButton(module: module, isSelected: activeModuleID == module.id) {
                    PerformanceMonitor.event("ModuleRail.activate", detail: module.id)
                    onActivateModule(module.id)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
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
            VStack(spacing: 4) {
                Image(systemName: module.icon)
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 34, height: 30)
                Text(module.displayName)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? AppTheme.workspaceTokens.accent : AppTheme.workspaceTokens.textSecondary)
            .frame(width: primarySidebarWidth - 12, height: 48)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AppTheme.workspaceTokens.accentSoft : (isHovered ? AppTheme.adaptiveWhite(0.52) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .help(module.description)
        .onHover { isHovered = $0 }
        .animation(AppMotion.hover, value: isHovered)
        .animation(AppMotion.smooth, value: isSelected)
    }
}

struct WorkspaceContentContainer<Header: View, Toolbar: View, BodyContent: View>: View {
    @ViewBuilder let header: () -> Header
    @ViewBuilder let toolbar: () -> Toolbar
    @ViewBuilder let bodyContent: () -> BodyContent

    var body: some View {
        VStack(spacing: 0) {
            header()
                .frame(height: 56)
            Divider().overlay(AppTheme.hairline)
            toolbar()
                .frame(minHeight: 44)
            Divider().overlay(AppTheme.hairline.opacity(0.72))
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
        .padding(.leading, 18)
        .padding(.trailing, 12)
        .frame(height: 52)
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
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.workspaceTokens.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)
            actions()
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
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
        .padding(.vertical, 7)
        .frame(minHeight: 44)
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
        .frame(height: 32)
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
                    .frame(height: 30)
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
