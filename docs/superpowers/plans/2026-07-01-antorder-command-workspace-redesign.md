# AntOrder Command Workspace Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a unified command-style workspace for AntOrder so Todos, Handbook, and Credentials share one shell, one header/toolbar language, and a real cross-module global search.

**Architecture:** Keep the current SwiftUI workspace shell and module registry. Add focused workspace primitives, then wire global search through `ContentView` so search results can activate modules and select records without polluting local filters. Replace old per-module header/search/sidebar patterns incrementally instead of rewriting storage or editor internals.

**Tech Stack:** Swift 6, SwiftUI, macOS 14, SQLite-backed local stores, existing shell files under `Sources/DailyTodos`.

## Global Constraints

- Do not replace SQLite or repository boundaries in this change.
- Do not implement account login, Billing, remote sync, AI semantic search, or vector search.
- Do not reveal credential sensitive fields through global search.
- Keep old skins (`ocean`, `aurora`, `board`, `leafcutter`, `workspace`) as color palettes only; skins must not change layout dimensions or component structure.
- Left-2 header title, subtitle, and collapse button must live in one fixed header.
- Right content title and subtitle must live in one fixed content header.
- `Command-K` must focus global search.
- Global search must not write into module local search fields unless the user explicitly chooses a local-filter action.
- Verification commands: `swift build`, `scripts/run_quality_checks.sh`, `python3 scripts/release_version_guard.py --self-test`, `git diff --check`.

---

## File Structure

- Modify `Sources/DailyTodos/AppTheme.swift`: add `WorkspaceThemeTokens` and fixed workspace measurements used by every skin.
- Modify `Sources/DailyTodos/AppShellViews.swift`: rename/collapse secondary rail primitives into `CollapsedContextRail`, and keep the button available for context headers.
- Modify `Sources/DailyTodos/WorkspaceShellViews.swift`: add `WorkspaceContextHeader`, `WorkspaceContentHeader`, `WorkspaceLocalToolbar`, `WorkspaceSearchField`, `WorkspaceSegmentedControl`, `WorkspaceListRowSurface`, and update `GlobalTopBar` to host the command search panel.
- Create `Sources/DailyTodos/GlobalCommandSearch.swift`: define result models, indexing helpers, and local search matching for todos, handbook summaries/items, and credential safe metadata.
- Modify `Sources/DailyTodos/ContentView.swift`: own global search focus/panel state, build search context from existing stores, implement result jump behavior, and pass new layout inputs to modules.
- Modify `Sources/DailyTodos/ModuleNavigationViews.swift`: replace legacy `ContentHeader`/`ContentToolbar` references with workspace primitives and remove repeated search where needed.
- Modify `Sources/DailyTodos/TodoSidebarViews.swift`: reuse `WorkspaceContextHeader` and keep the existing date/calendar behavior stable.
- Modify `Sources/DailyTodos/HandbookNotesWorkspaceView.swift`: align left-2 header copy, collapse behavior, Notes list header, local search placement, and editor split.
- Modify `Sources/DailyTodos/CredentialViews.swift`: remove local search from left-2, add content toolbar search, align list/detail surfaces, and preserve lock/reveal behavior.
- Modify `Sources/DailyTodos/ListToolbarViews.swift`: adapt `SearchField` and segmented controls to the workspace components or wrap them with compatibility typealiases.

---

### Task 1: Workspace Primitives And Theme Tokens

**Files:**
- Modify: `Sources/DailyTodos/AppTheme.swift`
- Modify: `Sources/DailyTodos/AppShellViews.swift`
- Modify: `Sources/DailyTodos/WorkspaceShellViews.swift`
- Modify: `Sources/DailyTodos/ListToolbarViews.swift`

**Interfaces:**
- Consumes: existing `AppTheme`, `AppSkin`, `AppMotion`, `SecondarySidebarCollapseButton`, `SearchField`, `ContentHeader`, `ContentToolbar`.
- Produces:
  - `struct WorkspaceThemeTokens`
  - `extension AppTheme { static var workspaceTokens: WorkspaceThemeTokens }`
  - `struct WorkspaceContextHeader`
  - `struct CollapsedContextRail`
  - `struct WorkspaceContentHeader`
  - `struct WorkspaceLocalToolbar<Content: View>`
  - `struct WorkspaceSearchField`
  - `struct WorkspaceSegmentedControl<Option: WorkspaceSegmentedOption>`
  - `protocol WorkspaceSegmentedOption: Identifiable, CaseIterable, Hashable`
  - `struct WorkspaceListRowSurface<Content: View>`

