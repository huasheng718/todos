# 蚁序命令型工作台重设计

## 背景

蚁序 1.2.20 已经完成全应用工作台 shell：待办、手记、凭证、设置、账户都进入了统一的左一模块栏、左二上下文侧栏和右侧内容区。这个方向正确，但当前体验仍停在“结构统一”，还没有做到“交互和视觉统一”。

本轮审查发现三个核心问题：

1. 顶栏“搜索蚁序 / ⌘K”只是输入框，占位感强，没有分发到待办、手记、凭证，也没有结果面板或快捷键聚焦。
2. 左二和右侧内容区各自有标题、副标题、收缩按钮、工具条，位置不稳定，形成了截图中被标记的视觉断点。
3. 旧主题仍然影响布局观感、圆角、阴影、透明度和模块气质，导致不同模块像多个历史版本拼在一起。

本设计把蚁序推进到“命令型工作台”：顶栏负责跨模块命令和全局搜索，左二负责当前模块上下文，右侧负责当前任务流。旧风格只保留为配色主题，不再改变布局语言。

## 目标

1. 把顶栏搜索改成真实可用的全局命令搜索，支持 `Command-K` 聚焦、跨模块搜索、结果分组和跳转。
2. 统一左二头部，把标题、副标题、展开/收缩按钮收纳到同一个 header 中。
3. 统一右侧内容头部，把当前视图标题、副标题和局部操作规范到固定区域。
4. 重设计待办、手记、凭证的页面结构，使三者共享工作台信息架构。
5. 让 `ocean`、`aurora`、`board`、`leafcutter`、`workspace` 都适配新框架：只作为主题 palette，不再产生旧版布局风格。
6. 保持业务逻辑和数据存储稳定，不在本轮重构 SQLite、同步 schema、AI 解析或凭证加密策略。

## 非目标

本轮不做以下内容：

- 不实现远端同步、账户登录、Billing 支付或团队空间。
- 不替换 SQLite，不改 repository 协议边界。
- 不重写手记编辑器 autosave 机制，只修正 UI 结构和焦点稳定性相关调用。
- 不新增复杂 AI 搜索、语义搜索或向量索引。
- 不复制截图中的具体项目管理业务字段。
- 不把老主题删除；只把老主题统一纳入新工作台视觉系统。

## 用户与任务模型

主要用户是部门经理或项目负责人。典型任务不是“浏览漂亮页面”，而是：

- 早上打开应用，快速知道今天、逾期、等待反馈和全部任务。
- 在会议或沟通中用一句话快速记录事项。
- 从大量手记里找业务规则、会议结论、调研资料。
- 需要时从凭证库快速定位账号、Key、证书，复制敏感字段。
- 在不知道内容属于哪个模块时，直接使用全局搜索定位。

设计要优先服务高频扫读、低误触、快速定位和长时间阅读。

## 总体结构

全应用保持四层布局：

```text
AppWindow
├── GlobalTopBar
└── WorkspaceShell
    ├── ModuleRail
    ├── ContextSidebar
    │   ├── WorkspaceContextHeader
    │   └── ContextNavigation
    └── WorkspaceContent
        ├── WorkspaceContentHeader
        ├── WorkspaceLocalToolbar
        └── ContentBody
```

### GlobalTopBar

GlobalTopBar 是全应用层，不承载当前模块局部筛选。

内容：

- 左侧：Logo、蚁序、空间名称。
- 中间：全局命令搜索框。
- 右侧：AI 入口、更新入口、设置入口、账户头像。

规则：

- 高度固定 52。
- 顶栏搜索必须有真实行为，不能只做视觉占位。
- `Command-K` 聚焦全局搜索。
- 搜索框为空时展示“搜索蚁序”；输入后打开结果浮层。
- 右侧 AI 入口如果没有实际行为，要降级为 disabled 或隐藏，不能制造假入口。

### WorkspaceContextHeader

左二头部统一使用 `WorkspaceContextHeader`，解决截图中标题、副标题、收缩按钮散落的问题。

结构：

```text
WorkspaceContextHeader
├── VStack
│   ├── title
│   └── subtitle
└── collapseButton
```

规则：

