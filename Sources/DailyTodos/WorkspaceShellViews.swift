import SwiftUI

struct WorkspaceShell<ContextSidebar: View, Content: View>: View {
    let installedModules: [any AppModule]
    @Binding var activeModuleID: String
    @Binding var globalSearchText: String
    let activeModuleTitle: String
    let activeModuleSubtitle: String
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
        .background(AppTheme.workspaceCanvas.ignoresSafeArea())
        .foregroundStyle(AppTheme.ink)
        .font(.system(size: 13, weight: .regular, design: .default))
    }
}

struct GlobalTopBar: View {
    let workspaceName: String
    @Binding var searchText: String
    let hasUpdate: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 9) {
                AppLogoImage()
                    .frame(width: 30, height: 30)
                Text("蚁序")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text(workspaceName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .frame(width: 220, alignment: .leading)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                TextField("搜索蚁序", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                Text("⌘K")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: 520)
            .frame(height: 32)
            .background(AppTheme.workspaceSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.hairline)
            )

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
        .padding(.horizontal, 14)
        .background(AppTheme.topBar)
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
        .background(AppTheme.sidebar)
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
            .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.secondaryText)
            .frame(width: primarySidebarWidth - 12, height: 48)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AppTheme.accentSoft : (isHovered ? AppTheme.adaptiveWhite(0.52) : Color.clear))
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
        .background(AppTheme.workspaceSurface)
    }
}

struct ContentHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 16)
        }
        .padding(.horizontal, 20)
        .background(AppTheme.workspaceSurface)
    }
}

struct ContentToolbar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .background(AppTheme.workspaceSurface)
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
                .foregroundStyle(AppTheme.secondaryText)
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
                .foregroundStyle(AppTheme.ink)
            Text("当前模块暂无二级导航")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.mutedInk)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .frame(width: secondarySidebarWidth)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.sidebar)
    }
}