- [ ] **Step 1: Add token model**

Add this near the top-level theme declarations in `Sources/DailyTodos/AppTheme.swift`:

```swift
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
```

- [ ] **Step 2: Map skins to palette-only tokens**

Add `AppTheme.workspaceTokens` using existing `AppTheme` colors as the compatibility layer. Ensure every `AppSkin` returns the same structural tokens and only changes color values:

```swift
extension AppTheme {
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
}
```

- [ ] **Step 3: Add workspace headers**

In `Sources/DailyTodos/WorkspaceShellViews.swift`, add:

```swift
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
```

- [ ] **Step 4: Add toolbar and search field**

In `Sources/DailyTodos/WorkspaceShellViews.swift`, add:

```swift
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
```

- [ ] **Step 5: Add segmented control and row surface**

In `Sources/DailyTodos/WorkspaceShellViews.swift`, add the shared segmented option protocol and row shell:

```swift
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
```

- [ ] **Step 6: Preserve compatibility aliases**

Replace the bodies of `ContentHeader`, `ContentToolbar`, and `SearchField` with wrappers around the new components so existing files still compile during later tasks:

```swift
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

struct SearchField: View {
    @Binding var text: String
    var placeholder = "搜索标题或备注"

    var body: some View {
        WorkspaceSearchField(text: $text, placeholder: placeholder, isFocused: nil)
    }
}
```

- [ ] **Step 7: Verify compilation**

Run:

```bash
swift build
```

Expected: build succeeds without duplicate type errors.

- [ ] **Step 8: Commit**

```bash
git add Sources/DailyTodos/AppTheme.swift Sources/DailyTodos/AppShellViews.swift Sources/DailyTodos/WorkspaceShellViews.swift Sources/DailyTodos/ListToolbarViews.swift
git commit -m "feat: add workspace primitives"
```

---

### Task 2: Global Command Search Model

**Files:**
- Create: `Sources/DailyTodos/GlobalCommandSearch.swift`
- Modify: `Sources/DailyTodos/WorkspaceShellViews.swift`
- Modify: `Sources/DailyTodos/ContentView.swift`

**Interfaces:**
- Consumes: `TodoItem`, `TodoScope`, `HandbookItem`, `HandbookCategory`, `CredentialItem`, `CredentialType`, `AppModuleRegistry`.
- Produces:
  - `enum GlobalSearchModule: String, CaseIterable, Identifiable`
  - `enum GlobalSearchTarget: Identifiable, Equatable`
  - `struct GlobalSearchResult: Identifiable, Equatable`
  - `struct GlobalCommandSearchContext`
  - `struct GlobalCommandSearchEngine`
  - `struct GlobalCommandSearchPanel`
  - `struct GlobalSearchResultRow`

- [ ] **Step 1: Create result models**

Create `Sources/DailyTodos/GlobalCommandSearch.swift` with:

```swift
import Foundation
import SwiftUI

enum GlobalSearchModule: String, CaseIterable, Identifiable {
    case todos
    case handbook
    case credentials

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todos: "待办"
        case .handbook: "手记"
        case .credentials: "凭证"
        }
    }

    var icon: String {
        switch self {
        case .todos: "checklist"
        case .handbook: "book.closed"
        case .credentials: "key.fill"
        }
    }
}

enum GlobalSearchTarget: Identifiable, Equatable {
    case todo(UUID, scope: TodoScope)
    case handbook(UUID, category: HandbookCategory?, folder: String?)
    case credential(UUID, type: CredentialType?)

    var id: String {
        switch self {
        case .todo(let id, _): "todo-\(id.uuidString)"
        case .handbook(let id, _, _): "handbook-\(id.uuidString)"
        case .credential(let id, _): "credential-\(id.uuidString)"
        }
    }
}

struct GlobalSearchResult: Identifiable, Equatable {
    let id: String
    let module: GlobalSearchModule
    let title: String
    let subtitle: String
    let detail: String
    let target: GlobalSearchTarget

    init(module: GlobalSearchModule, title: String, subtitle: String, detail: String, target: GlobalSearchTarget) {
        self.module = module
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.target = target
        self.id = "\(module.rawValue)-\(target.id)"
    }
}

struct GlobalCommandSearchContext {
    let todos: [TodoItem]
    let handbookItems: [HandbookItem]
    let credentials: [CredentialItem]
    let didLoadHandbookItems: Bool
    let isLoadingHandbookItems: Bool
    let isCredentialVaultUnlocked: Bool
}
```

- [ ] **Step 2: Add search engine**

Append to the same file:

```swift
struct GlobalCommandSearchEngine {
    private let calendar = Calendar.current

    func results(query rawQuery: String, context: GlobalCommandSearchContext) -> [GlobalSearchModule: [GlobalSearchResult]] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [:] }
        let normalizedQuery = query.localizedLowercase

        return [
            .todos: todoResults(query: normalizedQuery, todos: context.todos),
            .handbook: handbookResults(query: normalizedQuery, items: context.handbookItems),
            .credentials: context.isCredentialVaultUnlocked
                ? credentialResults(query: normalizedQuery, credentials: context.credentials)
                : []
        ]
    }

    private func todoResults(query: String, todos: [TodoItem]) -> [GlobalSearchResult] {
        todos.compactMap { todo in
            let haystack = [
                todo.trimmedTitle,
                todo.trimmedNotes,
                todo.priority.label,
                todo.progress.label,
                todo.date.formatted(.dateTime.year().month().day().hour().minute())
            ].joined(separator: " ").localizedLowercase
            guard haystack.contains(query) else { return nil }

            let scope: TodoScope = calendar.isDateInToday(todo.date) ? .dashboard : .all
            return GlobalSearchResult(
                module: .todos,
                title: todo.trimmedTitle,
                subtitle: todo.progress.label,
                detail: todo.date.formatted(.dateTime.month().day().hour().minute()),
                target: .todo(todo.id, scope: scope)
            )
        }
        .prefix(5)
        .map { $0 }
    }

    private func handbookResults(query: String, items: [HandbookItem]) -> [GlobalSearchResult] {
        items.compactMap { item in
            let attachmentText = item.attachments.map(\.name).joined(separator: " ")
            let haystack = [
                item.trimmedTitle,
                item.trimmedBody,
                item.category.title,
                item.trimmedFolder,
                attachmentText
            ].joined(separator: " ").localizedLowercase
            guard haystack.contains(query) else { return nil }

            return GlobalSearchResult(
                module: .handbook,
                title: item.trimmedTitle.isEmpty ? "未命名手记" : item.trimmedTitle,
                subtitle: item.category.title,
                detail: item.trimmedFolder.isEmpty ? "未归档" : item.trimmedFolder,
                target: .handbook(item.id, category: item.category, folder: item.trimmedFolder.isEmpty ? nil : item.trimmedFolder)
            )
        }
        .prefix(5)
        .map { $0 }
    }

    private func credentialResults(query: String, credentials: [CredentialItem]) -> [GlobalSearchResult] {
        credentials.compactMap { item in
            let haystack = [
                item.title,
                item.username,
                item.serviceURL,
                item.type.title,
                item.tags.joined(separator: " ")
            ].joined(separator: " ").localizedLowercase
            guard haystack.contains(query) else { return nil }

            return GlobalSearchResult(
                module: .credentials,
                title: item.title,
                subtitle: item.type.title,
                detail: item.displayService,
                target: .credential(item.id, type: item.type)
            )
        }
        .prefix(5)
        .map { $0 }
    }
}
```

- [ ] **Step 3: Add panel view**

Append:

```swift
struct GlobalCommandSearchPanel: View {
    let query: String
    let groupedResults: [GlobalSearchModule: [GlobalSearchResult]]
    let didLoadHandbookItems: Bool
    let isLoadingHandbookItems: Bool
    let isCredentialVaultUnlocked: Bool
    let onSelect: (GlobalSearchResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(statusText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.workspaceTokens.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)

            Divider().overlay(AppTheme.workspaceTokens.hairline.opacity(0.72))

            if totalCount == 0 {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(GlobalSearchModule.allCases) { module in
                            if let results = groupedResults[module], !results.isEmpty {
                                resultSection(module: module, results: results)
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: 340)
            }
        }
        .frame(width: 520)
        .background(AppTheme.workspaceTokens.contentSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.workspaceTokens.hairline)
        )
        .shadow(color: AppTheme.workspaceTokens.shadow.opacity(0.95), radius: 18, x: 0, y: 10)
    }

    private var totalCount: Int {
        groupedResults.values.reduce(0) { $0 + $1.count }
    }

    private var statusText: String {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "输入关键词，跨待办、手记和凭证定位内容"
        }
        if isLoadingHandbookItems {
            return "正在加载手记，同时搜索已加载内容"
        }
        if !didLoadHandbookItems {
            return "手记尚未加载，打开搜索会自动加载"
        }
        if !isCredentialVaultUnlocked {
            return "凭证库锁定时只搜索待办和手记"
        }
        return "按回车打开选中结果，Esc 关闭"
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("没有匹配结果")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
            Text("可以减少关键词，或切换到对应模块使用局部搜索。")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.workspaceTokens.textMuted)
        }
        .padding(14)
    }

    private func resultSection(module: GlobalSearchModule, results: [GlobalSearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(module.title, systemImage: module.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.workspaceTokens.textMuted)
                .padding(.horizontal, 4)

            ForEach(results) { result in
                GlobalSearchResultRow(result: result) {
                    onSelect(result)
                }
            }
        }
    }
}

struct GlobalSearchResultRow: View {
    let result: GlobalSearchResult
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: result.module.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.workspaceTokens.accent)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.workspaceTokens.textPrimary)
                        .lineLimit(1)
                    Text("\(result.subtitle) · \(result.detail)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.workspaceTokens.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isHovered ? AppTheme.workspaceTokens.listRowHover : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
```