- 高度 52。
- 标题 15 / bold，副标题 11 / semibold。
- 收缩按钮位于右侧，和标题同一头部区域。
- 收缩按钮只负责左二展开/折叠，不漂浮在分割线中部。
- 折叠状态下显示窄 rail：模块短名、展开按钮、必要图标。

各模块文案：

```text
待办 title: 待办
待办 subtitle: 今日、等待、固定、全部

手记 title: 手记
手记 subtitle: 规则、调研、会议、灵感

凭证 title: 凭证
凭证 subtitle: 账号、密码、Key、证书

设置 title: 设置
设置 subtitle: 外观、AI、更新、安全
```

### WorkspaceContentHeader

右侧内容头部统一使用 `WorkspaceContentHeader`。

结构：

```text
WorkspaceContentHeader
├── title
├── subtitle
└── optional actions
```

规则：

- 高度固定 56。
- 只描述当前视图，例如“全部待办”“业务规则”“凭证”。
- 不重复左二已有的统计。
- 不放搜索框，搜索和视图切换进入 `WorkspaceLocalToolbar`。
- 头部不使用卡片，不加大圆角，不用阴影。

### WorkspaceLocalToolbar

局部工具条服务当前内容区。

待办：

- 局部搜索：搜索标题或备注。
- 视图切换：紧凑、分组、看板、四象限。
- 可选筛选：状态、优先级。

手记：

- 局部搜索：搜索标题或正文。
- 新建手记。
- 排序或视图入口。

凭证：

- 局部搜索：搜索标题、账号、服务、标签。
- 新建凭证。
- 锁定或安全状态入口。

规则：

- 高度最小 44。
- 搜索框和 segmented control 使用同一套尺寸、半径、hover、focus 状态。
- 不出现“顶栏全局搜索 + 工具条局部搜索 + 列表头局部搜索”的三重重复。

## 全局命令搜索

全局搜索是本轮 P1 功能。

### 触发

- 点击顶栏搜索框。
- `Command-K`。
- 输入任意非空字符。

### 搜索范围

第一阶段搜索本地已加载数据：

- 待办：标题、备注、优先级、状态、日期文本。
- 手记：标题、正文预览、分类、二级目录、附件名。
- 凭证：标题、账号、服务 URL、类型、标签。敏感字段不进入全局搜索。

如果手记尚未加载，打开搜索时触发 `scheduleLoadHandbookItemsIfNeeded()`，结果面板显示手记加载状态。

### 结果面板

结果浮层锚定在顶栏搜索框下方。

结构：

```text
GlobalSearchPanel
├── Search status / hint
├── Todos results
├── Handbook results
└── Credential results
```

规则：

- 每组最多显示 5 条，更多时显示“查看全部”。
- 每条结果包含图标、标题、副信息、模块标签。
- 键盘上下选择，回车跳转。
- Escape 关闭结果面板。
- 无结果时显示建议：检查关键词、切换模块局部搜索、新建内容。

### 跳转行为

待办结果：

- 激活待办模块。
- 如果目标日期明确，切到对应 day scope；否则切到全部待办。
- 高亮并滚动到目标待办。

手记结果：

- 激活手记模块。
- 设置对应 category/folder。
- 选择目标手记。

凭证结果：

- 激活凭证模块。
- 设置类型筛选。
- 选择目标凭证。
- 不自动 reveal 敏感字段。

### 与局部搜索的关系

- 全局搜索：跨模块定位和跳转。
- 局部搜索：过滤当前列表。
- 全局搜索提交跳转后，不应污染当前模块局部搜索框，除非用户点击“在当前模块筛选此关键词”。

## 待办重设计

### 左二

左二保留截图中的分组逻辑，但统一 header。

顺序：

1. Header：待办 / 今日、等待、固定、全部 / 收缩按钮。
2. 主要导航：今日推进、等待反馈、本周固定、全部待办。
3. 快速日期：最近 7 天。
4. 有记录：年月控制 + 小日历。
5. 底部摘要：待办 / 未完成 N · 逾期 N。

规则：

- 导航项整行可点击。
- 每项最多一个数字徽标。
- 副标题只解释场景，不重复统计。
- 年和月仍分开，但不能出现两个下拉 icon 造成重复感。
- 快速日期和小日历必须保持固定尺寸，hover/选中不撑动布局。

