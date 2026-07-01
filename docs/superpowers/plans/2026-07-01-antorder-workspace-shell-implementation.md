# AntOrder Workspace Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved full-app AntOrder workspace shell so todos, handbook, credentials, settings, and account/billing boundaries share one global top bar, module rail, context sidebar, main content structure, and a new restrained workspace skin.

**Architecture:** Add a reusable SwiftUI shell layer above the existing modules, then migrate each module into the shell by separating context navigation from module content. Keep store, parser, SQLite, autosave, update download, and credential security logic unchanged. Settings becomes a first-class module while the existing settings sheet can remain as a compatibility wrapper until the shell path is stable.

**Tech Stack:** Swift Package Manager, SwiftUI, AppKit only where already used for logo, pasteboard, and macOS-specific integrations.

## Global Constraints

- 全应用统一为“蚁序工作台”结构，让待办、手记、凭证、设置共享一致的信息架构。
- 新增一套克制、商业化、适合长时间阅读和办公使用的浅色主题。
- 保持现有业务数据、存储、同步准备和核心交互不变，降低改造风险。
- 为账户、Billing、团队空间、全局搜索、跨端导航预留稳定入口。
- 减少页面层级混乱、重复入口和内容区域不满的问题。
- 不重构 SQLite、本地仓储、同步 schema。
- 不实现真实账户、Billing、团队协作或远端同步。
- 不改待办解析、手记 autosave、凭证复制等业务逻辑。
- 不新增复杂动画或大规模组件重写。
- 不把截图中的项目管理字段直接搬进蚁序。
- GlobalTopBar 高度建议 52。
- ModuleRail 宽度建议 68 到 76，第一阶段可沿用现有 `primarySidebarWidth`。
- ContextSidebar 展开宽度建议 264，折叠宽度建议 48。
- 主内容背景为白色或接近白色，不再嵌套多层卡片。
- 顶栏只放全局动作，模块动作只放模块 header/toolbar。
- 键盘焦点不能因为 autosave、搜索 debounce 或模块重绘丢失。
- 加载状态应局部出现，不阻塞整个 shell。
- 所有文本对比度至少满足长时间阅读需求，主要正文不使用过浅灰色。

---

## File Structure

Create these focused files:

- `Sources/DailyTodos/WorkspaceShellViews.swift`
  - Owns `WorkspaceShell`, `GlobalTopBar`, `ModuleRail`, `WorkspaceContentContainer`, `ContentHeader`, `ContentToolbar`, and small shell-only view helpers.
- `Sources/DailyTodos/AccountViews.swift`
  - Owns the Account/Billing placeholder module content.

Modify these files:

- `Sources/DailyTodos/AppTheme.swift`
  - Adds the `workspace` skin and shell-oriented theme tokens without changing existing skins.
- `Sources/DailyTodos/AppModule.swift`
  - Keeps the protocol stable; registry must register settings and account modules.
- `Sources/DailyTodos/AppModules.swift`
  - Adds `SettingsAppModule` and `AccountAppModule`.
- `Sources/DailyTodos/ContentView.swift`
  - Becomes the shell assembler. It should choose active module sidebar/content and pass global actions to `WorkspaceShell`.
- `Sources/DailyTodos/ModuleNavigationViews.swift`
  - Splits todo and handbook module views into context sidebar and workspace content slots.
- `Sources/DailyTodos/CredentialViews.swift`
  - Splits credentials module into context sidebar and workspace content slots while preserving vault behavior.
- `Sources/DailyTodos/SettingsViews.swift`
  - Extracts sheet internals into reusable workspace views and adds `SettingsModuleView`.
- `Sources/DailyTodos/AppShellViews.swift`
  - Keeps existing shared controls such as `SkinPickerButton`, `AppLogoImage`, and button styles; moves or deprecates shell-specific duplicates after new shell compiles.

Do not modify these files unless a compile error proves a direct dependency needs a signature update:

- `Sources/DailyTodos/TodoStore.swift`
- `Sources/DailyTodos/HandbookWorkspaceViewModel.swift`
- `Sources/DailyTodos/HandbookRepository.swift`
- `Sources/DailyTodos/CredentialStore.swift`
- `Sources/DailyTodos/TodoQuickInputParser.swift`

## Verification Commands

Run after each implementation task unless the task explicitly says a narrower command is enough:

```bash
swift build
swiftc -parse-as-library Sources/DailyTodos/TodoItem.swift Sources/DailyTodos/HandbookItem.swift Sources/DailyTodos/TodoQuickInputParser.swift Sources/DailyTodos/AppStateModels.swift Sources/DailyTodos/ViewDerivedModels.swift Sources/DailyTodos/HandbookRepository.swift Sources/DailyTodos/HandbookWorkspaceViewModel.swift Sources/DailyTodos/PerformanceMonitor.swift Sources/DailyTodos/TodoStore.swift Sources/DailyTodos/AppUpdateAvailability.swift Sources/DailyTodos/AppUpdateDownloadProgress.swift scripts/quality_checks.swift -o /tmp/DailyTodosChecks
/tmp/DailyTodosChecks
python3 scripts/release_version_guard.py --self-test
git diff --check
```

Expected final result:

- `swift build` exits 0.
- `/tmp/DailyTodosChecks` prints `DailyTodosChecks passed`.
- `release_version_guard.py --self-test` exits 0.
- `git diff --check` exits 0.