- [ ] **Step 4: Verify model compiles**

Run:

```bash
swift build
```

Expected: build succeeds or shows only call-site errors that are fixed in the next step before committing.

- [ ] **Step 5: Commit**

```bash
git add Sources/DailyTodos/GlobalCommandSearch.swift Sources/DailyTodos/WorkspaceShellViews.swift Sources/DailyTodos/ContentView.swift
git commit -m "feat: add global command search model"
```

---

### Task 3: Wire Global Search And Result Navigation

**Files:**
- Modify: `Sources/DailyTodos/WorkspaceShellViews.swift`
- Modify: `Sources/DailyTodos/ContentView.swift`
- Modify: `Sources/DailyTodos/CredentialViews.swift`

**Interfaces:**
- Consumes: `GlobalCommandSearchContext`, `GlobalCommandSearchEngine`, `GlobalCommandSearchPanel`.
- Produces:
  - `GlobalTopBar(searchText:isSearchPresented:onSearchFocused:onSearchDismiss:onSelectResult:searchPanel:)`
  - `ContentView.globalSearchContext`
  - `ContentView.globalSearchResults`
  - `ContentView.selectGlobalSearchResult(_:)`
  - `CredentialsModuleView(selectedCredentialID: Binding<UUID?>?)`

- [ ] **Step 1: Add search state in `ContentView`**

Add state properties:

```swift
@State private var isGlobalSearchPresented = false
@State private var selectedCredentialID: UUID?
@FocusState private var isGlobalSearchFocused: Bool
private let globalSearchEngine = GlobalCommandSearchEngine()
```

- [ ] **Step 2: Add search context and results**

Add computed properties in `ContentView`:

```swift
private var globalSearchContext: GlobalCommandSearchContext {
    GlobalCommandSearchContext(
        todos: store.todos,
        handbookItems: store.handbookItems,
        credentials: credentialStore.credentials,
        didLoadHandbookItems: store.didLoadHandbookItems,
        isLoadingHandbookItems: store.isLoadingHandbookItems,
        isCredentialVaultUnlocked: credentialStore.isUnlocked
    )
}

private var globalSearchResults: [GlobalSearchModule: [GlobalSearchResult]] {
    globalSearchEngine.results(query: globalSearchText, context: globalSearchContext)
}
```

- [ ] **Step 3: Pass global panel into shell**

Update the `WorkspaceShell` call in `ContentView`:

```swift
WorkspaceShell(
    installedModules: moduleRegistry.installedModules,
    activeModuleID: Binding(
        get: { moduleRegistry.activeModuleID },
        set: { moduleRegistry.activate($0) }
    ),
    globalSearchText: $globalSearchText,
    isGlobalSearchPresented: $isGlobalSearchPresented,
    isGlobalSearchFocused: $isGlobalSearchFocused,
    globalSearchResults: globalSearchResults,
    globalSearchContext: globalSearchContext,
    hasUpdate: updateController.hasAvailableUpdate,
    onOpenSettings: { activateSettings(.appearance) },
    onActivateModule: { moduleRegistry.activate($0) },
    onGlobalSearchFocused: {
        store.scheduleLoadHandbookItemsIfNeeded()
    },
    onGlobalSearchDismiss: {
        isGlobalSearchPresented = false
    },
    onSelectGlobalSearchResult: selectGlobalSearchResult,
    contextSidebar: { activeContextSidebarView },
    content: { activeWorkspaceContentView }
)
```

- [ ] **Step 4: Update `WorkspaceShell` signature**

Change `WorkspaceShell` in `WorkspaceShellViews.swift` to accept:

```swift
@Binding var isGlobalSearchPresented: Bool
var isGlobalSearchFocused: FocusState<Bool>.Binding
let globalSearchResults: [GlobalSearchModule: [GlobalSearchResult]]
let globalSearchContext: GlobalCommandSearchContext
let onGlobalSearchFocused: () -> Void
let onGlobalSearchDismiss: () -> Void
let onSelectGlobalSearchResult: (GlobalSearchResult) -> Void
```

Pass them to `GlobalTopBar`.

- [ ] **Step 5: Replace `GlobalTopBar` search behavior**

Update `GlobalTopBar` to hold focus and panel:

```swift
@Binding var isSearchPresented: Bool
var isSearchFocused: FocusState<Bool>.Binding
let groupedResults: [GlobalSearchModule: [GlobalSearchResult]]
let searchContext: GlobalCommandSearchContext
let onSearchFocused: () -> Void
let onSearchDismiss: () -> Void
let onSelectResult: (GlobalSearchResult) -> Void
```

Wrap the search field in a `ZStack(alignment: .topLeading)` and show:

```swift
if isSearchPresented {
    GlobalCommandSearchPanel(
        query: searchText,
        groupedResults: groupedResults,
        didLoadHandbookItems: searchContext.didLoadHandbookItems,
        isLoadingHandbookItems: searchContext.isLoadingHandbookItems,
        isCredentialVaultUnlocked: searchContext.isCredentialVaultUnlocked,
        onSelect: { result in
            onSelectResult(result)
            searchText = ""
            isSearchPresented = false
            isSearchFocused.wrappedValue = false
        }
    )
    .offset(y: 38)
    .zIndex(20)
}
```

Attach:

```swift
WorkspaceSearchField(
    text: $searchText,
    placeholder: "搜索蚁序",
    shortcutHint: "⌘K",
    isFocused: isSearchFocused
)
.onChange(of: isSearchFocused.wrappedValue) { _, focused in
    if focused {
        isSearchPresented = true
        onSearchFocused()
    }
}
.onChange(of: searchText) { _, newValue in
    if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        isSearchPresented = true
        onSearchFocused()
    }
}
.onExitCommand {
    searchText = ""
    isSearchPresented = false
    isSearchFocused.wrappedValue = false
    onSearchDismiss()
}
```

Add a keyboard shortcut button to `WorkspaceShell.body` inside a hidden overlay. This is the required `Command-K` path:

```swift
Button("搜索蚁序") {
    isGlobalSearchPresented = true
    isGlobalSearchFocused.wrappedValue = true
    onGlobalSearchFocused()
}
.keyboardShortcut("k", modifiers: [.command])
.frame(width: 0, height: 0)
.opacity(0)
```

- [ ] **Step 6: Implement result navigation**

Add to `ContentView`:

```swift
private func selectGlobalSearchResult(_ result: GlobalSearchResult) {
    switch result.target {
    case .todo(let id, let targetScope):
        moduleRegistry.activate("todos")
        scope = targetScope
        searchText = ""
        debouncedSearchText = ""
        rebuildFilteredTodos()
        highlightTodo(id, shouldScroll: true)

    case .handbook(let id, let category, let folder):
        moduleRegistry.activate("handbook")
        store.scheduleLoadHandbookItemsIfNeeded()
        handbookCategory = category
        handbookFolder = folder
        handbookSearchText = ""
        debouncedHandbookSearchText = ""
        handbookWorkspaceModel.refresh(
            items: store.handbookItems,
            selectedCategory: handbookCategory,
            selectedFolder: handbookFolder,
            searchText: debouncedHandbookSearchText
        )
        handbookWorkspaceModel.selectItem(id: id)

    case .credential(let id, let type):
        moduleRegistry.activate("credentials")
        credentialSearchText = ""
        credentialSelectedType = type
        selectedCredentialID = id
    }
}
```

- [ ] **Step 7: Make credentials externally selectable**

In `CredentialsModuleView`, add:

```swift
private let externalSelectedCredentialID: Binding<UUID?>?
```

Update initializer:

```swift
init(
    searchText: Binding<String>? = nil,
    selectedType: Binding<CredentialType?>? = nil,
    selectedCredentialID: Binding<UUID?>? = nil
) {
    externalSearchText = searchText
    externalSelectedType = selectedType
    externalSelectedCredentialID = selectedCredentialID
}
```

Replace local selected binding usage with:

```swift
private var selectedCredentialIDBinding: Binding<UUID?> {
    externalSelectedCredentialID ?? $selectedCredentialID
}
```

Then use `selectedCredentialIDBinding.wrappedValue` in `selectedCredential`, `onSelect`, and save/delete paths.

- [ ] **Step 8: Pass selected credential binding**

