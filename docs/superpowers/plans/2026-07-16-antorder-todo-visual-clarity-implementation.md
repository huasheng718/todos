# 蚁序待办视觉清晰度重设计 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变待办业务行为、导航顺序和右键菜单的前提下，将蚁序待办统一为 Linear 主导、符合 macOS 原生习惯的高对比度紧凑工作台。

**Architecture:** 先在 `AppTheme` 中收敛跨皮肤的中性表面、文字和语义色，再让现有 SwiftUI 组件只消费语义令牌。任务行用一个合并状态图标表达异常或进度，侧栏、工具栏、快速记录和日历去除重复强调色、半透明表面与投影。视觉约束通过现有 `scripts/quality_checks.swift` 静态回归检查锁定，最终用真实 macOS 窗口完成多尺寸、深浅色和五皮肤验收。

**Tech Stack:** Swift 6, SwiftUI, AppKit/SF Symbols, macOS 14+, existing static quality-check harness.

## Global Constraints

- 所有代码修改必须发生在 Loop Engineering 的 `.loop/workspaces/<run-id>/...` 隔离工作区，不能直接编辑挂载仓库。
- 保留三栏宽度：`ModuleRail` 184px、`ContextSidebar` 264px、主工作区自适应。
- 保留侧栏顺序和图标：今日推进 `scope`、未完成 `circle.dashed`、等待反馈 `hourglass`、本周固定 `repeat.circle`、已完成 `checkmark.circle.fill`、全部待办 `tray.full.fill`。
- 保留任务自然语言“时间 + 标题”阅读顺序和右键菜单操作。
- 五套皮肤共享表面、文字、圆角、阴影和组件状态，只允许 `accent`/`accentSoft` 不同。
- 主文字与正文级次级文字对背景的对比度不得低于 4.5:1。
- 红色仅表示逾期、错误或阻塞；普通任务和未完成数量使用中性色。
- 普通任务行最多出现一个彩色语义图标，不使用红色背景、红色边框或连续红色竖线。
- 页面区块、任务行、侧栏导航、快速记录和日历不使用投影；阴影仅保留给菜单、浮层、模态窗口和拖拽预览。
- 不新增第三方依赖，不修改 SQLite、同步、AI 解析或任务存储逻辑。
- 字体使用 SF Pro/PingFang SC，字间距为 0。

---

## File Map

- Modify `Sources/DailyTodos/AppTheme.swift`: 提供跨皮肤一致的中性表面、文字、分隔线、语义色和强调色映射。
- Modify `Sources/DailyTodos/WorkspaceShellViews.swift`: 收敛模块导航、搜索框和分段控件的圆角、表面与状态。
- Modify `Sources/DailyTodos/TodoSidebarViews.swift`: 简化待办分类选中态和数量徽标。
- Modify `Sources/DailyTodos/TodoFlowRow.swift`: 合并优先级/进度为单一信号，建立标题、日期、备注和行分隔层级。
- Modify `Sources/DailyTodos/TodoListViews.swift`: 让看板卡片复用单一任务信号，并保持现有列表密度。
- Modify `Sources/DailyTodos/TodoCaptureViews.swift`: 将快速记录改为无阴影、单强调色的平面输入条。
- Modify `Sources/DailyTodos/SidebarSharedViews.swift`: 简化快速日期按钮。
- Modify `Sources/DailyTodos/TodoMiniCalendarViews.swift`: 合并年月导航并去除多层卡片表面。
- Modify `scripts/quality_checks.swift`: 为每个视觉约束增加失败优先的静态回归检查，并更新旧的多图标断言。

---

### Task 1: 统一主题令牌与工作台基础表面

**Files:**
- Modify: `scripts/quality_checks.swift`
- Modify: `Sources/DailyTodos/AppTheme.swift`
- Modify: `Sources/DailyTodos/WorkspaceShellViews.swift`

**Interfaces:**
- Consumes: Existing `WorkspaceThemeTokens`, `AppSkin`, `AppTheme.workspaceTokens`, `ModuleRailButton`.
- Produces: `workspaceModuleRail`, `workspaceContextSidebar`, `workspaceAltSurface`, `workspaceListRowHover`, `workspacePrimaryText`, `workspaceSecondaryText`, `workspaceMutedText`, `workspaceDanger`, `workspaceWarning`; later tasks consume them through `AppTheme.workspaceTokens`.

- [ ] **Step 1: Add the failing theme guardrail**

Add `try checkWorkspaceVisualClarityTheme()` immediately after `try checkDeadCodeGuardrails()` in `DailyTodosChecks.main()`.

Add this function before `checkTodoIssueListUsesContextMenu()`:

```swift
func checkWorkspaceVisualClarityTheme() throws {
    let themeSource = try sourceFile("Sources/DailyTodos/AppTheme.swift")
    let shellSource = try sourceFile("Sources/DailyTodos/WorkspaceShellViews.swift")

    guard let tokensStart = themeSource.range(of: "static var workspaceTokens: WorkspaceThemeTokens"),
          let tokensEnd = themeSource.range(of: "static var isDark: Bool")
    else {
        throw CheckFailure.failed("无法定位 AppTheme.workspaceTokens")
    }
    let tokensSource = String(themeSource[tokensStart.lowerBound..<tokensEnd.lowerBound])

    for requiredMapping in [
        "moduleRail: workspaceModuleRail",
        "contextSidebar: workspaceContextSidebar",
        "contentAltSurface: workspaceAltSurface",
        "listRowHover: workspaceListRowHover",
        "textPrimary: workspacePrimaryText",
        "textSecondary: workspaceSecondaryText",
        "textMuted: workspaceMutedText",
        "action: accent",
        "actionSoft: accentSoft",
        "warning: workspaceWarning",
        "danger: workspaceDanger",
        "shadow: .clear"
    ] {
        try expect(tokensSource.contains(requiredMapping), "工作台主题缺少清晰度映射：\(requiredMapping)")
    }
    try expect(
        !tokensSource.contains("moduleRail: sidebar")
            && !tokensSource.contains("contextSidebar: sidebar")
            && !tokensSource.contains("action: accentWarm"),
        "工作台结构表面与主要操作不能继续复用旧皮肤表面或第二强调色"
    )

    for requiredToken in [
        "static var workspaceModuleRail: Color",
        "static var workspaceContextSidebar: Color",
        "static var workspaceAltSurface: Color",
        "static var workspaceListRowHover: Color",
        "static var workspacePrimaryText: Color",
        "static var workspaceSecondaryText: Color",
        "static var workspaceMutedText: Color",
        "static var workspaceDanger: Color",
        "static var workspaceWarning: Color"
    ] {
        try expect(themeSource.contains(requiredToken), "AppTheme 缺少视觉令牌：\(requiredToken)")
    }

    guard let railButtonStart = shellSource.range(of: "struct ModuleRailButton"),
          let chromeMetricsStart = shellSource.range(of: "enum WorkspaceChromeMetrics")
    else {
        throw CheckFailure.failed("无法定位 ModuleRailButton")
    }
    let railButtonSource = String(shellSource[railButtonStart.lowerBound..<chromeMetricsStart.lowerBound])
    try expect(
        railButtonSource.contains("cornerRadius: 6")
            && railButtonSource.contains("AppTheme.workspaceTokens.listRowHover"),
        "模块导航应使用 6px 圆角和统一 hover 表面"
    )
}
```

- [ ] **Step 2: Run the check and verify it fails**

Run:

```bash
scripts/run_quality_checks.sh
```

Expected: FAIL with `工作台主题缺少清晰度映射：moduleRail: workspaceModuleRail`.

- [ ] **Step 3: Replace the workspace token mapping**

Replace `AppTheme.workspaceTokens` with:

```swift
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
```

Delete the existing `workspaceCanvas` and `workspaceSurface` definitions near the bottom of `AppTheme`, replace them with the definitions below, and add the remaining new workspace properties in the same block. There must be exactly one definition for each property after this edit:

```swift
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
        ? Color(red: 0.557, green: 0.592, blue: 0.647)
        : Color(red: 0.478, green: 0.518, blue: 0.573)
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
```

Make the existing compatibility properties delegate to the neutral baseline:

```swift
static var workSurface: Color { workspaceAltSurface }
static var sidebar: Color { workspaceContextSidebar }
static var sidebarSelected: Color { accentSoft }
static var ink: Color { workspacePrimaryText }
static var mutedInk: Color { workspaceMutedText }
static var secondaryText: Color { workspaceSecondaryText }
static var panel: Color { workspaceSurface }
static var row: Color { workspaceSurface }
static var border: Color { workspaceHairline }
static var hairline: Color { workspaceHairline }
static var rowShadow: Color { .clear }
static var topBar: Color { workspaceModuleRail }
static var workspaceSidebar: Color { workspaceContextSidebar }
```

Replace `rowTint(priority:isOverdue:)` with a neutral return so priority and overdue no longer tint row backgrounds:

```swift
static func rowTint(priority: TodoPriority, isOverdue: Bool) -> Color {
    workspaceSurface
}
```

Keep `accent` skin-specific, but replace its values with restrained accessible accents:

```swift
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
        case .ocean: Color(red: 0.184, green: 0.420, blue: 1.000)
        case .aurora: Color(red: 0.435, green: 0.357, blue: 0.827)
        case .board: Color(red: 0.757, green: 0.302, blue: 0.541)
        case .leafcutter: Color(red: 0.184, green: 0.490, blue: 0.361)
        case .workspace: Color(red: 0.239, green: 0.388, blue: 0.867)
        }
    }
}
```

- [ ] **Step 4: Align the module rail component**

In `ModuleRailButton`, replace the row background and `rowFill` with:

```swift
.background(rowFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
```

```swift
private var rowFill: Color {
    if isSelected {
        return AppTheme.workspaceTokens.accentSoft
    }
    if isHovered {
        return AppTheme.workspaceTokens.listRowHover
    }
    return Color.clear
}
```

- [ ] **Step 5: Run focused verification**

Run:

```bash
scripts/run_quality_checks.sh
swift build
git diff --check
```

Expected: `DailyTodosChecks passed`, successful Swift build, and no diff-check output.

- [ ] **Step 6: Commit the theme foundation**

```bash
git add Sources/DailyTodos/AppTheme.swift Sources/DailyTodos/WorkspaceShellViews.swift scripts/quality_checks.swift
git commit -m "refactor: clarify workspace visual hierarchy"
```

---

### Task 2: 收敛模块导航与待办分类状态

