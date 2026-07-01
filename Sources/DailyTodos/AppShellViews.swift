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
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
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

struct CollapsedSecondarySidebarRail: View {
    let title: String
    @Binding var isCollapsed: Bool

    var body: some View {
        VStack(spacing: 10) {
            SecondarySidebarCollapseButton(isCollapsed: $isCollapsed)
                .padding(.top, 9)

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1)
                .rotationEffect(.degrees(-90))
                .fixedSize()
                .frame(width: collapsedSecondarySidebarWidth, height: 72)

            Spacer(minLength: 0)
        }
        .frame(width: collapsedSecondarySidebarWidth)
        .frame(maxHeight: .infinity)
        .background(AppTheme.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(width: 1)
        }
    }
}
