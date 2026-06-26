import SwiftUI
import AppKit

struct SkinPickerButton: View {
    @Binding var selection: String

    private var currentSkin: AppSkin {
        AppSkin(rawValue: selection) ?? .ocean
    }

    var body: some View {
        Menu {
            ForEach(AppSkin.allCases) { skin in
                Button {
                    withAnimation(AppMotion.smooth) {
                        activeAppSkin = skin
                        selection = skin.rawValue
                    }
                } label: {
                    HStack {
                        Label(skin.title, systemImage: skin.icon)
                        if skin == currentSkin {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: currentSkin.icon)
                    .font(.system(size: 11, weight: .bold))
                Text(currentSkin.shortTitle)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(AppTheme.accent)
            .frame(width: 76, height: 30)
            .background(AppTheme.accentSoft, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.accent.opacity(0.22))
            )
            .interactionHitArea()
        }
        .menuStyle(.borderlessButton)
        .help("切换皮肤")
        .accessibilityLabel("切换皮肤")
        .accessibilityValue(currentSkin.title)
    }
}

struct AppTopBar: View {
    let title: String
    let subtitle: String
    @Binding var isSecondarySidebarCollapsed: Bool
    let isAIEnabled: Bool
    let onOpenAISettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .contentTransition(.opacity)

                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }

            Spacer(minLength: 24)

            HStack(spacing: 8) {
                SecondarySidebarCollapseButton(isCollapsed: $isSecondarySidebarCollapsed)
                AISettingsButton(isEnabled: isAIEnabled, action: onOpenAISettings)
            }
            .padding(.trailing, 16)
        }
        .padding(.leading, 20)
        .background(topBarBackground)
    }

    private var topBarBackground: some View {
        Color.clear
    }
}

struct AISettingsButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text("AI")
                    .font(.caption.weight(.semibold))
                Circle()
                    .fill(isEnabled ? Color(red: 0.18, green: 0.70, blue: 0.40) : AppTheme.mutedInk.opacity(0.45))
                    .frame(width: 6, height: 6)
            }
            .foregroundStyle(isEnabled ? AppTheme.accent : AppTheme.mutedInk)
            .frame(width: 64, height: 30)
            .background(isEnabled ? AppTheme.accentSoft : AppTheme.adaptiveWhite(0.58), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isEnabled ? AppTheme.accent.opacity(0.24) : AppTheme.hairline)
            )
            .interactionHitArea()
        }
        .buttonStyle(.tactilePlain)
        .help("AI 设置")
    }
}

struct AppLogoImage: View {
    var body: some View {
        Group {
            if let image = Self.logoImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .frame(width: 46, height: 46)
        .shadow(color: AppTheme.adaptiveBlack(0.10), radius: 5, x: 0, y: 3)
        .accessibilityHidden(true)
    }

    private static var logoImage: NSImage? {
        if let url = Bundle.module.url(forResource: "InAppLogo", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        if let url = Bundle.main.url(forResource: "InAppLogo", withExtension: "png") {
            return NSImage(contentsOf: url)
        }

        return nil
    }
}

struct PrimarySidebarView: View {
    @Binding var activeSection: AppSection
    let hasUpdate: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                ForEach(AppSection.allCases) { section in
                    PrimarySidebarButton(
                        section: section,
                        isSelected: activeSection == section
                    ) {
                        PerformanceMonitor.event("PrimarySidebar.section", detail: section.rawValue)
                        withAnimation(AppMotion.sectionSwitch) {
                            activeSection = section
                        }
                    }
                }
            }
            .padding(.top, 52)

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                AppLogoImage()
                    .frame(width: 42, height: 42)

                Text("蚁序")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                Button(action: onOpenSettings) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .semibold))
                            .interactionHitArea()

                        if hasUpdate {
                            UpdateDot(size: 8)
                                .offset(x: -6, y: 7)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .buttonStyle(.tactilePlain)
                .foregroundStyle(hasUpdate ? AppTheme.accent : AppTheme.mutedInk)
                .help(hasUpdate ? "有新版本，打开设置查看" : "应用设置")
                .accessibilityLabel(hasUpdate ? "应用设置，有新版本可用" : "应用设置")
            }
            .padding(.bottom, 14)
        }
        .frame(width: primarySidebarWidth)
        .frame(maxHeight: .infinity)
        .background(AppTheme.sidebar)
    }
}

struct UpdateDot: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(TodoPriority.high.displayColor)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(AppTheme.adaptiveWhite(0.92), lineWidth: max(1, size * 0.18))
            )
            .shadow(color: TodoPriority.high.displayColor.opacity(0.35), radius: 4, x: 0, y: 1)
            .accessibilityLabel("有可用更新")
    }
}

struct SecondarySidebarCollapseButton: View {
    @Binding var isCollapsed: Bool
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(AppMotion.modeSwitch) {
                isCollapsed.toggle()
            }
        } label: {
            Image(systemName: isCollapsed ? "sidebar.leading" : "sidebar.left")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isCollapsed ? AppTheme.accent : AppTheme.mutedInk)
                .frame(width: 34, height: 30)
                .background(buttonBackground, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.hairline.opacity(isHovered || isCollapsed ? 0.92 : 0.56))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.tactilePlain)
        .interactionHitArea()
        .help(isCollapsed ? "展开辅导航" : "收起辅导航")
        .accessibilityLabel("辅导航")
        .accessibilityValue(isCollapsed ? "已收起" : "已展开")
        .onHover { hovered in
            withAnimation(AppMotion.hoverAware) {
                isHovered = hovered
            }
        }
    }

    private var buttonBackground: Color {
        if isCollapsed {
            return AppTheme.panel.opacity(0.96)
        }
        if isHovered {
            return AppTheme.adaptiveWhite(0.82)
        }
        return AppTheme.adaptiveWhite(0.58)
    }
}

struct PrimarySidebarButton: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: section.icon)
                    .font(.system(size: 18, weight: .bold))
                Text(section.title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.mutedInk)
            .frame(width: 58, height: 56)
            .background(buttonBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.22) : AppTheme.adaptiveWhite(isHovered ? 0.38 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.tactilePlain)
        .help(section.title)
        .accessibilityLabel(section.title)
        .accessibilityValue(isSelected ? "已选中" : "未选中")
        .onHover { hovered in
            withAnimation(AppMotion.hoverAware) {
                isHovered = hovered
            }
        }
    }

    private var buttonBackground: Color {
        if isSelected {
            return AppTheme.sidebarSelected
        }
        if isHovered {
            return AppTheme.adaptiveWhite(0.44)
        }
        return Color.clear
    }
}