**Files:**
- Modify: `scripts/quality_checks.swift`
- Modify: `Sources/DailyTodos/TodoSidebarViews.swift`

**Interfaces:**
- Consumes: `AppTheme.workspaceTokens.contextSidebar`, `accent`, `accentSoft`, `textPrimary`, `textSecondary`, `danger`, `listRowHover` from Task 1.
- Produces: `DateButton.countForeground`, `DateButton.countBackground`, and a single-accent 6px selected navigation style.

- [ ] **Step 1: Add the failing sidebar guardrail**

Add `try checkTodoSidebarVisualClarity()` after `checkWorkspaceVisualClarityTheme()` in `DailyTodosChecks.main()`.

Add:

```swift
func checkTodoSidebarVisualClarity() throws {
    let source = try sourceFile("Sources/DailyTodos/TodoSidebarViews.swift")
    guard let buttonStart = source.range(of: "struct DateButton"),
          let metricsStart = source.range(of: "struct TodoSidebarMetrics")
    else {
        throw CheckFailure.failed("无法定位 DateButton")
    }
    let buttonSource = String(source[buttonStart.lowerBound..<metricsStart.lowerBound])

    try expect(
        source.contains(".background(AppTheme.workspaceTokens.contextSidebar)"),
        "待办上下文侧栏应使用独立 contextSidebar 表面"
    )
    try expect(
        !buttonSource.contains("AppTheme.accentWarm")
            && !buttonSource.contains("cornerRadius: 12")
            && !buttonSource.contains("RoundedRectangle(cornerRadius: 2"),
        "待办分类不能保留橙色竖线或 12px 卡片式选中态"
    )
    try expect(
        buttonSource.contains("cornerRadius: 6")
            && buttonSource.contains("private var countForeground: Color")
            && buttonSource.contains("private var countBackground: Color")
            && buttonSource.contains("AppTheme.workspaceTokens.listRowHover"),
        "待办分类应使用统一圆角、hover 表面和数量颜色规则"
    )
}
```

- [ ] **Step 2: Run the check and verify it fails**

Run `scripts/run_quality_checks.sh`.

Expected: FAIL with `待办上下文侧栏应使用独立 contextSidebar 表面`.

- [ ] **Step 3: Update the sidebar surface**

In `TodoSidebarView`, replace:

```swift
.background(AppTheme.sidebar)
.foregroundStyle(AppTheme.ink)
```

with:

```swift
.background(AppTheme.workspaceTokens.contextSidebar)
.foregroundStyle(AppTheme.workspaceTokens.textPrimary)
```

- [ ] **Step 4: Replace DateButton with a single-accent treatment**

Remove the leading `RoundedRectangle` rail from the button `HStack`. Keep the icon, text, spacer, and count. Replace the icon/text/count styling and row modifiers with:

```swift
Image(systemName: systemImage)
    .symbolRenderingMode(.hierarchical)
    .font(.system(size: 14, weight: .semibold))
    .foregroundStyle(isSelected ? AppTheme.workspaceTokens.accent : AppTheme.workspaceTokens.textSecondary)
    .frame(width: 20, height: 20)

VStack(alignment: .leading, spacing: 1) {
    Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(isSelected ? AppTheme.workspaceTokens.accent : AppTheme.workspaceTokens.textPrimary)
        .lineLimit(1)
    Text(subtitle)
        .font(.system(size: 11, weight: .regular))
        .foregroundStyle(AppTheme.workspaceTokens.textSecondary)
        .lineLimit(1)
}

Spacer()

if count > 0 || alertCount > 0 {
    Text(countText)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(countForeground)
        .frame(minWidth: 24, minHeight: 20)
        .background(countBackground, in: Capsule())
        .help(countHelp)
}
```

Use these row modifiers:

```swift
.padding(.horizontal, 9)
.frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
.contentShape(Rectangle())
.background(navBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
```

Replace the private color properties with:

```swift
private var navBackground: Color {
    if isSelected {
        return AppTheme.workspaceTokens.accentSoft
    }
    if isHovered {
        return AppTheme.workspaceTokens.listRowHover
    }
    return Color.clear
}

private var countForeground: Color {
    if isSelected {
        return AppTheme.workspaceTokens.accent
    }
    return alertCount > 0
        ? AppTheme.workspaceTokens.danger
        : AppTheme.workspaceTokens.textSecondary
}

private var countBackground: Color {
    if isSelected {
        return AppTheme.workspaceTokens.accent.opacity(0.10)
    }
    return countForeground.opacity(0.10)
}
```

Keep `countText` and `countHelp` unchanged so an alert count still describes overdue work without introducing a second selected-state color.

- [ ] **Step 5: Run focused verification**

Run:

```bash
scripts/run_quality_checks.sh
swift build
git diff --check
```

Expected: all commands pass.

- [ ] **Step 6: Commit the sidebar refinement**

```bash
git add Sources/DailyTodos/TodoSidebarViews.swift scripts/quality_checks.swift
git commit -m "refactor: simplify todo sidebar states"
```

---

### Task 3: 将任务行收敛为单一状态信号

**Files:**
- Modify: `scripts/quality_checks.swift`
- Modify: `Sources/DailyTodos/TodoFlowRow.swift`
- Modify: `Sources/DailyTodos/TodoListViews.swift`

