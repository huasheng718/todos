import Foundation
import SwiftUI

let statusColumnWidth: CGFloat = 82
let progressColumnWidth: CGFloat = 104
let priorityColumnWidth: CGFloat = 78
let followUpColumnWidth: CGFloat = 154
let todoActionColumnWidth: CGFloat = 128
let compactHitTargetSize: CGFloat = 38
let primarySidebarWidth: CGFloat = 184
let secondarySidebarWidth: CGFloat = 264
let collapsedSecondarySidebarWidth: CGFloat = 46

enum AppMotion {
    static let reduceMotionStorageKey = "DailyTodos.reduceMotion"

    private static var reduceMotion: Bool {
        UserDefaults.standard.bool(forKey: reduceMotionStorageKey)
    }

    static var press: Animation {
        spring(response: 0.18, dampingFraction: 0.86, blendDuration: 0.02, reducedDuration: 0.06)
    }

    static var quick: Animation {
        easeOut(duration: 0.14, reducedDuration: 0.05)
    }

    static var hover: Animation {
        easeOut(duration: 0.12, reducedDuration: 0.04)
    }

    static var smooth: Animation {
        spring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.03, reducedDuration: 0.08)
    }

    static var reveal: Animation {
        spring(response: 0.30, dampingFraction: 0.86, blendDuration: 0.04, reducedDuration: 0.08)
    }

    static var list: Animation {
        spring(response: 0.32, dampingFraction: 0.90, blendDuration: 0.04, reducedDuration: 0.08)
    }

    static var capture: Animation {
        spring(response: 0.34, dampingFraction: 0.82, blendDuration: 0.04, reducedDuration: 0.08)
    }

    static var status: Animation {
        spring(response: 0.26, dampingFraction: 0.84, blendDuration: 0.03, reducedDuration: 0.07)
    }

    static var complete: Animation {
        spring(response: 0.34, dampingFraction: 0.72, blendDuration: 0.04, reducedDuration: 0.08)
    }

    static var modeSwitch: Animation {
        spring(response: 0.30, dampingFraction: 0.90, blendDuration: 0.04, reducedDuration: 0.08)
    }

    static var sectionSwitch: Animation {
        easeOut(duration: 0.16, reducedDuration: 0.06)
    }

    static var rowTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.985, anchor: .top)),
            removal: .opacity.combined(with: .scale(scale: 0.985, anchor: .center))
        )
    }

    static var viewTransition: AnyTransition {
        .opacity
    }

    static var inlineTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .scale(scale: 0.985, anchor: .top))
    }

    private static func spring(
        response: Double,
        dampingFraction: Double,
        blendDuration: Double,
        reducedDuration: Double
    ) -> Animation {
        reduceMotion
            ? .easeOut(duration: reducedDuration)
            : .interactiveSpring(response: response, dampingFraction: dampingFraction, blendDuration: blendDuration)
    }

    private static func easeOut(duration: Double, reducedDuration: Double) -> Animation {
        .easeOut(duration: reduceMotion ? reducedDuration : duration)
    }
}

struct WorkspaceThemeTokens {
    let canvas: Color
    let topBar: Color
    let moduleRail: Color
    let contextSidebar: Color
    let contentSurface: Color
    let contentAltSurface: Color
    let listRow: Color
    let listRowHover: Color
    let listRowSelected: Color
    let hairline: Color
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let accent: Color
    let accentForeground: Color
    let accentSoft: Color
    let action: Color
    let actionSoft: Color
    let success: Color
    let warning: Color
    let danger: Color
    let focusRing: Color
    let shadow: Color
}

struct TactilePlainButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(buttonFill(isPressed: configuration.isPressed))
            }
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(AppMotion.press, value: configuration.isPressed)
            .animation(AppMotion.hover, value: isHovered)
            .onHover { hovered in
                isHovered = hovered
            }
    }

    private func buttonFill(isPressed: Bool) -> Color {
        guard isEnabled else {
            return Color.clear
        }
        if isPressed {
            return AppTheme.accentSoft.opacity(0.82)
        }
        if isHovered {
            return AppTheme.adaptiveWhite(0.68)
        }
        return Color.clear
    }
}

extension ButtonStyle where Self == TactilePlainButtonStyle {
    static var tactilePlain: TactilePlainButtonStyle { TactilePlainButtonStyle() }
}