### 右侧

结构：

1. ContentHeader：当前视图标题和说明。
2. LocalToolbar：局部搜索 + 视图切换。
3. QuickCaptureBar。
4. TodoList。

规则：

- QuickCaptureBar 是高频动作，但不应像大表单压过列表。
- 列表行保持紧凑，标题优先，备注换行不超过 4 行。
- 逾期使用红色背景/边框/文字共同表达，不能只靠颜色。
- 完成项降低视觉权重，但仍可读。

## 手记重设计

手记继续接近 macOS Notes 的模型，但必须去掉层级混乱和重复入口。

### 左二

顺序：

1. Header：手记 / 规则、调研、会议、灵感 / 收缩按钮。
2. 来源：全部手记。
3. 分类：业务规则、调研、会议、灵感。
4. 标签：二级目录作为 tag，不再像深层目录树。

规则：

- 分类默认可见，不需要反复展开。
- 二级目录使用标签，选中后过滤右侧列表。
- 拖拽修改分类保留，但要有明确 hover/drop 反馈。

### 右侧

结构：

```text
WorkspaceContent
├── ContentHeader: 当前分类/全部手记
├── LocalToolbar: 搜索 + 新建 + 排序
└── HSplit
    ├── NotesList
    └── Editor
```

规则：

- 搜索只保留在 LocalToolbar 或 NotesListHeader 二选一。推荐放在 NotesListHeader；若使用 LocalToolbar，NotesListHeader 不再重复搜索。
- NotesList 只负责扫描和选择。
- Editor 顶部工具栏收纳附件、格式、删除等操作。
- autosave 不出现保存按钮，最多显示轻量状态：已保存 / 正在保存。
- 编辑焦点不能因 autosave 或同一 item 回写丢失。
- 空状态明确：选择一条手记阅读 / 新建手记。

## 凭证重设计

凭证要从“独立安全工具页”统一成工作台信息管理页，同时保持安全边界。

### 左二

顺序：

1. Header：凭证 / 账号、密码、Key、证书 / 收缩按钮。
2. 类型：全部、账号、密码、Key、证书、其他。
3. 状态：已解锁、已锁定、风险检查入口。
4. 底部安全提示。

规则：

- 搜索不放左二，放右侧工具条或列表头，避免和全局搜索混乱。
- 锁定状态下左二仍展示结构，但内容区显示解锁面板。

### 右侧

结构：

```text
WorkspaceContent
├── ContentHeader: 凭证
├── LocalToolbar: 搜索 + 新建凭证 + 锁定
└── HSplit
    ├── CredentialList
    └── CredentialDetail / Editor / SecuritySettings
```

规则：

- 列表行视觉和手记列表接近，不使用重阴影卡片。
- 详情区使用表格式字段，不用卡片套卡片。
- 敏感字段默认隐藏。
- 点击“查看”只显示当前凭证，不影响全局搜索。
- 复制成功要有短反馈，但不抢焦点。
- 删除必须确认。

## 主题与老风格适配

所有主题共用同一套布局、间距、圆角、阴影和组件状态。主题只覆盖颜色 token。

### 令牌层级

新增或收敛为：

```text
WorkspaceThemeTokens
├── canvas
├── topBar
├── moduleRail
├── contextSidebar
├── contentSurface
├── contentAltSurface
├── listRow
├── listRowHover
├── listRowSelected
├── hairline
├── textPrimary
├── textSecondary
├── textMuted
├── accent
├── accentSoft
├── action
├── actionSoft
├── success
├── warning
├── danger
├── focusRing
└── shadow
```

### 工作台主题

推荐浅色 token：

```text
canvas:           #F4F6F8
topBar:           #F5F6F8
moduleRail:       #EEF2F7
contextSidebar:   #F1F4F8
contentSurface:   #FFFFFF
contentAltSurface:#F8FAFC
listRow:          #FFFFFF
listRowHover:     #F4F7FB
listRowSelected:  #EAF2FF
hairline:         #E2E8F0
textPrimary:      #1E293B
textSecondary:    #475569
textMuted:        #64748B
accent:           #2563EB
accentSoft:       #EAF2FF
action:           #EA580C
actionSoft:       #FFF1E8
success:          #16A34A
warning:          #D97706
danger:           #DC2626
focusRing:        #2563EB
```