**Interfaces:**
- Consumes: `TodoItem.progress`, `TodoItem.priority`, `TodoIssueStatusMarker`, `AppTheme.workspaceTokens`.
- Produces: `TodoIssueSignalIcon(todo: TodoItem)`, reused by compact/grouped rows and board cards.

- [ ] **Step 1: Change the existing checks to require one signal**

In `checkTodoIssueListUsesContextMenu()`, replace the first expectation with:

```swift
try expect(
    rowSource.contains("TodoIssueStatusMarker")
        && rowSource.contains("TodoIssueSignalIcon(todo: todo)")
        && rowSource.contains("TodoContextMenuContent(")
        && rowSource.contains(".contextMenu"),
    "待办行应使用完成框与单一 issue 信号，并通过右键菜单承载操作"
)
```

In `checkTodoDenseNaturalListPresentation()`, replace the two-icon expectation with:

```swift
try expect(
    rowSource.contains("TodoIssueSignalIcon(todo: todo)")
        && listSource.contains("TodoIssueSignalIcon(todo: todo)"),
    "紧凑、分组和看板待办应复用单一状态信号"
)
try expect(
    !rowSource.contains("TodoIssuePriorityIcon")
        && !rowSource.contains("TodoIssueProgressIcon")
        && !listSource.contains("TodoIssuePriorityIcon")
        && !listSource.contains("TodoIssueProgressIcon"),
    "普通待办不能同时展示优先级和进度两个彩色 icon"
)
try expect(
    !rowSource.contains("issueRailColor")
        && !rowSource.contains("sideRailOpacity")
        && rowSource.contains("AppTheme.workspaceTokens.danger")
        && rowSource.contains("AppTheme.workspaceTokens.textSecondary"),
    "任务行应取消状态竖线，并用语义色区分逾期日期与普通日期"
)
try expect(
    rowSource.contains(".font(.system(size: 14, weight: todo.isDone ? .regular : .semibold))")
        && rowSource.contains(".font(.system(size: 12, weight: .regular))")
        && rowSource.contains(".lineLimit(2)"),
    "任务标题和备注应使用 14/12 的清晰文字层级"
)
```

Remove the old expectation that requires `TodoIssuePriorityIcon` and `TodoIssueProgressIcon`. Keep the navigation-order, natural-language, row-density, and no-overdue-background checks.

- [ ] **Step 2: Run the check and verify it fails**

Run `scripts/run_quality_checks.sh`.

Expected: FAIL with `待办行应使用完成框与单一 issue 信号，并通过右键菜单承载操作`.

- [ ] **Step 3: Add TodoIssueSignalIcon**

Delete `TodoIssuePriorityIcon` and `TodoIssueProgressIcon`. Add this component after `TodoIssueStatusMarker`:

```swift
struct TodoIssueSignalIcon: View {
    let todo: TodoItem

    var body: some View {
        Group {
            if let signal {
                Image(systemName: signal.systemName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(signal.color)
                    .help(signal.label)
                    .accessibilityLabel(signal.label)
            } else {
                Color.clear
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 16, height: 20)
        .contentShape(Rectangle())
    }

    private var signal: (systemName: String, color: Color, label: String)? {
        if isOverdue {
            return ("exclamationmark.circle.fill", AppTheme.workspaceTokens.danger, "已逾期")
        }
        if todo.priority == .high {
            return ("flag.fill", AppTheme.workspaceTokens.danger, "高优先级")
        }
        switch todo.progress {
        case .pending:
            return nil
        case .inProgress:
            return ("bolt", AppTheme.workspaceTokens.textSecondary, "推进中")
        case .waiting:
            return ("hourglass", AppTheme.workspaceTokens.textSecondary, "等待他人")
        case .done:
            return ("checkmark.circle", AppTheme.workspaceTokens.success, "已完成")
        }
    }

    private var isOverdue: Bool {
        let calendar = Calendar.current
        return todo.progress != .done
            && todo.progress != .waiting
            && calendar.startOfDay(for: todo.date) < calendar.startOfDay(for: Date())
    }
}
```

- [ ] **Step 4: Rewrite the non-editing TodoFlowRow layout**

Replace the two icon calls with:

```swift
TodoIssueSignalIcon(todo: todo)
    .padding(.top, hasNotes ? 2 : 0)
```

Use these text styles:

```swift
Text(naturalFollowUpText)
    .font(.system(size: 12, weight: .medium))
    .monospacedDigit()
    .foregroundStyle(dateColor)
    .lineLimit(1)
    .fixedSize()

Text(titleText)
    .font(.system(size: 14, weight: todo.isDone ? .regular : .semibold))
    .foregroundStyle(todo.isDone ? AppTheme.workspaceTokens.textSecondary : AppTheme.workspaceTokens.textPrimary)
    .strikethrough(todo.isDone, color: AppTheme.workspaceTokens.textSecondary)
    .lineLimit(1)
    .fixedSize(horizontal: false, vertical: true)
    .frame(maxWidth: .infinity, alignment: .leading)
```

Use this notes block:

```swift
if hasNotes {
    Text(todo.trimmedNotes)
        .font(.system(size: 12, weight: .regular))
        .foregroundStyle(AppTheme.workspaceTokens.textSecondary)
        .strikethrough(todo.isDone, color: AppTheme.workspaceTokens.textSecondary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
}
```

Replace the rounded card background, border, rail and rounded content shape with:

