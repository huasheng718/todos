import SwiftUI

let statusColumnWidth: CGFloat = 82
let progressColumnWidth: CGFloat = 104
let priorityColumnWidth: CGFloat = 78
let followUpColumnWidth: CGFloat = 154
let todoActionColumnWidth: CGFloat = 128
let compactHitTargetSize: CGFloat = 38
let primarySidebarWidth: CGFloat = 76
let secondarySidebarWidth: CGFloat = 250
let collapsedSecondarySidebarWidth: CGFloat = 46

enum AppMotion {
    static let press = Animation.interactiveSpring(response: 0.18, dampingFraction: 0.86, blendDuration: 0.02)
    static let quick = Animation.easeOut(duration: 0.14)
    static let hover = Animation.easeOut(duration: 0.12)
    static let smooth = Animation.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.03)
    static let reveal = Animation.interactiveSpring(response: 0.30, dampingFraction: 0.86, blendDuration: 0.04)
    static let list = Animation.interactiveSpring(response: 0.32, dampingFraction: 0.90, blendDuration: 0.04)
    static let capture = Animation.interactiveSpring(response: 0.34, dampingFraction: 0.82, blendDuration: 0.04)
    static let status = Animation.interactiveSpring(response: 0.26, dampingFraction: 0.84, blendDuration: 0.03)
    static let complete = Animation.interactiveSpring(response: 0.34, dampingFraction: 0.72, blendDuration: 0.04)
    static let modeSwitch = Animation.interactiveSpring(response: 0.30, dampingFraction: 0.90, blendDuration: 0.04)
    static let sectionSwitch = Animation.easeOut(duration: 0.16)

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
        .opacity.combined(with: .scale(scale: 0.985, anchor: .top))
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
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.46)
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
            moduleRail: sidebar,
            contextSidebar: sidebar,
            contentSurface: workspaceSurface,
            contentAltSurface: workSurface,
            listRow: panel,
            listRowHover: adaptiveWhite(isDark ? 0.16 : 0.72),
            listRowSelected: accentSoft,
            hairline: hairline,
            textPrimary: ink,
            textSecondary: secondaryText,
            textMuted: mutedInk,
            accent: accent,
            accentSoft: accentSoft,
            action: accentWarm,
            actionSoft: accentWarm.opacity(isDark ? 0.18 : 0.12),
            success: success,
            warning: accentWarm,
            danger: TodoPriority.high.displayColor,
            focusRing: accent,
            shadow: rowShadow
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
        if isDark {
            switch AppSkin.current {
            case .ocean:
                return [
                    Color(red: 0.050, green: 0.075, blue: 0.096),
                    Color(red: 0.025, green: 0.110, blue: 0.120)
                ]
            case .aurora:
                return [
                    Color(red: 0.068, green: 0.054, blue: 0.098),
                    Color(red: 0.098, green: 0.046, blue: 0.088)
                ]
            case .board:
                return [
                    Color(red: 0.070, green: 0.070, blue: 0.076),
                    Color(red: 0.112, green: 0.096, blue: 0.090)
                ]
            case .leafcutter:
                return [
                    Color(red: 0.070, green: 0.078, blue: 0.052),
                    Color(red: 0.126, green: 0.076, blue: 0.040)
                ]
            case .workspace:
                return [
                    Color(red: 0.070, green: 0.074, blue: 0.082),
                    Color(red: 0.112, green: 0.096, blue: 0.090)
                ]
            }
        }
        switch AppSkin.current {
        case .ocean:
            return [
                Color(red: 0.925, green: 0.960, blue: 1.0),
                Color(red: 0.855, green: 0.915, blue: 0.990)
            ]
        case .aurora:
            return [
                Color(red: 0.965, green: 0.915, blue: 1.0),
                Color(red: 0.900, green: 0.980, blue: 0.975)
            ]
        case .board:
            return [
                Color(red: 0.900, green: 0.900, blue: 0.905),
                Color(red: 0.965, green: 0.930, blue: 0.960)
            ]
        case .leafcutter:
            return [
                Color(red: 0.938, green: 0.962, blue: 0.895),
                Color(red: 0.984, green: 0.902, blue: 0.812)
            ]
        case .workspace:
            return [
                Color(red: 0.957, green: 0.961, blue: 0.969),
                Color(red: 0.933, green: 0.941, blue: 0.953)
            ]
        }
    }

    static var workSurface: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 0.052, green: 0.070, blue: 0.088)
            case .aurora: Color(red: 0.060, green: 0.052, blue: 0.082)
            case .board: Color(red: 0.070, green: 0.070, blue: 0.076)
            case .leafcutter: Color(red: 0.070, green: 0.064, blue: 0.044)
            case .workspace: Color(red: 0.070, green: 0.074, blue: 0.082)
            }
        } else {
            switch AppSkin.current {
            case .ocean: Color(red: 0.972, green: 0.985, blue: 0.995)
            case .aurora: Color(red: 0.987, green: 0.984, blue: 0.996)
            case .board: Color(red: 0.984, green: 0.984, blue: 0.978)
            case .leafcutter: Color(red: 0.982, green: 0.968, blue: 0.928)
            case .workspace: Color.white
            }
        }
    }

    static var sidebar: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 0.066, green: 0.088, blue: 0.110)
            case .aurora: Color(red: 0.078, green: 0.064, blue: 0.108)
            case .board: Color(red: 0.084, green: 0.082, blue: 0.092)
            case .leafcutter: Color(red: 0.084, green: 0.074, blue: 0.048)
            case .workspace: Color(red: 0.084, green: 0.082, blue: 0.092)
            }
        } else {
            switch AppSkin.current {
            case .ocean: Color(red: 0.918, green: 0.950, blue: 0.982)
            case .aurora: Color(red: 0.952, green: 0.928, blue: 0.985)
            case .board: Color(red: 0.935, green: 0.932, blue: 0.952)
            case .leafcutter: Color(red: 0.938, green: 0.910, blue: 0.805)
            case .workspace: Color(red: 0.933, green: 0.941, blue: 0.953)
            }
        }
    }

    static var sidebarSelected: Color {
        switch AppSkin.current {
        case .ocean: AppTheme.adaptiveWhite(0.74)
        case .aurora: AppTheme.adaptiveWhite(0.72)
        case .board: AppTheme.adaptiveWhite(0.68)
        case .leafcutter: AppTheme.adaptiveWhite(0.64)
        case .workspace: AppTheme.adaptiveWhite(0.68)
        }
    }

    static var ink: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 0.910, green: 0.950, blue: 0.972)
            case .aurora: Color(red: 0.942, green: 0.932, blue: 0.974)
            case .board: Color(red: 0.932, green: 0.930, blue: 0.918)
            case .leafcutter: Color(red: 0.958, green: 0.928, blue: 0.870)
            case .workspace: Color(red: 0.932, green: 0.930, blue: 0.918)
            }
        } else {
            switch AppSkin.current {
            case .ocean: Color(red: 0.035, green: 0.060, blue: 0.095)
            case .aurora: Color(red: 0.045, green: 0.042, blue: 0.070)
            case .board: Color(red: 0.060, green: 0.058, blue: 0.062)
            case .leafcutter: Color(red: 0.095, green: 0.060, blue: 0.035)
            case .workspace: Color(red: 0.141, green: 0.153, blue: 0.180)
            }
        }
    }

    static var mutedInk: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 0.650, green: 0.728, blue: 0.790)
            case .aurora: Color(red: 0.716, green: 0.680, blue: 0.800)
            case .board: Color(red: 0.710, green: 0.704, blue: 0.690)
            case .leafcutter: Color(red: 0.744, green: 0.676, blue: 0.560)
            case .workspace: Color(red: 0.710, green: 0.704, blue: 0.690)
            }
        } else {
            switch AppSkin.current {
            case .ocean: Color(red: 0.245, green: 0.310, blue: 0.410)
            case .aurora: Color(red: 0.315, green: 0.300, blue: 0.405)
            case .board: Color(red: 0.245, green: 0.240, blue: 0.270)
            case .leafcutter: Color(red: 0.315, green: 0.245, blue: 0.165)
            case .workspace: Color(red: 0.541, green: 0.565, blue: 0.600)
            }
        }
    }

    static var secondaryText: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 0.760, green: 0.830, blue: 0.882)
            case .aurora: Color(red: 0.810, green: 0.785, blue: 0.878)
            case .board: Color(red: 0.805, green: 0.800, blue: 0.780)
            case .leafcutter: Color(red: 0.830, green: 0.760, blue: 0.640)
            case .workspace: Color(red: 0.805, green: 0.800, blue: 0.780)
            }
        } else {
            switch AppSkin.current {
            case .ocean: Color(red: 0.150, green: 0.205, blue: 0.285)
            case .aurora: Color(red: 0.205, green: 0.190, blue: 0.285)
            case .board: Color(red: 0.160, green: 0.155, blue: 0.180)
            case .leafcutter: Color(red: 0.220, green: 0.160, blue: 0.100)
            case .workspace: Color(red: 0.420, green: 0.447, blue: 0.502)
            }
        }
    }

    static var panel: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 0.085, green: 0.112, blue: 0.136)
            case .aurora: Color(red: 0.092, green: 0.078, blue: 0.126)
            case .board: Color(red: 0.104, green: 0.104, blue: 0.112)
            case .leafcutter: Color(red: 0.102, green: 0.088, blue: 0.060)
            case .workspace: Color(red: 0.104, green: 0.104, blue: 0.112)
            }
        } else {
            switch AppSkin.current {
            case .ocean, .aurora: AppTheme.adaptiveWhite(0.985)
            case .board: AppTheme.adaptiveWhite(0.970)
            case .leafcutter: Color(red: 1.0, green: 0.988, blue: 0.950).opacity(0.985)
            case .workspace: Color.white
            }
        }
    }

    static var row: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 0.102, green: 0.136, blue: 0.164)
            case .aurora: Color(red: 0.110, green: 0.092, blue: 0.150)
            case .board: Color(red: 0.124, green: 0.124, blue: 0.132)
            case .leafcutter: Color(red: 0.120, green: 0.102, blue: 0.066)
            case .workspace: Color(red: 0.124, green: 0.124, blue: 0.132)
            }
        } else {
            switch AppSkin.current {
            case .ocean: Color.white
            case .aurora: Color(red: 0.990, green: 0.982, blue: 1.0)
            case .board: Color(red: 0.980, green: 0.988, blue: 0.998)
            case .leafcutter: Color(red: 1.0, green: 0.986, blue: 0.942)
            case .workspace: Color(red: 0.980, green: 0.980, blue: 0.984)
            }
        }
    }

    static func rowTint(priority: TodoPriority, isOverdue: Bool) -> Color {
        if isDark {
            if isOverdue {
                return Color(red: 0.235, green: 0.108, blue: 0.122).opacity(0.96)
            }

            switch priority {
            case .high:
                return Color(red: 0.218, green: 0.104, blue: 0.118).opacity(0.94)
            case .medium:
                switch AppSkin.current {
                case .ocean: return Color(red: 0.080, green: 0.170, blue: 0.176).opacity(0.96)
                case .aurora: return Color(red: 0.132, green: 0.096, blue: 0.230).opacity(0.96)
                case .board: return Color(red: 0.168, green: 0.148, blue: 0.102).opacity(0.96)
                case .leafcutter: return Color(red: 0.174, green: 0.112, blue: 0.062).opacity(0.96)
                case .workspace: return Color(red: 0.168, green: 0.148, blue: 0.102).opacity(0.96)
                }
            case .low:
                return Color(red: 0.085, green: 0.158, blue: 0.112).opacity(0.94)
            }
        }

        switch AppSkin.current {
        case .ocean:
            if isOverdue {
                return Color(red: 1.0, green: 0.945, blue: 0.955)
            }
            return row
        case .aurora:
            if isOverdue {
                return Color(red: 1.0, green: 0.945, blue: 0.955)
            }
            switch priority {
            case .high: return Color(red: 1.0, green: 0.925, blue: 0.965)
            case .medium: return Color(red: 0.940, green: 0.925, blue: 1.0)
            case .low: return Color(red: 0.920, green: 0.980, blue: 0.965)
            }
        case .board:
            if isOverdue {
                return Color(red: 1.0, green: 0.945, blue: 0.955)
            }
            switch priority {
            case .high: return Color(red: 1.0, green: 0.910, blue: 0.900)
            case .medium: return Color(red: 0.900, green: 0.940, blue: 1.0)
            case .low: return Color(red: 0.890, green: 0.980, blue: 0.930)
            }
        case .leafcutter:
            if isOverdue {
                return Color(red: 1.0, green: 0.945, blue: 0.955)
            }
            switch priority {
            case .high: return Color(red: 1.0, green: 0.930, blue: 0.880)
            case .medium: return Color(red: 0.965, green: 0.952, blue: 0.870)
            case .low: return Color(red: 0.910, green: 0.965, blue: 0.860)
            }
        case .workspace:
            if isOverdue {
                return Color(red: 1.0, green: 0.945, blue: 0.955)
            }
            switch priority {
            case .high: return Color(red: 1.0, green: 0.910, blue: 0.900)
            case .medium: return Color(red: 0.900, green: 0.940, blue: 1.0)
            case .low: return Color(red: 0.890, green: 0.980, blue: 0.930)
            }
        }
    }

    static var border: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 0.250, green: 0.344, blue: 0.418)
            case .aurora: Color(red: 0.320, green: 0.260, blue: 0.450)
            case .board: Color(red: 0.330, green: 0.326, blue: 0.340)
            case .leafcutter: Color(red: 0.365, green: 0.288, blue: 0.176)
            case .workspace: Color(red: 0.330, green: 0.326, blue: 0.340)
            }
        } else {
            switch AppSkin.current {
            case .ocean: Color(red: 0.705, green: 0.785, blue: 0.875)
            case .aurora: Color(red: 0.760, green: 0.705, blue: 0.880)
            case .board: Color(red: 0.745, green: 0.740, blue: 0.765)
            case .leafcutter: Color(red: 0.720, green: 0.640, blue: 0.500)
            case .workspace: Color(red: 0.894, green: 0.906, blue: 0.925)
            }
        }
    }

    static var hairline: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 0.180, green: 0.250, blue: 0.305)
            case .aurora: Color(red: 0.250, green: 0.206, blue: 0.355)
            case .board: Color(red: 0.250, green: 0.248, blue: 0.260)
            case .leafcutter: Color(red: 0.286, green: 0.224, blue: 0.132)
            case .workspace: Color(red: 0.250, green: 0.248, blue: 0.260)
            }
        } else {
            switch AppSkin.current {
            case .ocean: Color(red: 0.780, green: 0.845, blue: 0.920)
            case .aurora: Color(red: 0.825, green: 0.770, blue: 0.925)
            case .board: Color(red: 0.805, green: 0.800, blue: 0.820)
            case .leafcutter: Color(red: 0.780, green: 0.700, blue: 0.560)
            case .workspace: Color(red: 0.894, green: 0.906, blue: 0.925)
            }
        }
    }

    static var accent: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 0.220, green: 0.820, blue: 0.760)
            case .aurora: Color(red: 0.680, green: 0.560, blue: 1.000)
            case .board: Color(red: 0.860, green: 0.790, blue: 0.620)
            case .leafcutter: Color(red: 0.980, green: 0.515, blue: 0.210)
            case .workspace: Color(red: 0.860, green: 0.790, blue: 0.620)
            }
        } else {
            switch AppSkin.current {
            case .ocean: Color(red: 0.050, green: 0.520, blue: 0.490)
            case .aurora: Color(red: 0.430, green: 0.300, blue: 0.850)
            case .board: Color(red: 0.075, green: 0.070, blue: 0.080)
            case .leafcutter: Color(red: 0.705, green: 0.210, blue: 0.090)
            case .workspace: Color(red: 0.145, green: 0.388, blue: 0.922)
            }
        }
    }

    static var accentCyan: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 0.360, green: 0.860, blue: 1.000)
            case .aurora: Color(red: 1.000, green: 0.520, blue: 0.800)
            case .board: Color(red: 0.620, green: 0.520, blue: 1.000)
            case .leafcutter: Color(red: 0.540, green: 0.820, blue: 0.340)
            case .workspace: Color(red: 0.620, green: 0.520, blue: 1.000)
            }
        } else {
            switch AppSkin.current {
            case .ocean: Color(red: 0.245, green: 0.790, blue: 0.925)
            case .aurora: Color(red: 0.975, green: 0.390, blue: 0.740)
            case .board: Color(red: 0.455, green: 0.330, blue: 0.930)
            case .leafcutter: Color(red: 0.410, green: 0.720, blue: 0.230)
            case .workspace: Color(red: 0.145, green: 0.388, blue: 0.922)
            }
        }
    }

    static var accentSoft: Color {
        switch AppSkin.current {
        case .ocean: accent.opacity(isDark ? 0.18 : 0.10)
        case .aurora: accent.opacity(isDark ? 0.20 : 0.12)
        case .board: accent.opacity(isDark ? 0.18 : 0.08)
        case .leafcutter: accent.opacity(isDark ? 0.20 : 0.11)
        case .workspace: accent.opacity(isDark ? 0.18 : 0.10)
        }
    }

    static var shellStroke: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 0.180, green: 0.260, blue: 0.320).opacity(0.92)
            case .aurora: Color(red: 0.280, green: 0.220, blue: 0.420).opacity(0.90)
            case .board: Color(red: 0.320, green: 0.310, blue: 0.300).opacity(0.88)
            case .leafcutter: Color(red: 0.330, green: 0.250, blue: 0.140).opacity(0.88)
            case .workspace: Color(red: 0.320, green: 0.310, blue: 0.300).opacity(0.88)
            }
        } else {
            switch AppSkin.current {
            case .ocean, .aurora: AppTheme.adaptiveWhite(0.95)
            case .board: AppTheme.adaptiveWhite(0.82)
            case .leafcutter: AppTheme.adaptiveWhite(0.86)
            case .workspace: Color(red: 0.894, green: 0.906, blue: 0.925)
            }
        }
    }

    static var shadow: Color {
        if isDark {
            return Color.black.opacity(0.34)
        }

        switch AppSkin.current {
        case .ocean: return Color(red: 0.160, green: 0.300, blue: 0.500).opacity(0.12)
        case .aurora: return Color(red: 0.420, green: 0.300, blue: 0.620).opacity(0.12)
        case .board: return AppTheme.adaptiveBlack(0.10)
        case .leafcutter: return Color(red: 0.360, green: 0.220, blue: 0.110).opacity(0.13)
        case .workspace: return AppTheme.adaptiveBlack(0.10)
        }
    }

    static var rowShadow: Color {
        if isDark {
            return Color.black.opacity(0.28)
        }

        switch AppSkin.current {
        case .ocean: return Color(red: 0.160, green: 0.300, blue: 0.500).opacity(0.07)
        case .aurora: return Color(red: 0.420, green: 0.300, blue: 0.620).opacity(0.07)
        case .board: return AppTheme.adaptiveBlack(0.05)
        case .leafcutter: return Color(red: 0.360, green: 0.220, blue: 0.110).opacity(0.07)
        case .workspace: return AppTheme.adaptiveBlack(0.05)
        }
    }

    static var accentWarm: Color {
        if isDark {
            switch AppSkin.current {
            case .ocean: Color(red: 1.000, green: 0.540, blue: 0.210)
            case .aurora: Color(red: 1.000, green: 0.470, blue: 0.670)
            case .board: Color(red: 1.000, green: 0.630, blue: 0.360)
            case .leafcutter: Color(red: 1.000, green: 0.605, blue: 0.245)
            case .workspace: Color(red: 1.000, green: 0.630, blue: 0.360)
            }
        } else {
            switch AppSkin.current {
            case .ocean: Color(red: 0.918, green: 0.345, blue: 0.047)
            case .aurora: Color(red: 0.905, green: 0.300, blue: 0.520)
            case .board: Color(red: 0.790, green: 0.310, blue: 0.130)
            case .leafcutter: Color(red: 0.920, green: 0.395, blue: 0.085)
            case .workspace: Color(red: 0.790, green: 0.310, blue: 0.130)
            }
        }
    }

    static var success: Color {
        isDark ? Color(red: 0.360, green: 0.820, blue: 0.560) : Color(red: 0.140, green: 0.580, blue: 0.340)
    }

    static var successSoft: Color {
        isDark ? Color(red: 0.070, green: 0.190, blue: 0.120).opacity(0.96) : Color(red: 0.900, green: 0.970, blue: 0.910)
    }

    static var workspaceCanvas: Color {
        isDark ? workSurface : Color(red: 0.957, green: 0.961, blue: 0.969)
    }

    static var topBar: Color {
        if isDark {
            return Color(red: 0.064, green: 0.070, blue: 0.078)
        }
        return AppSkin.current == .workspace
            ? Color(red: 0.949, green: 0.953, blue: 0.961)
            : sidebar.opacity(0.92)
    }

    static var workspaceSidebar: Color {
        AppSkin.current == .workspace && !isDark
            ? Color(red: 0.980, green: 0.980, blue: 0.984)
            : sidebar
    }

    static var workspaceSurface: Color {
        AppSkin.current == .workspace && !isDark
            ? Color.white
            : workSurface
    }

    private static var darkOverlayBase: Color {
        switch AppSkin.current {
        case .ocean:
            Color(red: 0.160, green: 0.210, blue: 0.250)
        case .aurora:
            Color(red: 0.180, green: 0.145, blue: 0.250)
        case .board:
            Color(red: 0.210, green: 0.205, blue: 0.200)
        case .leafcutter:
            Color(red: 0.205, green: 0.155, blue: 0.090)
        case .workspace:
            Color(red: 0.210, green: 0.205, blue: 0.200)
        }
    }
}