### 老主题映射

- `ocean`：保留清蓝主色，但使用新工作台布局。
- `aurora`：保留柔紫主色，但降低背景饱和度，避免儿童化。
- `board`：保留粉彩倾向，但不再使用过多卡片阴影。
- `leafcutter`：保留切叶蚁暖色，但背景不再大面积偏黄。
- `workspace`：作为默认商业化主题，优先适配长时间阅读。

规则：

- 主题不允许改变 `primarySidebarWidth`、`secondarySidebarWidth`、header 高度、toolbar 高度。
- 主题不允许改变列表行结构。
- 主题不允许引入装饰性渐变、orb、bokeh 或大面积插画。

## 组件清单

建议新增或改造：

- `WorkspaceContextHeader`
- `CollapsedContextRail`
- `WorkspaceContentHeader`
- `WorkspaceLocalToolbar`
- `WorkspaceSearchField`
- `GlobalCommandSearchPanel`
- `GlobalSearchResultRow`
- `WorkspaceThemeTokens`
- `WorkspaceSegmentedControl`
- `WorkspaceListRowSurface`

建议收敛：

- `ContentHeader` -> `WorkspaceContentHeader`
- `ContentToolbar` -> `WorkspaceLocalToolbar`
- `SearchField` -> `WorkspaceSearchField`
- `CollapsedSecondarySidebarRail` -> `CollapsedContextRail`

## 验收标准

### 功能

- `Command-K` 可以聚焦全局搜索。
- 全局搜索输入关键词后出现结果面板。
- 待办、手记、凭证结果可点击并跳转到对应模块和目标记录。
- 全局搜索不会污染模块局部搜索。
- 手记尚未加载时，全局搜索能触发加载并展示加载状态。

### 布局

- 左二标题、副标题、收缩按钮位于同一 header。
- 右侧标题、副标题位于固定内容 header。
- 待办、手记、凭证都使用统一 header + toolbar + body 结构。
- 老主题下布局不变化，只颜色变化。
- 在 1100px 最小宽度下，文本不互相遮挡。

### 视觉

- 主文字对比度满足长时间阅读。
- 次文字不可过浅。
- 选中态、hover、focus、disabled 状态清楚可分。
- 凭证列表和手记列表不再像两个不同产品。
- 不出现卡片套卡片。

### 交互

- 搜索、切换模块、选择手记、编辑正文不应明显卡顿。
- 手记 autosave 不抢焦点。
- 凭证复制反馈不抢焦点。
- Escape 关闭全局搜索面板。

### 验证命令

```bash
swift build
scripts/run_quality_checks.sh
python3 scripts/release_version_guard.py --self-test
git diff --check
```

后续如加入 UI 自动化，应补充以下手工/自动测试任务：

1. `Command-K` 搜索一个待办标题并跳转。
2. `Command-K` 搜索一条手记正文并跳转。
3. `Command-K` 搜索一个凭证服务名并跳转，但不 reveal 敏感字段。
4. 切换所有主题，确认布局尺寸不变化。
5. 在手记正文连续输入 30 秒，确认焦点不丢失。

## 实施建议

推荐分四个提交实施：

1. `feat: add workspace header and theme tokens`
   - 抽统一 header、toolbar、search field 和 theme token。
   - 不改业务数据流。

2. `feat: implement global command search`
   - 建立搜索结果模型和面板。
   - 接入待办、手记、凭证跳转。

3. `refactor: align todos and handbook workspace layout`
   - 待办和手记套用新 header/toolbar。
   - 删除重复搜索和漂浮收缩按钮。

4. `refactor: align credentials and legacy skins`
   - 凭证改为统一列表/详情视觉。
   - 老主题映射到新 token。

## 设计自检

- 没有 TBD 或 TODO。
- 没有要求实现账户、Billing 或同步。
- 全局搜索从占位变为真实功能。
- 截图反馈中的标题、副标题、收缩按钮已明确收纳到左二头部。
- 老主题适配被限定为 token 映射，不再扩散成多套布局。
