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
            .foregroundStyle(AppTheme.workspaceTokens.selectedContent)
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
    var size: CGFloat = 46
    var shadowRadius: CGFloat = 5

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
        .frame(width: size, height: size)
        .shadow(color: AppTheme.adaptiveBlack(0.10), radius: shadowRadius, x: 0, y: shadowRadius > 0 ? 3 : 0)
        .accessibilityHidden(true)
    }

    private static var logoImage: NSImage? {
        // Prefer a top-level app resource (present when packaged as a .app).
        if let url = Bundle.main.url(forResource: "InAppLogo", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        // Fall back to the SwiftPM resource bundle. We resolve it ourselves
        // instead of using the generated `Bundle.module`, which fails to locate
        // the bundle inside a packaged .app and triggers a launch-time crash.
        if let bundle = resourceBundle,
           let url = bundle.url(forResource: "InAppLogo", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        return nil
    }

    /// Resolves the SwiftPM resource bundle across both dev (`swift build`/Xcode)
    /// and packaged `.app` layouts. Uses `Bundle(path:)` so a missing bundle
    /// returns `nil` instead of crashing.
    private static let resourceBundle: Bundle? = {
        let bundleName = "DailyTodos_DailyTodos.bundle"
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources").appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(bundleName),
        ]
        for candidate in candidates {
            if let bundle = Bundle(path: candidate.path) {
                return bundle
            }
        }
        return nil
    }()
}

struct UpdateDot: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(AppTheme.workspaceTokens.warning)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(AppTheme.adaptiveWhite(0.92), lineWidth: max(1, size * 0.18))
            )
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
                .foregroundStyle(isCollapsed ? AppTheme.workspaceTokens.selectedContent : AppTheme.workspaceTokens.textMuted)
                .frame(width: 28, height: 28)
                .background(buttonBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(AppTheme.hairline.opacity(isHovered || isCollapsed ? 0.78 : 0.0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.tactilePlain)
        .interactionHitArea(32)
        .help(isCollapsed ? "展开辅导航" : "收起辅导航")
        .onHover { hovered in
            withAnimation(AppMotion.hover) {
                isHovered = hovered
            }
        }
    }

    private var buttonBackground: Color {
        if isCollapsed {
            return AppTheme.workspaceTokens.accentSoft
        }
        if isHovered {
            return AppTheme.adaptiveWhite(0.62)
        }
        return Color.clear
    }
}

typealias CollapsedSecondarySidebarRail = CollapsedContextRail

struct CollapsedContextRail: View {
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