Update `ContentView.activeWorkspaceContentView` credentials case:

```swift
CredentialsModuleView(
    searchText: $credentialSearchText,
    selectedType: $credentialSelectedType,
    selectedCredentialID: $selectedCredentialID
)
```

- [ ] **Step 9: Verify**

Run:

```bash
swift build
scripts/run_quality_checks.sh
```

Expected: both commands pass.

- [ ] **Step 10: Commit**

```bash
git add Sources/DailyTodos/WorkspaceShellViews.swift Sources/DailyTodos/ContentView.swift Sources/DailyTodos/CredentialViews.swift
git commit -m "feat: wire global command search"
```

---

### Task 4: Align Todos And Handbook Workspace Layout

**Files:**
- Modify: `Sources/DailyTodos/ModuleNavigationViews.swift`
- Modify: `Sources/DailyTodos/TodoSidebarViews.swift`
- Modify: `Sources/DailyTodos/HandbookNotesWorkspaceView.swift`
- Modify: `Sources/DailyTodos/ListToolbarViews.swift`

**Interfaces:**
- Consumes: `WorkspaceContextHeader`, `WorkspaceContentHeader`, `WorkspaceLocalToolbar`, `WorkspaceSearchField`, `CollapsedContextRail`.
- Produces: no new public model; this task replaces visual structure and removes duplicated search.

- [ ] **Step 1: Replace collapsed rail names**

In `AppShellViews.swift`, rename `CollapsedSecondarySidebarRail` to `CollapsedContextRail`. Add this compatibility wrapper until all call sites are migrated:

```swift
typealias CollapsedSecondarySidebarRail = CollapsedContextRail
```

Update `TodoContextSidebar` and `HandbookContextSidebar` to instantiate `CollapsedContextRail`.

- [ ] **Step 2: Use `WorkspaceContextHeader` in todo sidebar**

Replace `TodoSidebarView.sidebarHeader` with:

```swift
private var sidebarHeader: some View {
    WorkspaceContextHeader(
        title: "待办",
        subtitle: "今日、等待、固定、全部",
        isCollapsed: $isCollapsed
    )
}
```

- [ ] **Step 3: Use `WorkspaceContentHeader` and `WorkspaceLocalToolbar` in todo content**

In `TodoWorkspaceContent.body`, replace:

```swift
ContentHeader(title: contentTitle, subtitle: contentSubtitle)
ContentToolbar {
    ListToolbar(searchText: $searchText, allTodosViewMode: $allTodosViewMode, scope: scope)
}
```

with:

```swift
WorkspaceContentHeader(title: contentTitle, subtitle: contentSubtitle)
WorkspaceLocalToolbar {
    ListToolbar(searchText: $searchText, allTodosViewMode: $allTodosViewMode, scope: scope)
}
```

- [ ] **Step 4: Use `WorkspaceContextHeader` in handbook sidebar**

Replace `HandbookFolderSidebarView.sidebarHeader` with:

```swift
private var sidebarHeader: some View {
    WorkspaceContextHeader(
        title: "手记",
        subtitle: "规则、调研、会议、灵感",
        isCollapsed: $isSecondarySidebarCollapsed
    )
}
```

- [ ] **Step 5: Remove duplicated handbook toolbar search**

In `HandbookWorkspaceContent.body`, keep search in `HandbookNotesListView.notesListHeader`. Replace toolbar contents with only new/create/sort actions:

```swift
WorkspaceLocalToolbar {
    Button(action: createDraftHandbookItem) {
        Label("新建", systemImage: "square.and.pencil")
            .font(.system(size: 12, weight: .bold))
    }
    .buttonStyle(.tactilePlain)
}
```

Keep `HandbookNotesListView` receiving `$handbookSearchText`.

- [ ] **Step 6: Use `WorkspaceContentHeader` in handbook content**

Replace the content header with:

```swift
WorkspaceContentHeader(
    title: handbookCategory?.title ?? "全部手记",
    subtitle: handbookCategory?.subtitle ?? "收集业务规则、调研、会议和灵感"
)
```

- [ ] **Step 7: Ensure notes list remains selectable**

In `HandbookNotesRow`, confirm the button `.contentShape(Rectangle())` wraps the entire row. If absent, add:

```swift
.contentShape(Rectangle())
```

inside the row label before `.background(...)`.

- [ ] **Step 8: Verify**

Run:

```bash
swift build
scripts/run_quality_checks.sh
```

Expected: build and checks pass; no duplicate search field appears in handbook content header and notes list header.

- [ ] **Step 9: Commit**