```swift
.padding(.horizontal, 10)
.frame(maxWidth: .infinity, minHeight: hasNotes ? 54 : 40, alignment: .leading)
.background(rowBackground)
.overlay(alignment: .bottom) {
    Rectangle()
        .fill(AppTheme.workspaceTokens.hairline.opacity(0.72))
        .frame(height: 1)
}
.opacity(rowOpacity)
.contentShape(Rectangle())
```

Replace `dateColor` and `rowBackground` with:

```swift
private var dateColor: Color {
    isOverdue
        ? AppTheme.workspaceTokens.danger
        : AppTheme.workspaceTokens.textSecondary
}

private var rowBackground: Color {
    if isHighlighted {
        return AppTheme.workspaceTokens.listRowSelected
    }
    if isHovered {
        return AppTheme.workspaceTokens.listRowHover
    }
    return Color.clear
}
```

Delete `rowStroke`, `issueRailColor`, and `sideRailOpacity`. Keep `rowOpacity`, context menu behavior, animations, and editing branches.

- [ ] **Step 5: Reuse the signal in board cards**

In `TodoBoardCard`, replace adjacent `TodoIssuePriorityIcon` and `TodoIssueProgressIcon` calls with:

```swift
TodoIssueSignalIcon(todo: todo)
```

Keep `TodoIssueStatusMarker`, title, notes, context menu, and board drag behavior unchanged.

- [ ] **Step 6: Run focused verification**

Run:

```bash
scripts/run_quality_checks.sh
swift build
git diff --check
```

Expected: all commands pass, including the existing navigation-order and context-menu checks.

- [ ] **Step 7: Commit the task-row refinement**

```bash
git add Sources/DailyTodos/TodoFlowRow.swift Sources/DailyTodos/TodoListViews.swift scripts/quality_checks.swift
git commit -m "refactor: simplify todo row status signals"
```

---

### Task 4: 平面化搜索、视图切换和快速记录

**Files:**
- Modify: `scripts/quality_checks.swift`
- Modify: `Sources/DailyTodos/WorkspaceShellViews.swift`
- Modify: `Sources/DailyTodos/TodoCaptureViews.swift`

**Interfaces:**
- Consumes: shared workspace tokens from Task 1, existing `WorkspaceSearchField`, `WorkspaceSegmentedControl`, `QuickCaptureBar` bindings and callbacks.
- Produces: shared 32px search/segmented controls and an 8px, single-accent, shadow-free quick capture surface.

- [ ] **Step 1: Add the failing controls guardrail**

Add `try checkTodoControlsVisualClarity()` after `checkTodoDenseNaturalListPresentation()` in `DailyTodosChecks.main()`.

Add:

```swift
func checkTodoControlsVisualClarity() throws {
    let shellSource = try sourceFile("Sources/DailyTodos/WorkspaceShellViews.swift")
    let captureSource = try sourceFile("Sources/DailyTodos/TodoCaptureViews.swift")

    guard let searchStart = shellSource.range(of: "struct WorkspaceSearchField"),
          let rowSurfaceStart = shellSource.range(of: "struct WorkspaceListRowSurface")
    else {
        throw CheckFailure.failed("无法定位工作台搜索和分段控件")
    }
    let controlsSource = String(shellSource[searchStart.lowerBound..<rowSurfaceStart.lowerBound])

    try expect(
        controlsSource.contains("AppTheme.workspaceTokens.contentSurface")
            && controlsSource.contains("lineWidth: focusBinding.wrappedValue ? 1.5 : 1")
            && controlsSource.contains("AppTheme.workspaceTokens.accentSoft")
            && controlsSource.contains("AppTheme.workspaceTokens.accent"),
        "搜索与分段控件应使用明确表面、1.5px 焦点环和轻量选中态"
    )
    try expect(
        !controlsSource.contains("selection == option ? .white")
            && !controlsSource.contains(".fill(AppTheme.workspaceTokens.accent)"),
        "分段控件不应继续使用整块强调色填充"
    )

    guard let captureStart = captureSource.range(of: "struct QuickCaptureBar"),
          let previewStart = captureSource.range(of: "struct QuickCapturePreview")
    else {
        throw CheckFailure.failed("无法定位 QuickCaptureBar")
    }
    let captureBarSource = String(captureSource[captureStart.lowerBound..<previewStart.lowerBound])
    try expect(
        !captureBarSource.contains("LinearGradient")
            && !captureBarSource.contains("AppTheme.accentWarm")
            && !captureBarSource.contains(".shadow(")
            && !captureBarSource.contains("cornerRadius: 16"),
        "快速记录应去除渐变、第二强调色、投影和 16px 卡片圆角"
    )
    try expect(
        captureBarSource.contains("cornerRadius: 8")
            && captureBarSource.contains("lineWidth: isFocused ? 1.5 : 1")
            && captureBarSource.contains("AppTheme.workspaceTokens.contentSurface"),
        "快速记录应使用 8px 平面表面和明确焦点边框"
    )
}
```

- [ ] **Step 2: Run the check and verify it fails**

Run `scripts/run_quality_checks.sh`.

Expected: FAIL with `搜索与分段控件应使用明确表面、1.5px 焦点环和轻量选中态`.

- [ ] **Step 3: Update WorkspaceSearchField**

Replace its final surface modifiers with:

```swift
.padding(.horizontal, 10)
.frame(height: 32)
.background(
    AppTheme.workspaceTokens.contentSurface,
    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
)
.overlay(
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(
            focusBinding.wrappedValue
                ? AppTheme.workspaceTokens.focusRing
                : AppTheme.workspaceTokens.hairline,
            lineWidth: focusBinding.wrappedValue ? 1.5 : 1
        )
)
.onHover { isHovered = $0 }
```

Use `isHovered` only to tint the magnifying-glass icon from `textMuted` to `textSecondary`; do not change the field background opacity.

- [ ] **Step 4: Update WorkspaceSegmentedControl**

Use this option label styling:

```swift
.foregroundStyle(
    selection == option
        ? AppTheme.workspaceTokens.accent
        : AppTheme.workspaceTokens.textSecondary
)
.frame(height: 28)
.frame(maxWidth: .infinity)
.background(selectionBackground(for: option))
.contentShape(Rectangle())
```

Use this container and selected background:

```swift
.padding(2)
.background(
    AppTheme.workspaceTokens.contentAltSurface,
    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
)
.overlay(
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(AppTheme.workspaceTokens.hairline)
)
```

```swift
@ViewBuilder
private func selectionBackground(for option: Option) -> some View {
    if selection == option {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(AppTheme.workspaceTokens.accentSoft)
            .matchedGeometryEffect(id: "workspaceSegmentedSelection", in: selectionNamespace)
    }
}
```

- [ ] **Step 5: Flatten QuickCaptureBar**

Replace the command icon background with:

```swift
RoundedRectangle(cornerRadius: 6, style: .continuous)
    .fill(AppTheme.workspaceTokens.accentSoft)
    .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(AppTheme.workspaceTokens.accent.opacity(0.18))
    )
```

Keep the command symbol and 28x28 frame. Remove the gradient and `scaleEffect`.

Replace the record-button visual modifiers with:

```swift
.foregroundStyle(
    canCreate && !isCreating
        ? Color.white
        : AppTheme.workspaceTokens.textSecondary
)
.background(
    canCreate && !isCreating
        ? AppTheme.workspaceTokens.accent
        : AppTheme.workspaceTokens.contentAltSurface,
    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
)
.overlay(
    RoundedRectangle(cornerRadius: 6, style: .continuous)
        .stroke(
            canCreate && !isCreating
                ? AppTheme.workspaceTokens.accent
                : AppTheme.workspaceTokens.hairline
        )
)
.interactionHitArea()
```

Remove the button shadow and scale effect.

Replace the outer quick-capture surface with:

```swift
.padding(.horizontal, 12)
.padding(.vertical, 7)
.background(
    AppTheme.workspaceTokens.contentSurface,
    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
)
.overlay(
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(captureStrokeColor, lineWidth: isFocused ? 1.5 : 1)
)
```

Delete the leading colored rail and the outer `.shadow`. Replace `captureStrokeColor` with:

```swift
private var captureStrokeColor: Color {
    if isFocused {
        return AppTheme.workspaceTokens.focusRing
    }
    if isExpanded || isHovered {
        return AppTheme.workspaceTokens.textMuted
    }
    return AppTheme.workspaceTokens.hairline
}
```

Replace remaining successful `AppTheme.accentWarm` uses inside `QuickCaptureBar` and `QuickCapturePreview` with `AppTheme.workspaceTokens.accent`; keep failure messages on `workspaceTokens.danger`.

- [ ] **Step 6: Run focused verification**

Run:

```bash
scripts/run_quality_checks.sh
swift build
git diff --check
```

Expected: all commands pass.

- [ ] **Step 7: Commit the controls refinement**

```bash
git add Sources/DailyTodos/WorkspaceShellViews.swift Sources/DailyTodos/TodoCaptureViews.swift scripts/quality_checks.swift
git commit -m "refactor: flatten todo workspace controls"
```

---

### Task 5: 简化快速日期与小日历

**Files:**
- Modify: `scripts/quality_checks.swift`
- Modify: `Sources/DailyTodos/SidebarSharedViews.swift`
- Modify: `Sources/DailyTodos/TodoMiniCalendarViews.swift`

**Interfaces:**
- Consumes: existing `QuickDateStrip`, `TodoMiniCalendar`, `MiniCalendarDayCell`, and Task 1 tokens.
- Produces: `calendarNavigation` as the sole year/month control and flat date-cell states.

- [ ] **Step 1: Add the failing calendar guardrail**

Add `try checkTodoCalendarVisualClarity()` after `checkTodoControlsVisualClarity()` in `DailyTodosChecks.main()`.

Add:

```swift
func checkTodoCalendarVisualClarity() throws {
    let quickDateSource = try sourceFile("Sources/DailyTodos/SidebarSharedViews.swift")
    let calendarSource = try sourceFile("Sources/DailyTodos/TodoMiniCalendarViews.swift")

    try expect(
        quickDateSource.contains("AppTheme.workspaceTokens.accentSoft")
            && quickDateSource.contains("AppTheme.workspaceTokens.listRowHover")
            && !quickDateSource.contains("AppTheme.adaptiveWhite(0.74)")
            && !quickDateSource.contains("cornerRadius: 10"),
        "快速日期应使用轻量选中/hover 状态，不能保留独立白色卡片"
    )
    try expect(
        calendarSource.contains("private var calendarNavigation: some View")
            && !calendarSource.contains("private var yearStepper")
            && !calendarSource.contains("private var monthStepper")
            && !calendarSource.contains("AppTheme.accentWarm"),
        "小日历应合并年月导航并移除第二强调色"
    )
    guard let bodyStart = calendarSource.range(of: "var body: some View"),
          let navigationStart = calendarSource.range(of: "private var calendarNavigation: some View")
    else {
        throw CheckFailure.failed("无法定位 TodoMiniCalendar.body/calendarNavigation")
    }
    let calendarBodySource = String(calendarSource[bodyStart.lowerBound..<navigationStart.lowerBound])
    try expect(
        !calendarBodySource.contains("AppTheme.adaptiveWhite")
            && !calendarBodySource.contains("cornerRadius: 13"),
        "月历主体不能继续使用半透明卡片容器"
    )
}
```

- [ ] **Step 2: Run the check and verify it fails**

Run `scripts/run_quality_checks.sh`.

Expected: FAIL with `快速日期应使用轻量选中/hover 状态，不能保留独立白色卡片`.

- [ ] **Step 3: Flatten QuickDateCell**

Add `@State private var isHovered = false` to `QuickDateCell`. Replace its foreground/background/overlay with:

```swift
.foregroundStyle(isSelected ? AppTheme.workspaceTokens.accent : AppTheme.workspaceTokens.textPrimary)
.frame(maxWidth: .infinity, minHeight: 46)
.background(background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
.onHover { isHovered = $0 }
```

Add:

```swift
private var background: Color {
    if isSelected {
        return AppTheme.workspaceTokens.accentSoft
    }
    if isHovered {
        return AppTheme.workspaceTokens.listRowHover
    }
    return Color.clear
}
```

Change the event dot to:

```swift
Circle()
    .fill(count > 0 ? AppTheme.workspaceTokens.accent : Color.clear)
    .frame(width: 4, height: 4)
```

- [ ] **Step 4: Merge the calendar navigation**

Replace `yearStepper` and `monthStepper` in `TodoMiniCalendar.body` with `calendarNavigation`. Remove the rounded card background and overlay from the `LazyVGrid`.

Add:

```swift
private var calendarNavigation: some View {
    HStack(spacing: 4) {
        calendarStepButton(systemImage: "chevron.left", help: "上个月") {
            shiftMonth(-1)
        }

        Menu {
            Section("月份") {
                ForEach(monthOptions, id: \.self) { month in
                    Button {
                        setMonth(month)
                    } label: {
                        HStack {
                            Text(monthName(for: month))
                            if month == currentMonth {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section("年份") {
                ForEach(yearOptions, id: \.self) { year in
                    Button {
                        setYear(year)
                    } label: {
                        HStack {
                            Text("\(year) 年")
                            if year == currentYear {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            dropdownLabel(
                title: "\(yearTitle) \(monthTitle)",
                font: .system(size: 12, weight: .semibold)
            )
            .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.plain)
        .help("选择年月")

        calendarStepButton(systemImage: "chevron.right", help: "下个月") {
            shiftMonth(1)
        }
    }
    .foregroundStyle(AppTheme.workspaceTokens.textSecondary)
}
```