extension View {
    func interactionHitArea(_ minSize: CGFloat = compactHitTargetSize) -> some View {
        frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }

    func sectionVisibility(_ isVisible: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
            .zIndex(isVisible ? 1 : 0)
    }
}

enum AppSkin: String, CaseIterable, Identifiable {
    case ocean
    case aurora
    case board
    case leafcutter
    case workspace

    static let storageKey = "dailyTodos.selectedSkin"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ocean: "清蓝工作台"
        case .aurora: "柔紫课程"
        case .board: "看板粉彩"
        case .leafcutter: "切叶森工"
        case .workspace: "工作台"
        }
    }

    var shortTitle: String {
        switch self {
        case .ocean: "清蓝"
        case .aurora: "柔紫"
        case .board: "粉彩"
        case .leafcutter: "切叶"
        case .workspace: "工作台"
        }
    }

    var icon: String {
        switch self {
        case .ocean: "drop.fill"
        case .aurora: "sparkles"
        case .board: "square.grid.2x2.fill"
        case .leafcutter: "leaf.fill"
        case .workspace: "rectangle.3.group"
        }
    }

    static var stored: AppSkin {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey),
              let skin = AppSkin(rawValue: rawValue) else {
            return .ocean
        }
        return skin
    }

    static var current: AppSkin {
        activeAppSkin
    }
}

nonisolated(unsafe) var activeAppSkin = AppSkin.stored
nonisolated(unsafe) var activeColorScheme: ColorScheme = .light

enum AppTheme {
    static var workspaceTokens: WorkspaceThemeTokens {
        WorkspaceThemeTokens(
            canvas: workspaceCanvas,
            topBar: topBar,
            moduleRail: workspaceModuleRail,
            contextSidebar: workspaceContextSidebar,
            contentSurface: workspaceSurface,
            contentAltSurface: workspaceAltSurface,
            listRow: .clear,
            listRowHover: workspaceListRowHover,
            listRowSelected: accentSoft,
            hairline: hairline,
            textPrimary: workspacePrimaryText,
            textSecondary: workspaceSecondaryText,
            textMuted: workspaceMutedText,
            accent: accent,
            accentForeground: workspaceAccentForeground,
            accentSoft: accentSoft,
            action: accent,
            actionSoft: accentSoft,
            success: success,
            warning: workspaceWarning,
            danger: workspaceDanger,
            focusRing: accent,
            shadow: .clear
        )
    }

    static var isDark: Bool {
        activeColorScheme == .dark
    }

    static func adaptiveWhite(_ opacity: Double) -> Color {
        guard isDark else {
            return Color.white.opacity(opacity)
        }
        let adjustedOpacity = min(0.92, max(0.08, opacity * 0.72))
        return darkOverlayBase.opacity(adjustedOpacity)
    }

    static func adaptiveBlack(_ opacity: Double) -> Color {
        guard isDark else {
            return Color.black.opacity(opacity)
        }
        return Color.black.opacity(min(0.74, max(0.08, opacity + 0.16)))
    }

    static var canvasGradient: [Color] {
        [workspaceCanvas, workspaceAltSurface]
    }

    static var workSurface: Color {
        workspaceAltSurface
    }

    static var sidebar: Color {
        workspaceContextSidebar
    }

    static var sidebarSelected: Color { accentSoft }

    static var ink: Color { workspacePrimaryText }

    static var mutedInk: Color { workspaceMutedText }

    static var secondaryText: Color { workspaceSecondaryText }

    static var panel: Color { workspaceSurface }

    static var row: Color { workspaceSurface }

    static func rowTint(priority: TodoPriority, isOverdue: Bool) -> Color {
        workspaceSurface
    }

    static var border: Color { workspaceHairline }

    static var hairline: Color { workspaceHairline }