---

### Task 1: Add Workspace Skin And Shell Tokens

**Files:**
- Modify: `Sources/DailyTodos/AppTheme.swift`

**Interfaces:**
- Consumes: Existing `AppSkin`, `AppTheme`, and `activeAppSkin`.
- Produces:
  - `AppSkin.workspace`
  - `AppTheme.topBar`
  - `AppTheme.workspaceCanvas`
  - `AppTheme.workspaceSidebar`
  - `AppTheme.workspaceSurface`
  - Existing theme properties continue compiling for all `AppSkin` cases.

- [ ] **Step 1: Update `AppSkin` cases and labels**

Add the new case and labels exactly as follows:

```swift
enum AppSkin: String, CaseIterable, Identifiable {
    case ocean
    case aurora
    case board
    case leafcutter
    case workspace

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
}
```

- [ ] **Step 2: Add `workspace` branches to every `switch AppSkin.current` in `AppTheme.swift`**

Use these values for the new light skin:

```swift
case .workspace: Color(red: 0.957, green: 0.961, blue: 0.969) // canvas #F4F5F7
case .workspace: Color(red: 0.933, green: 0.941, blue: 0.953) // rail #EEF0F3
case .workspace: Color(red: 0.980, green: 0.980, blue: 0.984) // sidebar #FAFAFB
case .workspace: Color.white                                  // surface #FFFFFF
case .workspace: Color(red: 0.141, green: 0.153, blue: 0.180) // ink #24272E
case .workspace: Color(red: 0.420, green: 0.447, blue: 0.502) // secondary #6B7280
case .workspace: Color(red: 0.541, green: 0.565, blue: 0.600) // muted #8A9099
case .workspace: Color(red: 0.145, green: 0.388, blue: 0.922) // accent #2563EB
case .workspace: Color(red: 0.918, green: 0.945, blue: 1.000) // accentSoft #EAF1FF
case .workspace: Color(red: 0.894, green: 0.906, blue: 0.925) // hairline #E4E7EC
```

For dark mode, map `workspace` to restrained versions of the current `board` dark values. Use exact branches rather than falling through, so future token changes remain explicit:

```swift
case .workspace: Color(red: 0.070, green: 0.074, blue: 0.082)
```

- [ ] **Step 3: Add shell-specific semantic tokens**

Append these computed properties inside `enum AppTheme` near the existing surface tokens:

```swift
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
```

- [ ] **Step 4: Run build to catch exhaustive switch misses**

Run:

```bash
swift build
```

Expected: if any `switch` is missing `case .workspace`, Swift emits a non-exhaustive switch error. Add explicit `workspace` branches until `swift build` exits 0.

- [ ] **Step 5: Commit**

```bash
git add Sources/DailyTodos/AppTheme.swift
git commit -m "feat: add workspace app skin"
```

---

### Task 2: Add Reusable Workspace Shell Components

**Files:**
- Create: `Sources/DailyTodos/WorkspaceShellViews.swift`
- Modify: `Sources/DailyTodos/AppShellViews.swift`

**Interfaces:**
- Consumes:
  - `AppModule`
  - `AppLogoImage`
  - `UpdateDot`
  - `AppTheme`
  - `AppMotion`
- Produces:
  - `WorkspaceShell<ContextSidebar: View, Content: View>`
  - `GlobalTopBar`
  - `ModuleRail`
  - `WorkspaceContentContainer<Header: View, Toolbar: View, BodyContent: View>`
  - `ContentHeader`
  - `ContentToolbar`
  - `WorkspaceIconButton`

- [ ] **Step 1: Create `WorkspaceShellViews.swift` with stable shell interfaces**

Create the file with this initial structure:

```swift
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
```

- [ ] **Step 2: Add `GlobalTopBar`**

Use a single global search field and app-level actions only:

```swift
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
            WorkspaceIconButton(systemName: hasUpdate ? "arrow.down.circle.fill" : "arrow.triangle.2.circlepath", title: "更新") {
                onOpenSettings()
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
```

- [ ] **Step 3: Add `ModuleRail` and `ModuleRailButton`**

The rail replaces the old bottom-logo module bar:

```swift
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
```

- [ ] **Step 4: Add content containers**

```swift
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
```

- [ ] **Step 5: Add `WorkspaceIconButton`**

```swift
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
```

- [ ] **Step 6: Compile**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/DailyTodos/WorkspaceShellViews.swift Sources/DailyTodos/AppShellViews.swift
git commit -m "feat: add workspace shell views"
```

---

### Task 3: Register Settings And Account Modules

**Files:**
- Modify: `Sources/DailyTodos/AppModules.swift`
- Modify: `Sources/DailyTodos/AppModule.swift`
- Create: `Sources/DailyTodos/AccountViews.swift`

**Interfaces:**
- Consumes: Existing `AppModuleRegistry` and `AppModule`.
- Produces:
  - `SettingsAppModule`
  - `AccountAppModule`
  - `AccountModuleView`
  - Registry order: todos, handbook, credentials, settings, account.

- [ ] **Step 1: Add settings and account modules**

Update the registered modules array in `AppModuleRegistry.init()`:

```swift
let modules: [any AppModule] = [
    TodoAppModule(),
    HandbookAppModule(),
    CredentialsAppModule(),
    SettingsAppModule(),
    AccountAppModule()
]
```

Add these module definitions to `AppModules.swift`:

```swift
struct SettingsAppModule: AppModule {
    let id = "settings"
    let displayName = "设置"
    let icon = "gearshape"
    let isDefault = true
    let description = "管理外观、AI、更新、模块和安全配置"
}