```bash
git add Sources/DailyTodos/ModuleNavigationViews.swift Sources/DailyTodos/TodoSidebarViews.swift Sources/DailyTodos/HandbookNotesWorkspaceView.swift Sources/DailyTodos/ListToolbarViews.swift Sources/DailyTodos/AppShellViews.swift
git commit -m "refactor: align todos and handbook workspace"
```

---

### Task 5: Align Credentials Workspace Layout

**Files:**
- Modify: `Sources/DailyTodos/CredentialViews.swift`
- Modify: `Sources/DailyTodos/ContentView.swift`

**Interfaces:**
- Consumes: `WorkspaceContextHeader`, `WorkspaceContentHeader`, `WorkspaceLocalToolbar`, `WorkspaceSearchField`, `WorkspaceListRowSurface`.
- Produces:
  - `CredentialContextSidebar(isSecondarySidebarCollapsed:)`
  - credentials search moved from left-2 to content toolbar.

- [ ] **Step 1: Add credential sidebar collapse binding**

Change `CredentialContextSidebar` signature:

```swift
struct CredentialContextSidebar: View {
    @EnvironmentObject private var credentialStore: CredentialStore
    @Binding var selectedType: CredentialType?
    @Binding var isSecondarySidebarCollapsed: Bool
}
```

Remove `searchText` from this sidebar.

- [ ] **Step 2: Update `ContentView` credential sidebar call**

Replace:

```swift
CredentialContextSidebar(
    searchText: $credentialSearchText,
    selectedType: $credentialSelectedType
)
```

with:

```swift
CredentialContextSidebar(
    selectedType: $credentialSelectedType,
    isSecondarySidebarCollapsed: $isSecondarySidebarCollapsed
)
```

- [ ] **Step 3: Add collapsed credential rail**

In `CredentialContextSidebar.body`:

```swift
Group {
    if isSecondarySidebarCollapsed {
        CollapsedContextRail(title: "凭证", isCollapsed: $isSecondarySidebarCollapsed)
            .frame(width: collapsedSecondarySidebarWidth)
    } else {
        CredentialSidebar(
            selectedType: $selectedType,
            credentials: credentialStore.credentials,
            status: credentialStore.status,
            isSecondarySidebarCollapsed: $isSecondarySidebarCollapsed
        )
        .frame(width: secondarySidebarWidth)
        .background(AppTheme.workspaceTokens.contextSidebar)
    }
}
```

- [ ] **Step 4: Remove search field from credential sidebar**

Change `CredentialSidebar` signature to:

```swift
struct CredentialSidebar: View {
    @Binding var selectedType: CredentialType?
    let credentials: [CredentialItem]
    let status: CredentialVaultStatus
    @Binding var isSecondarySidebarCollapsed: Bool
}
```

Replace its manual header with:

```swift
WorkspaceContextHeader(
    title: "凭证",
    subtitle: "账号、密码、Key、证书",
    isCollapsed: $isSecondarySidebarCollapsed
)
```

Delete the `SearchField(text: $searchText)` block from the sidebar body.

- [ ] **Step 5: Put credential local search in content toolbar**

In `CredentialWorkspaceContent`, add:

```swift
@Binding var searchText: String
```

Pass it from `CredentialsModuleView.body`:

```swift
CredentialWorkspaceContent(
    credentialSubtitle: credentialSubtitle,
    status: credentialStore.status,
    requiresMasterPassword: credentialStore.requiresMasterPassword,
    notice: credentialActions.notice,
    searchText: searchTextBinding,
    content: { content },
    onNew: openNewCredential,
    onLock: { credentialStore.lock() }
)
```

In the toolbar, render:

```swift
if status == .unlocked {
    WorkspaceSearchField(text: $searchText, placeholder: "搜索标题、账号、服务或标签")
        .frame(maxWidth: 280)

    Button(action: onNew) {
        Label("新建凭证", systemImage: "plus")
            .font(.system(size: 12, weight: .bold))
    }
    .buttonStyle(.tactilePlain)

    if requiresMasterPassword {
        Button(action: onLock) {
            Label("锁定", systemImage: "lock.fill")
                .font(.system(size: 12, weight: .bold))
        }
        .buttonStyle(.tactilePlain)
    }

    if let notice {
        Label(notice.message, systemImage: notice.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(notice.isError ? TodoPriority.high.displayColor : AppTheme.workspaceTokens.accent)
            .lineLimit(1)
    }
}
```

- [ ] **Step 6: Align list row surface**

In `CredentialListRow`, reduce corner radius to 8 and use token surfaces:

```swift
.background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(isSelected ? AppTheme.workspaceTokens.accent.opacity(0.28) : AppTheme.workspaceTokens.hairline.opacity(isHovered ? 0.92 : 0.55))
)
```

Set:

```swift
private var rowBackground: Color {
    if isSelected { return AppTheme.workspaceTokens.listRowSelected }
    if isHovered { return AppTheme.workspaceTokens.listRowHover }
    return AppTheme.workspaceTokens.listRow
}
```

- [ ] **Step 7: Verify lock boundary**

Run:

```bash
swift build
scripts/run_quality_checks.sh
```

Manual verification:

```text
Open credentials while locked: sidebar type list is visible, content shows unlock panel, no sensitive fields are visible.
Unlock credentials: toolbar search filters list, global search can jump to a credential, sensitive fields remain hidden until View/Copy.
```

- [ ] **Step 8: Commit**

```bash
git add Sources/DailyTodos/CredentialViews.swift Sources/DailyTodos/ContentView.swift
git commit -m "refactor: align credentials workspace"
```

---

### Task 6: Theme And Interaction Regression Pass

**Files:**
- Modify: `Sources/DailyTodos/AppTheme.swift`
- Modify: `Sources/DailyTodos/WorkspaceShellViews.swift`
- Modify: `Sources/DailyTodos/HandbookDetailPanel.swift`
- Modify: `Sources/DailyTodos/HandbookMarkdownEditor.swift`
- Modify: `Sources/DailyTodos/CredentialViews.swift`

**Interfaces:**
- Consumes: all prior workspace primitives.
- Produces: theme consistency and focus-preserving interaction polish.

- [ ] **Step 1: Remove layout-changing skin branches**

Search for skin-specific layout changes:

```bash
rg -n "AppSkin\\.current|activeAppSkin|cornerRadius|shadow|frame\\(width|frame\\(height" Sources/DailyTodos
```

Only color selection in `AppTheme` should depend on `AppSkin.current`. If a view branches by skin to change spacing, width, height, corner radius, shadow, or structure, replace that branch with fixed workspace values.

- [ ] **Step 2: Keep autosave focus stable**

Inspect `HandbookDetailPanel` and `HandbookMarkdownEditor` for `.id(item.id)` on editor fields or state reset during body updates. If an editor field uses `.id(item.id)` on text input, remove it from the input view and place identity on the outer detail panel only.

Expected editor rule:

```swift
TextEditor(text: $body)
    .textFieldStyle(.plain)
```

No `TextEditor(...).id(item.updatedAt)` or `TextField(...).id(item.updatedAt)` should exist.

- [ ] **Step 3: Normalize text contrast**

Search:

```bash
rg -n "mutedInk\\.opacity\\(0\\.[0-5]|secondaryText\\.opacity\\(0\\.[0-5]" Sources/DailyTodos
```

For primary readable labels, replace with `AppTheme.workspaceTokens.textSecondary`. For helper text, use `AppTheme.workspaceTokens.textMuted` without opacity below `0.72`.

- [ ] **Step 4: Verify theme switching**

Run the app locally:

```bash
swift run DailyTodos
```

Manual check:

```text
Switch ocean, aurora, board, leafcutter, workspace.
Confirm left rail width, left-2 width, collapsed rail width, header height, toolbar height, and list row structure do not move.
Confirm only palette changes.
```

- [ ] **Step 5: Full verification**

Run:

```bash
swift build
scripts/run_quality_checks.sh
python3 scripts/release_version_guard.py --self-test
git diff --check
```

Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/DailyTodos/AppTheme.swift Sources/DailyTodos/WorkspaceShellViews.swift Sources/DailyTodos/HandbookDetailPanel.swift Sources/DailyTodos/HandbookMarkdownEditor.swift Sources/DailyTodos/CredentialViews.swift
git commit -m "fix: normalize workspace themes and focus"
```

---

## Self-Review

- Spec coverage: tasks cover global search, left-2 header consolidation, right content header consolidation, Todos/Handbook/Credentials layout, old skin palette mapping, focus stability, and verification.
- No account login, Billing, remote sync, SQLite replacement, AI semantic search, or vector search is included.
- Placeholder scan: no `TBD`, `TODO`, `待定`, or “implement later” content is intentionally left.
- Type consistency: `GlobalSearchResult`, `GlobalSearchTarget`, `GlobalCommandSearchContext`, and `Workspace*` component names are defined before use in later tasks.
- Risk note: `Command-K` focus in SwiftUI macOS may need the hidden keyboard-shortcut button fallback described in Task 3 if direct focus bridging is not accepted by the compiler.