    static var accent: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 0.365, green: 0.596, blue: 1.000)
            case .aurora: Color(red: 0.620, green: 0.536, blue: 0.930)
            case .board: Color(red: 0.890, green: 0.430, blue: 0.650)
            case .leafcutter: Color(red: 0.360, green: 0.720, blue: 0.540)
            case .workspace: Color(red: 0.400, green: 0.560, blue: 1.000)
            }
        } else {
            switch AppSkin.current {
            case .ocean: Color(red: 0.170, green: 0.400, blue: 0.950)
            case .aurora: Color(red: 0.435, green: 0.357, blue: 0.827)
            case .board: Color(red: 0.720, green: 0.280, blue: 0.510)
            case .leafcutter: Color(red: 0.184, green: 0.490, blue: 0.361)
            case .workspace: Color(red: 0.239, green: 0.388, blue: 0.867)
            }
        }
    }

    static var accentCyan: Color { accent }

    static var accentSoft: Color {
        switch AppSkin.current {
        case .ocean: accent.opacity(isDark ? 0.18 : 0.10)
        case .aurora: accent.opacity(isDark ? 0.20 : 0.12)
        case .board: accent.opacity(isDark ? 0.18 : 0.08)
        case .leafcutter: accent.opacity(isDark ? 0.20 : 0.11)
        case .workspace: accent.opacity(isDark ? 0.18 : 0.10)
        }
    }

    static var shellStroke: Color { workspaceHairline }

    static var shadow: Color { .clear }

    static var rowShadow: Color { .clear }

    static var accentWarm: Color { workspaceWarning }

    static var success: Color {
        isDark ? Color(red: 0.360, green: 0.820, blue: 0.560) : Color(red: 0.140, green: 0.580, blue: 0.340)
    }

    static var successSoft: Color {
        isDark ? Color(red: 0.070, green: 0.190, blue: 0.120).opacity(0.96) : Color(red: 0.900, green: 0.970, blue: 0.910)
    }

    static var workspaceCanvas: Color {
        isDark
            ? Color(red: 0.082, green: 0.090, blue: 0.106)
            : Color(red: 0.957, green: 0.961, blue: 0.969)
    }

    static var workspaceModuleRail: Color {
        isDark
            ? Color(red: 0.098, green: 0.110, blue: 0.129)
            : Color(red: 0.933, green: 0.941, blue: 0.953)
    }

    static var workspaceContextSidebar: Color {
        isDark
            ? Color(red: 0.114, green: 0.125, blue: 0.149)
            : Color(red: 0.969, green: 0.973, blue: 0.980)
    }

    static var workspaceSurface: Color {
        isDark
            ? Color(red: 0.129, green: 0.145, blue: 0.169)
            : Color.white
    }

    static var workspaceAltSurface: Color {
        isDark
            ? Color(red: 0.149, green: 0.169, blue: 0.196)
            : Color(red: 0.973, green: 0.976, blue: 0.984)
    }

    static var workspaceListRowHover: Color {
        isDark
            ? Color(red: 0.169, green: 0.188, blue: 0.220)
            : Color(red: 0.957, green: 0.965, blue: 0.973)
    }

    static var workspacePrimaryText: Color {
        isDark
            ? Color(red: 0.949, green: 0.957, blue: 0.969)
            : Color(red: 0.125, green: 0.141, blue: 0.165)
    }

    static var workspaceSecondaryText: Color {
        isDark
            ? Color(red: 0.722, green: 0.753, blue: 0.800)
            : Color(red: 0.349, green: 0.384, blue: 0.439)
    }

    static var workspaceMutedText: Color {
        isDark
            ? Color(red: 0.604, green: 0.639, blue: 0.690)
            : Color(red: 0.395, green: 0.430, blue: 0.480)
    }

    static var workspaceAccentForeground: Color {
        isDark ? workspaceCanvas : Color.white
    }

    static var workspaceHairline: Color {
        isDark
            ? Color(red: 0.204, green: 0.227, blue: 0.263)
            : Color(red: 0.851, green: 0.871, blue: 0.906)
    }

    static var workspaceDanger: Color {
        isDark
            ? Color(red: 1.000, green: 0.482, blue: 0.482)
            : Color(red: 0.769, green: 0.294, blue: 0.294)
    }

    static var workspaceWarning: Color {
        isDark
            ? Color(red: 0.941, green: 0.639, blue: 0.290)
            : Color(red: 0.659, green: 0.396, blue: 0.000)
    }

    static var topBar: Color { workspaceModuleRail }
    static var workspaceSidebar: Color { workspaceContextSidebar }

    private static var darkOverlayBase: Color {
        workspaceAltSurface
    }
}