struct AccountAppModule: AppModule {
    let id = "account"
    let displayName = "账户"
    let icon = "person.crop.circle"
    let isDefault = true
    let description = "账户、空间和 Billing 边界"
}
```

- [ ] **Step 2: Create account placeholder view**

Create `AccountViews.swift`:

```swift
import SwiftUI

struct AccountModuleView: View {
    var body: some View {
        WorkspaceContentContainer {
            ContentHeader(
                title: "账户",
                subtitle: "个人空间、订阅和 Billing 边界"
            )
        } toolbar: {
            ContentToolbar {
                Label("商业化能力占位", systemImage: "creditcard")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: 14) {
                Label("账户系统尚未启用", systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text("当前版本保留账户、空间和 Billing 的产品边界，不连接远端服务，不处理支付。")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.workspaceSurface)
        }
    }
}
```

- [ ] **Step 3: Compile**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/DailyTodos/AppModule.swift Sources/DailyTodos/AppModules.swift Sources/DailyTodos/AccountViews.swift
git commit -m "feat: register workspace modules"
```

---

### Task 4: Wire `ContentView` To The Workspace Shell

**Files:**
- Modify: `Sources/DailyTodos/ContentView.swift`

**Interfaces:**
- Consumes:
  - `WorkspaceShell`
  - `TodoModuleView`
  - `HandbookModuleView`
  - `CredentialsModuleView`
  - `SettingsModuleView`
  - `AccountModuleView`
- Produces:
  - `@State private var globalSearchText = ""`
  - `contextSidebarView`
  - `workspaceContentView`
  - Settings topbar action activates the settings module instead of presenting only a modal.

- [ ] **Step 1: Add global search state**

Add near the existing search states:

```swift
@State private var globalSearchText = ""
```

- [ ] **Step 2: Replace root `HStack` with `WorkspaceShell`**

Replace the top-level `body` `HStack` with:

```swift
WorkspaceShell(
    installedModules: moduleRegistry.installedModules,
    activeModuleID: Binding(
        get: { moduleRegistry.activeModuleID },
        set: { moduleRegistry.activate($0) }
    ),
    globalSearchText: $globalSearchText,
    activeModuleTitle: contentTitle,
    activeModuleSubtitle: contentSubtitle,
    hasUpdate: updateController.hasAvailableUpdate,
    onOpenSettings: { activateSettings(.appearance) },
    onActivateModule: { moduleRegistry.activate($0) },
    contextSidebar: { activeContextSidebarView },
    content: { activeWorkspaceContentView }
)
```

Keep the existing `.foregroundStyle`, `.font`, `.id(selectedSkinRawValue)`, `.onAppear`, `.onChange`, `.onReceive`, and `.sheet` modifiers after the new root.

- [ ] **Step 3: Replace settings modal action helper**

Keep the current sheet helper for compatibility, but add a shell-first action:

```swift
private func activateSettings(_ section: AppSettingsSection) {
    appSettingsSection = section
    moduleRegistry.activate("settings")
}
```

Keep `openSettings(_:)` until all call sites are migrated:

```swift
private func openSettings(_ section: AppSettingsSection) {
    appSettingsSection = section
    isAppSettingsPresented = true
}
```

- [ ] **Step 4: Add active sidebar/content switch points**

Add two computed views. During this task, it is acceptable for module views to still render their old internal sidebars; Task 5 and Task 6 split them fully.

```swift
@ViewBuilder
private var activeContextSidebarView: some View {
    switch moduleRegistry.activeModuleID {
    case "todos":
        TodoContextSidebar(scope: $scope, isSecondarySidebarCollapsed: $isSecondarySidebarCollapsed)
    case "handbook":
        HandbookContextSidebar(
            handbookCategory: $handbookCategory,
            handbookFolder: $handbookFolder,
            isSecondarySidebarCollapsed: $isSecondarySidebarCollapsed
        )
        .environmentObject(store)
    case "credentials":
        CredentialContextSidebar()
            .environmentObject(credentialStore)
    case "settings":
        SettingsContextSidebar(selectedSection: $appSettingsSection)
            .environmentObject(updateController)
            .environmentObject(aiSettings)
    case "account":
        EmptyWorkspaceContextSidebar(title: "账户")
    default:
        EmptyWorkspaceContextSidebar(title: "模块")
    }
}

@ViewBuilder
private var activeWorkspaceContentView: some View {
    switch moduleRegistry.activeModuleID {
    case "todos":
        todoWorkspaceContentView
    case "handbook":
        handbookWorkspaceContentView
    case "credentials":
        CredentialsModuleView()
    case "settings":
        SettingsModuleView(
            selectedSkinRawValue: $selectedSkinRawValue,
            selectedSection: $appSettingsSection
        )
        .environmentObject(updateController)
        .environmentObject(moduleRegistry)
        .environmentObject(aiSettings)
        .environmentObject(credentialStore)
        .environmentObject(credentialActions)
    case "account":
        AccountModuleView()
    default:
        Text("未知模块")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

If any referenced view does not exist yet, create the smallest compiling version in the owning file as part of the task that owns it. Do not leave references unresolved when committing.

- [ ] **Step 5: Compile**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/DailyTodos/ContentView.swift
git commit -m "feat: wire app into workspace shell"
```

---

### Task 5: Split Todo And Handbook Into Shell Slots

**Files:**
- Modify: `Sources/DailyTodos/ModuleNavigationViews.swift`
- Modify: `Sources/DailyTodos/TodoSidebarViews.swift`
- Modify: `Sources/DailyTodos/HandbookSidebarViews.swift`
- Modify: `Sources/DailyTodos/ContentView.swift`

**Interfaces:**
- Consumes: Existing `TodoModuleView`, `HandbookModuleView`, `TodoSidebarView`, `HandbookFolderSidebarView`, `HandbookWorkspaceViewModel`.
- Produces:
  - `TodoContextSidebar`
  - `TodoWorkspaceContent`
  - `HandbookContextSidebar`
  - `HandbookWorkspaceContent`
  - `EmptyWorkspaceContextSidebar`
  - `ContentView.todoWorkspaceContentView`
  - `ContentView.handbookWorkspaceContentView`

- [ ] **Step 1: Add shared empty sidebar**

Add to `WorkspaceShellViews.swift`:

```swift
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
        .frame(width: secondarySidebarWidth, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.workspaceSidebar)
    }
}
```

- [ ] **Step 2: Add `TodoContextSidebar`**

In `ModuleNavigationViews.swift`, add:

```swift
struct TodoContextSidebar: View {
    @Binding var scope: TodoScope
    @Binding var isSecondarySidebarCollapsed: Bool

    var body: some View {
        Group {
            if isSecondarySidebarCollapsed {
                CollapsedSecondarySidebarRail(title: "待办", isCollapsed: $isSecondarySidebarCollapsed)
                    .frame(width: collapsedSecondarySidebarWidth)
            } else {
                TodoSidebarView(scope: $scope, isCollapsed: $isSecondarySidebarCollapsed)
                    .frame(width: secondarySidebarWidth)
                    .background(AppTheme.workspaceSidebar)
            }
        }
    }
}
```

- [ ] **Step 3: Add `TodoWorkspaceContent`**

Move the content area from `TodoModuleView.taskColumn` into a new view. Keep all existing bindings and callbacks:

```swift
struct TodoWorkspaceContent: View {
    @EnvironmentObject private var store: TodoStore
    @Binding var searchText: String
    @Binding var allTodosViewMode: AllTodosViewMode
    let scope: TodoScope
    let filteredTodosCache: [TodoItem]
    let debouncedSearchText: String
    let highlightedTodoID: TodoItem.ID?
    @Binding var scrollTargetTodoID: TodoItem.ID?
    @Binding var newTitle: String
    @Binding var newPriority: TodoPriority
    @Binding var newProgress: TodoProgress
    @Binding var newDate: Date
    let previewDate: Date
    @Binding var newNotes: String
    @Binding var newIsWeekly: Bool
    @Binding var isQuickCaptureExpanded: Bool
    var focusedField: FocusState<FocusField?>.Binding
    let isCreatingTodo: Bool
    let aiStatusMessage: String?
    let quickCaptureAITrace: AITrace?
    let quickCaptureAIResultSummary: String?
    let isAIEnabled: Bool
    let contentTitle: String
    let contentSubtitle: String
    let onActivate: () -> Void
    let onCreate: () -> Void
    let onClear: () -> Void
    let onUpdate: (TodoItem, TodoDraft) -> Void
    let onProgressChange: (TodoItem, TodoProgress) -> Void
    let onToggle: (TodoItem) -> Void
    let onDelete: (TodoItem) -> Void

    var body: some View {
        WorkspaceContentContainer {
            ContentHeader(title: contentTitle, subtitle: contentSubtitle)
        } toolbar: {
            ContentToolbar {
                ListToolbar(searchText: $searchText, allTodosViewMode: $allTodosViewMode, scope: scope)
            }
        } bodyContent: {
            VStack(alignment: .leading, spacing: 0) {
                if let error = store.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                }

                QuickCaptureBar(
                    title: $newTitle,
                    priority: $newPriority,
                    progress: $newProgress,
                    date: $newDate,
                    previewDate: previewDate,
                    notes: $newNotes,
                    isWeekly: $newIsWeekly,
                    isExpanded: $isQuickCaptureExpanded,
                    focusedField: focusedField,
                    onActivate: onActivate,
                    onCreate: onCreate,
                    onClear: onClear,
                    isCreating: isCreatingTodo,
                    aiStatusMessage: aiStatusMessage,
                    aiTrace: quickCaptureAITrace,
                    aiResultSummary: quickCaptureAIResultSummary,
                    isAIEnabled: isAIEnabled
                )
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

                TodoListView(
                    todos: filteredTodosCache,
                    scope: scope,
                    allTodosViewMode: allTodosViewMode,
                    onUpdate: onUpdate,
                    onProgressChange: onProgressChange,
                    onToggle: onToggle,
                    onDelete: onDelete,
                    highlightedTodoID: highlightedTodoID,
                    scrollTargetTodoID: $scrollTargetTodoID,
                    isSearching: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.workspaceSurface)
        }
    }
}
```

- [ ] **Step 4: Add `HandbookContextSidebar`**

In `ModuleNavigationViews.swift`, add:

```swift
struct HandbookContextSidebar: View {
    @EnvironmentObject private var store: TodoStore
    @Binding var handbookCategory: HandbookCategory?
    @Binding var handbookFolder: String?
    @Binding var isSecondarySidebarCollapsed: Bool
    @StateObject private var workspaceModel = HandbookWorkspaceViewModel()

    var body: some View {
        Group {
            if isSecondarySidebarCollapsed {
                CollapsedSecondarySidebarRail(title: "手记", isCollapsed: $isSecondarySidebarCollapsed)
                    .frame(width: collapsedSecondarySidebarWidth)
            } else {
                HandbookFolderSidebarView(
                    sidebarIndex: workspaceModel.sidebarIndex,
                    selectedCategory: $handbookCategory,
                    selectedFolder: $handbookFolder,
                    isSecondarySidebarCollapsed: $isSecondarySidebarCollapsed,
                    isLoaded: store.didLoadHandbookItems,
                    onMove: { _, _, _ in false }
                )
                .frame(width: secondarySidebarWidth)
                .background(AppTheme.workspaceSidebar)
            }
        }
        .onAppear {
            workspaceModel.refresh(items: store.handbookItems, selectedCategory: handbookCategory, selectedFolder: handbookFolder, searchText: "")
        }
        .onChange(of: store.handbookItems) { _, newItems in
            workspaceModel.refresh(items: newItems, selectedCategory: handbookCategory, selectedFolder: handbookFolder, searchText: "")
        }
    }
}
```

If drag move support is required in the sidebar, move the existing `onMove` closure from `HandbookModuleView` into `ContentView` and pass it into `HandbookContextSidebar`. The compile-safe fallback above must not ship if it disables an existing user-facing move path; use it only to unblock the first split, then restore move behavior before Task 5 commit.

- [ ] **Step 5: Add `HandbookWorkspaceContent`**

Extract the notes list and detail area from `HandbookModuleView` into a content-only view. Preserve the existing single `HandbookWorkspaceViewModel` inside the content view so selection and detail identity remain stable:

```swift
struct HandbookWorkspaceContent: View {
    @EnvironmentObject private var store: TodoStore
    @Binding var handbookCategory: HandbookCategory?
    @Binding var handbookFolder: String?
    @Binding var handbookSearchText: String
    let debouncedHandbookSearchText: String
    let onCreate: (HandbookCategory, String, String, String, [HandbookAttachment]) -> HandbookItem?
    let onUpdate: (HandbookItem, HandbookCategory, String, String, String, [HandbookAttachment]) -> Void
    let onDelete: (HandbookItem) -> Void
    @StateObject private var workspaceModel = HandbookWorkspaceViewModel()
    private let notesListWidth: CGFloat = 368

    var body: some View {
        WorkspaceContentContainer {
            ContentHeader(
                title: handbookCategory?.title ?? "全部手记",
                subtitle: handbookCategory?.subtitle ?? "收集业务规则、调研、会议和灵感"
            )
        } toolbar: {
            ContentToolbar {
                SearchField(text: $handbookSearchText)
                    .frame(maxWidth: 280)
                Button(action: createDraftHandbookItem) {
                    Label("新建", systemImage: "square.and.pencil")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.tactilePlain)
            }
        } bodyContent: {
            HStack(spacing: 0) {
                HandbookNotesListView(
                    snapshot: workspaceModel.listSnapshot,
                    selectedCategory: $handbookCategory,
                    selectedFolder: $handbookFolder,
                    searchText: $handbookSearchText,
                    selectedItemID: workspaceModel.selectedItemID,
                    isLoaded: store.didLoadHandbookItems,
                    onSelect: { workspaceModel.selectItem(id: $0) },
                    onCreateDraft: createDraftHandbookItem,
                    onDelete: { itemID in
                        guard let item = workspaceModel.item(for: itemID) else { return }
                        onDelete(item)
                        if workspaceModel.selectedItemID == item.id {
                            workspaceModel.selectItem(id: nil)
                        }
                    }
                )
                .frame(width: notesListWidth)

                Divider().overlay(AppTheme.hairline.opacity(0.72))

                HandbookDetailPanel(
                    item: workspaceModel.selectedItem,
                    onUpdate: onUpdate,
                    onDelete: { item in
                        onDelete(item)
                        if workspaceModel.selectedItemID == item.id {
                            workspaceModel.selectItem(id: nil)
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppTheme.workspaceSurface)
        }
        .onAppear {
            workspaceModel.refresh(items: store.handbookItems, selectedCategory: handbookCategory, selectedFolder: handbookFolder, searchText: debouncedHandbookSearchText)
        }
        .onChange(of: store.handbookItems) { _, newItems in
            workspaceModel.refresh(items: newItems, selectedCategory: handbookCategory, selectedFolder: handbookFolder, searchText: debouncedHandbookSearchText)
        }
        .onChange(of: handbookCategory) { _, _ in
            workspaceModel.updateScope(selectedCategory: handbookCategory, selectedFolder: handbookFolder, searchText: debouncedHandbookSearchText)
        }
        .onChange(of: handbookFolder) { _, _ in
            workspaceModel.updateScope(selectedCategory: handbookCategory, selectedFolder: handbookFolder, searchText: debouncedHandbookSearchText)
        }
        .onChange(of: debouncedHandbookSearchText) { _, _ in
            workspaceModel.updateScope(selectedCategory: handbookCategory, selectedFolder: handbookFolder, searchText: debouncedHandbookSearchText)
        }
    }

    private func createDraftHandbookItem() {
        let category = handbookCategory ?? .businessRule
        let folder = handbookFolder?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let createdItem = onCreate(category, folder, "未命名手记", "", []) else { return }
        handbookCategory = category
        handbookFolder = createdItem.trimmedFolder.isEmpty ? nil : createdItem.trimmedFolder
        workspaceModel.refresh(items: store.handbookItems, selectedCategory: handbookCategory, selectedFolder: handbookFolder, searchText: debouncedHandbookSearchText)
        workspaceModel.selectItem(id: createdItem.id)
    }
}
```

- [ ] **Step 6: Update `ContentView` computed views**

Add:

```swift
private var todoWorkspaceContentView: some View {
    TodoWorkspaceContent(
        searchText: $searchText,
        allTodosViewMode: $allTodosViewMode,
        scope: scope,
        filteredTodosCache: filteredTodosCache,
        debouncedSearchText: debouncedSearchText,
        highlightedTodoID: highlightedTodoID,
        scrollTargetTodoID: $scrollTargetTodoID,
        newTitle: $newTitle,
        newPriority: $newPriority,
        newProgress: $newProgress,
        newDate: quickCaptureDateBinding,
        previewDate: quickCaptureFallbackDate(),
        newNotes: $newNotes,
        newIsWeekly: $newIsWeekly,
        isQuickCaptureExpanded: $isQuickCaptureExpanded,
        focusedField: $focusedField,
        isCreatingTodo: isCreatingTodo,
        aiStatusMessage: aiStatusMessage,
        quickCaptureAITrace: quickCaptureAITrace,
        quickCaptureAIResultSummary: quickCaptureAIResultSummary,
        isAIEnabled: aiSettings.canUseAI,
        contentTitle: contentTitle,
        contentSubtitle: contentSubtitle,
        onActivate: focusQuickCapture,
        onCreate: createTodo,
        onClear: cancelCreate,
        onUpdate: updateTodo,
        onProgressChange: updateProgress,
        onToggle: toggleTodo,
        onDelete: deleteTodo
    )
}

private var handbookWorkspaceContentView: some View {
    HandbookWorkspaceContent(
        handbookCategory: $handbookCategory,
        handbookFolder: $handbookFolder,
        handbookSearchText: $handbookSearchText,
        debouncedHandbookSearchText: debouncedHandbookSearchText,
        onCreate: createHandbookItem,
        onUpdate: updateHandbookItem,
        onDelete: deleteHandbookItem
    )
}
```

- [ ] **Step 7: Preserve behavior**

Manually verify in code before compiling:

- Todo quick capture still receives `$focusedField`.
- Todo `newDate` still uses `quickCaptureDateBinding`.
- Handbook `HandbookWorkspaceViewModel` selection remains in one content owner.
- Handbook drag/move behavior from the sidebar is not removed in the final diff.

- [ ] **Step 8: Compile and run quality checks**

Run:

```bash
swift build
swiftc -parse-as-library Sources/DailyTodos/TodoItem.swift Sources/DailyTodos/HandbookItem.swift Sources/DailyTodos/TodoQuickInputParser.swift Sources/DailyTodos/AppStateModels.swift Sources/DailyTodos/ViewDerivedModels.swift Sources/DailyTodos/HandbookRepository.swift Sources/DailyTodos/HandbookWorkspaceViewModel.swift Sources/DailyTodos/PerformanceMonitor.swift Sources/DailyTodos/TodoStore.swift Sources/DailyTodos/AppUpdateAvailability.swift Sources/DailyTodos/AppUpdateDownloadProgress.swift scripts/quality_checks.swift -o /tmp/DailyTodosChecks
/tmp/DailyTodosChecks
```

Expected: both commands pass.

- [ ] **Step 9: Commit**

```bash
git add Sources/DailyTodos/WorkspaceShellViews.swift Sources/DailyTodos/ModuleNavigationViews.swift Sources/DailyTodos/TodoSidebarViews.swift Sources/DailyTodos/HandbookSidebarViews.swift Sources/DailyTodos/ContentView.swift
git commit -m "feat: adapt todos and handbook to workspace shell"
```

---

### Task 6: Adapt Credentials And Settings To Shell

**Files:**
- Modify: `Sources/DailyTodos/CredentialViews.swift`
- Modify: `Sources/DailyTodos/SettingsViews.swift`
- Modify: `Sources/DailyTodos/ContentView.swift`

**Interfaces:**
- Consumes:
  - `CredentialSidebar`
  - `CredentialTopBar`
  - `CredentialWorkArea`
  - `AppSettingsSheet`
  - `AppSettingsSection`
- Produces:
  - `CredentialContextSidebar`
  - `CredentialWorkspaceContent`
  - `SettingsContextSidebar`
  - `SettingsModuleView`
  - Reusable `SettingsWorkspaceContent`

- [ ] **Step 1: Split credentials sidebar**

Keep `CredentialSidebar` but expose a shell wrapper:

```swift
struct CredentialContextSidebar: View {
    @EnvironmentObject private var credentialStore: CredentialStore
    @State private var searchText = ""
    @State private var selectedType: CredentialType?

    var body: some View {
        CredentialSidebar(
            searchText: $searchText,
            selectedType: $selectedType,
            credentials: credentialStore.credentials,
            status: credentialStore.status
        )
        .frame(width: secondarySidebarWidth)
        .background(AppTheme.workspaceSidebar)
        .onAppear {
            credentialStore.load()
        }
    }
}
```

If this creates duplicate state with `CredentialsModuleView`, promote `searchText` and `selectedType` to `CredentialsModuleView` and pass bindings into both `CredentialContextSidebar` and `CredentialWorkspaceContent`. The final shipped code must have one source of truth for credential search/type selection.

- [ ] **Step 2: Convert `CredentialsModuleView` into content-only owner**

Replace the root `HStack` in `CredentialsModuleView.body` with `CredentialWorkspaceContent` or inline `WorkspaceContentContainer`. Preserve the existing states:

```swift
WorkspaceContentContainer {
    ContentHeader(title: "凭证", subtitle: credentialSubtitle)
} toolbar: {
    ContentToolbar {
        if credentialStore.status == .unlocked {
            Button(action: openNewCredential) {
                Label("新建凭证", systemImage: "plus")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.tactilePlain)

            if credentialStore.requiresMasterPassword {
                Button(action: { credentialStore.lock() }) {
                    Label("锁定", systemImage: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.tactilePlain)
            }
        }
    }
} bodyContent: {
    content
}
.onAppear {
    credentialStore.load()
}
```

Add:

```swift
private var credentialSubtitle: String {
    switch credentialStore.status {
    case .uninitialized: "尚未初始化凭证库"
    case .locked: "凭证库已锁定"
    case .unlocked: "\(credentialStore.credentials.count) 条凭证，敏感字段默认隐藏"
    }
}
```

- [ ] **Step 3: Extract settings workspace view**

In `SettingsViews.swift`, create a reusable container that contains the current navigation and content without a modal close button:

```swift
struct SettingsModuleView: View {
    @EnvironmentObject private var updateController: UpdateController
    @EnvironmentObject private var moduleRegistry: AppModuleRegistry
    @EnvironmentObject private var aiSettings: AISettingsStore
    @EnvironmentObject private var credentialStore: CredentialStore
    @EnvironmentObject private var credentialActions: CredentialManagementActions
    @Binding var selectedSkinRawValue: String
    @Binding var selectedSection: AppSettingsSection

    var body: some View {
        WorkspaceContentContainer {
            ContentHeader(title: selectedSection.title, subtitle: selectedSection.subtitle)
        } toolbar: {
            ContentToolbar {
                Label("设置", systemImage: selectedSection.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
        } bodyContent: {
            ScrollView {
                SettingsContentView(
                    selectedSkinRawValue: $selectedSkinRawValue,
                    selectedSection: $selectedSection
                )
                .padding(22)
            }
            .scrollIndicators(.visible)
            .background(AppTheme.workspaceSurface)
        }
        .sheet(isPresented: $credentialActions.isBackupSheetPresented) {
            CredentialBackupSheet()
                .environmentObject(credentialStore)
        }
    }
}
```

If the existing settings content is currently private inside `AppSettingsSheet`, move it into a new reusable `SettingsContentView` in the same file. Keep the body code identical except for removing `settingsHeader`, modal close button, and outer sheet frame.

- [ ] **Step 4: Add settings sidebar**

In `SettingsViews.swift`, add:

```swift
struct SettingsContextSidebar: View {
    @EnvironmentObject private var updateController: UpdateController
    @EnvironmentObject private var aiSettings: AISettingsStore
    @Binding var selectedSection: AppSettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("设置")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 8)

            ForEach(AppSettingsSection.allCases) { section in
                Button {
                    withAnimation(AppMotion.smooth) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: section.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(selectedSection == section ? AppTheme.accent : AppTheme.mutedInk)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(section.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.ink)
                            Text(section.subtitle)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(selectedSection == section ? AppTheme.accent : AppTheme.mutedInk)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if section == .ai {
                            Circle()
                                .fill(aiSettings.canUseAI ? AppTheme.success : AppTheme.mutedInk.opacity(0.36))
                                .frame(width: 6, height: 6)
                        } else if section == .updates, updateController.hasAvailableUpdate {
                            Circle()
                                .fill(TodoPriority.high.displayColor)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 46)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .background(
                        selectedSection == section ? AppTheme.sidebarSelected : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 0)
            Text(AppVersion.displayText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.mutedInk)
                .padding(18)
        }
        .frame(width: secondarySidebarWidth, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.workspaceSidebar)
    }
}
```

- [ ] **Step 5: Keep `AppSettingsSheet` as wrapper**

Refactor `AppSettingsSheet.body` to use the same reusable content so existing sheet call sites still work:

```swift
var body: some View {
    HStack(spacing: 0) {
        SettingsContextSidebar(selectedSection: $selectedSection)
            .environmentObject(updateController)
            .environmentObject(aiSettings)
        Divider().overlay(AppTheme.hairline)
        SettingsModuleView(
            selectedSkinRawValue: $selectedSkinRawValue,
            selectedSection: $selectedSection
        )
        .environmentObject(updateController)
        .environmentObject(moduleRegistry)
        .environmentObject(aiSettings)
        .environmentObject(credentialStore)
        .environmentObject(credentialActions)
    }
    .frame(width: 920, height: 640)
    .background(AppTheme.workspaceSurface)
    .foregroundStyle(AppTheme.ink)
}
```

The sheet wrapper may look redundant after settings becomes a module; retain it only to avoid breaking older internal paths.

- [ ] **Step 6: Compile and run quality checks**

Run:

```bash
swift build
swiftc -parse-as-library Sources/DailyTodos/TodoItem.swift Sources/DailyTodos/HandbookItem.swift Sources/DailyTodos/TodoQuickInputParser.swift Sources/DailyTodos/AppStateModels.swift Sources/DailyTodos/ViewDerivedModels.swift Sources/DailyTodos/HandbookRepository.swift Sources/DailyTodos/HandbookWorkspaceViewModel.swift Sources/DailyTodos/PerformanceMonitor.swift Sources/DailyTodos/TodoStore.swift Sources/DailyTodos/AppUpdateAvailability.swift Sources/DailyTodos/AppUpdateDownloadProgress.swift scripts/quality_checks.swift -o /tmp/DailyTodosChecks
/tmp/DailyTodosChecks
```

Expected: both commands pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/DailyTodos/CredentialViews.swift Sources/DailyTodos/SettingsViews.swift Sources/DailyTodos/ContentView.swift
git commit -m "feat: adapt credentials and settings to workspace shell"
```

---

### Task 7: Final Visual, Interaction, And Release Gate

**Files:**
- Modify only files that previous tasks touched if verification finds issues.
- Do not create new architecture files in this task.

**Interfaces:**
- Consumes: Finished shell and module adaptations.
- Produces: Passing build, passing quality checks, and a concise manual QA record in the final implementation message.

- [ ] **Step 1: Run full verification**

Run:

```bash
swift build
swiftc -parse-as-library Sources/DailyTodos/TodoItem.swift Sources/DailyTodos/HandbookItem.swift Sources/DailyTodos/TodoQuickInputParser.swift Sources/DailyTodos/AppStateModels.swift Sources/DailyTodos/ViewDerivedModels.swift Sources/DailyTodos/HandbookRepository.swift Sources/DailyTodos/HandbookWorkspaceViewModel.swift Sources/DailyTodos/PerformanceMonitor.swift Sources/DailyTodos/TodoStore.swift Sources/DailyTodos/AppUpdateAvailability.swift Sources/DailyTodos/AppUpdateDownloadProgress.swift scripts/quality_checks.swift -o /tmp/DailyTodosChecks
/tmp/DailyTodosChecks
python3 scripts/release_version_guard.py --self-test
git diff --check
```

Expected: all commands pass.

- [ ] **Step 2: Launch local app for manual QA**

Run:

```bash
swift run
```

Manual checks:

- Top bar remains visible in todos, handbook, credentials, settings, and account.
- Module rail selection changes immediately.
- Todo quick capture keeps focus while typing.
- Handbook editor keeps focus after a short pause and after input method switching.
- Handbook category selection and note selection do not jump to unrelated notes.
- Credential vault lock/unlock/new/copy paths still work.
- Settings skin switch includes “工作台” and applies immediately.
- Update section still shows progress state when an update is available.
- Account module clearly states that account/Billing are boundaries only.

- [ ] **Step 3: Check visual constraints**

Inspect the running app:

- No nested page cards inside cards.
- Main content occupies the available right side.
- Left rail is not wider than the old `primarySidebarWidth`.
- Context sidebar is readable and full-row clickable.
- Text contrast is not lighter than the existing `AppTheme.mutedInk` for body text.
- No “备忘录” copy appears in handbook UI.

- [ ] **Step 4: Remove dead shell duplicates only if no longer referenced**

Run:

```bash
rg -n "ModuleSwitcherBar|AppTopBar|PrimarySidebarView" Sources/DailyTodos
```

If a symbol is unreferenced and only belongs to the old shell, remove it from `AppShellViews.swift`. Keep shared controls such as `AppLogoImage`, `SkinPickerButton`, `UpdateDot`, and `TactilePlainButtonStyle`.

- [ ] **Step 5: Run final status**

Run:

```bash
git status --short
```

Expected: only intentional source/docs changes are present.

- [ ] **Step 6: Commit**

```bash
git add Sources/DailyTodos docs/superpowers/specs/2026-07-01-antorder-workspace-shell-design.md docs/superpowers/plans/2026-07-01-antorder-workspace-shell-implementation.md
git commit -m "chore: verify workspace shell rollout"
```

If Task 7 finds no code or docs changes, do not create an empty commit. Report that verification passed with no final cleanup commit.

---

## Plan Self-Review

Spec coverage:

- Full-app shell: Tasks 2, 3, 4, 5, and 6.
- Workspace skin: Task 1.
- Todos, handbook, credentials, settings, account boundaries: Tasks 3, 5, and 6.
- No data/store/parser/sync changes: Global constraints and file restrictions.
- Focus and performance concerns: Task 7 manual QA.
- Account/Billing boundary without real payment: Task 3.
- Global search as UI entry without complete indexing: Task 2.

Placeholder scan:

- This plan intentionally contains no unresolved section or undefined acceptance gate.
- Temporary compile fallbacks are explicitly marked as not acceptable for the final shipped diff when they would remove user-facing behavior.

Type consistency:

- New shell types are defined before being consumed.
- `SettingsModuleView`, `AccountModuleView`, `TodoWorkspaceContent`, and `HandbookWorkspaceContent` are named consistently across tasks.
- Existing domain types are not renamed.