Use this body structure:

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 7) {
        HStack(spacing: 8) {
            SidebarSectionLabel("有记录")
            Spacer()
        }

        calendarNavigation

        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.workspaceTokens.textSecondary)
                    .frame(maxWidth: .infinity)
            }

            ForEach(calendarDays) { day in
                if let date = day.date {
                    MiniCalendarDayCell(
                        date: date,
                        isInCurrentMonth: day.isInCurrentMonth,
                        isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                        isToday: calendar.isDateInToday(date),
                        totalCount: todoCount(date),
                        pendingCount: pendingCount(date),
                        action: { onSelect(date) }
                    )
                } else {
                    Color.clear.frame(height: 30)
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 5: Simplify MiniCalendarDayCell states**

Replace marker colors and selected styling with:

```swift
private var markerColor: Color {
    pendingCount > 0
        ? AppTheme.workspaceTokens.accent
        : AppTheme.workspaceTokens.success
}
```

Use `markerColor` for the first event dot and `workspaceTokens.success` for a second completed-state dot. Do not use `accentWarm` or translucent adaptive white.

Replace its color helpers with:

```swift
private var foreground: Color {
    if isSelected { return AppTheme.workspaceTokens.accent }
    if !isInCurrentMonth { return AppTheme.workspaceTokens.textMuted }
    if isToday { return AppTheme.workspaceTokens.accent }
    return AppTheme.workspaceTokens.textPrimary
}

private var background: Color {
    if isSelected { return AppTheme.workspaceTokens.accentSoft }
    if isToday { return AppTheme.workspaceTokens.listRowHover }
    return Color.clear
}

private var stroke: Color {
    if isSelected { return AppTheme.workspaceTokens.accent.opacity(0.32) }
    if isToday { return AppTheme.workspaceTokens.hairline }
    return Color.clear
}
```

Change day-cell rounded rectangles from 8px to 6px.

- [ ] **Step 6: Run focused verification**

Run:

```bash
scripts/run_quality_checks.sh
swift build
git diff --check
```

Expected: all commands pass.

- [ ] **Step 7: Commit the calendar refinement**

```bash
git add Sources/DailyTodos/SidebarSharedViews.swift Sources/DailyTodos/TodoMiniCalendarViews.swift scripts/quality_checks.swift
git commit -m "refactor: simplify todo date navigation"
```

---

### Task 6: 执行跨主题视觉验收与完整回归

**Files:**
- Verify only: all files changed in Tasks 1-5.
- Evidence: `/tmp/AntOrderVisualQA/` screenshots, not committed.

**Interfaces:**
- Consumes: completed implementation from Tasks 1-5.
- Produces: verified light/dark, five-skin, multi-size evidence and a clean branch ready for review.

- [ ] **Step 1: Run the complete DailyTodos checks**

From the DailyTodos workspace run:

```bash
scripts/run_quality_checks.sh
swift build
git diff --check
```

Expected: `DailyTodosChecks passed`, successful build, no diff-check output.

- [ ] **Step 2: Run Loop Engineering control-plane checks**

From `/Users/wusheng/Documents/cuke-think/loop-engineering` run:

```bash
swift build
swift run loop-selftest
swift run loopctl doctor
```

Expected: all three commands exit 0; `loop-selftest` reports success and `loopctl doctor` reports no blocking issue.

- [ ] **Step 3: Launch the real app**

From the DailyTodos workspace run:

```bash
swift run DailyTodos
```

Expected: the app opens without a launch crash and displays the existing local task data.

- [ ] **Step 4: Capture deterministic window sizes**

Create a temporary evidence directory:

```bash
mkdir -p /tmp/AntOrderVisualQA
```

For each target size, use System Events to set the front window and capture the same region:

```bash
osascript -e 'tell application "System Events" to tell process "DailyTodos" to set position of front window to {40, 40}' -e 'tell application "System Events" to tell process "DailyTodos" to set size of front window to {1280, 800}'
screencapture -x -R40,40,1280,800 /tmp/AntOrderVisualQA/light-workspace-1280x800.png

osascript -e 'tell application "System Events" to tell process "DailyTodos" to set size of front window to {1440, 900}'
screencapture -x -R40,40,1440,900 /tmp/AntOrderVisualQA/light-workspace-1440x900.png

osascript -e 'tell application "System Events" to tell process "DailyTodos" to set size of front window to {1920, 1080}'
screencapture -x -R40,40,1920,1080 /tmp/AntOrderVisualQA/light-workspace-1920x1080.png
```

Expected: every image is nonblank, contains all three columns, and has no clipped toolbar or overlapping text.

- [ ] **Step 5: Inspect component states**

In the running app, verify and capture at least one screenshot for each state:

1. Sidebar unselected, hovered, and selected.
2. Normal, overdue, high-priority, waiting, completed, and note-bearing task rows.
3. Search default and focused.
4. Quick capture empty, focused, valid, expanded, and disabled while creating.
5. Quick date and calendar default, today, hovered, and selected.
6. Right-click menu with status, priority, follow-up date, edit, duplicate-title, and delete actions present.

Expected: no component mixes multiple accent families; red is limited to overdue/error; hover and focus do not move layout.

- [ ] **Step 6: Verify skins and appearance modes**

Switch through `ocean`, `aurora`, `board`, `leafcutter`, and `workspace` in light mode, then repeat in dark mode. Capture one 1440x900 screenshot per skin/mode under `/tmp/AntOrderVisualQA/`.

Expected:

- Only accent color changes between skins.
- Surface hierarchy, text levels, corner radii, spacing and semantic colors stay stable.
- Primary and secondary text remain readable.
- No theme restores tinted row backgrounds, card shadows or warm secondary action colors.

- [ ] **Step 7: Review the final diff**

Run:

```bash
git status --short --branch
git diff --stat origin/main...HEAD
git diff origin/main...HEAD -- Sources/DailyTodos scripts/quality_checks.swift
```

Expected: only the design/plan documents, previously approved sidebar icon/order change, scoped visual source files, and quality checks are present. No storage, sync, AI, credential, or release metadata changes appear.

- [ ] **Step 8: Record final verification without an empty commit**

Do not create a verification-only commit. Confirm that every implementation task already has its own commit and that `git status --short` is empty.

---

## Execution Notes

- Keep the existing branch `codex/daily-todos-sidebar-nav-order-icons`; it already contains the approved sidebar order/icon commit and the visual design document.
- Do not package or publish during this plan. Packaging, version bump, changelog, artifact signing, push and release require a separate shipping step after visual acceptance.
- If a static source check fails because a refactor preserves the requirement with different syntax, update the check to assert the semantic boundary using a narrowly sliced source range; do not weaken or delete the requirement.
- If a visual check reveals a mismatch, return to the owning task, add a failing static check when the behavior can be represented reliably, apply the smallest correction, rerun the task checks, and amend only that task's implementation before final review.

## Plan Self-Review

- Every design section maps to a task: surfaces/theme (Task 1), sidebar (Task 2), task rows (Task 3), toolbar/capture (Task 4), dates/calendar (Task 5), multi-theme/accessibility verification (Task 6).
- Existing checks that require two task icons are explicitly updated before implementation.
- Existing right-click menu, natural-language date/title order, list spacing and navigation-order checks remain active.
- All introduced identifiers are defined before later tasks consume them.
- No task changes persistence, synchronization, AI parsing or release metadata.
- No unresolved placeholders remain in this plan.
