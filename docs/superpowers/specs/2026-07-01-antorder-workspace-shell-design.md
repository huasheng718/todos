# 蚁序全应用工作台布局设计

## 背景

蚁序已经从单一待办工具扩展到待办、手记、凭证、设置等模块，并且后续需要具备商业化、账户、Billing、iPad/iOS 适配和同步能力。当前应用已有左侧模块栏、二级侧栏和主内容区，但不同模块的顶栏、导航层级、工具条和内容密度不统一，导致产品感偏“多个页面拼接”，也影响后续扩展。

本设计借鉴用户提供截图中的工作台结构和低饱和浅灰配色，只调整布局和新增一套风格，不复制截图内容、品牌或业务模型。

## 目标

1. 全应用统一为“蚁序工作台”结构，让待办、手记、凭证、设置共享一致的信息架构。
2. 新增一套克制、商业化、适合长时间阅读和办公使用的浅色主题。
3. 保持现有业务数据、存储、同步准备和核心交互不变，降低改造风险。
4. 为账户、Billing、团队空间、全局搜索、跨端导航预留稳定入口。
5. 减少页面层级混乱、重复入口和内容区域不满的问题。

## 非目标

本次不做以下内容：

- 不重构 SQLite、本地仓储、同步 schema。
- 不实现真实账户、Billing、团队协作或远端同步。
- 不改待办解析、手记 autosave、凭证复制等业务逻辑。
- 不新增复杂动画或大规模组件重写。
- 不把截图中的项目管理字段直接搬进蚁序。

## 目标结构

全应用统一为四层布局：

```text
AppWindow
├── GlobalTopBar
└── WorkspaceShell
    ├── ModuleRail
    ├── ContextSidebar
    └── WorkspaceContent
        ├── ContentHeader
        ├── ContentToolbar / Tabs
        └── ContentBody
```

### GlobalTopBar

GlobalTopBar 是应用级能力入口，固定在窗口顶部。

内容：

- 左侧：蚁序 Logo、空间名称，默认显示“个人空间”。
- 中间：全局搜索输入框，第一阶段可以只作为 UI 入口，搜索仍委托各模块现有搜索逻辑。
- 右侧：AI 入口、更新状态、设置入口、账户头像占位。

规则：

- 高度建议 52。
- 使用浅灰背景和底部分割线。
- 顶栏不承载当前模块的筛选、分类或编辑动作。
- 未来账户/Billing 可以从右侧账户入口进入，不再散落在模块页面中。

### ModuleRail

ModuleRail 是一级模块导航，固定在最左侧。

模块：

- 待办
- 手记
- 凭证
- 设置
- Account/Billing 占位

规则：

- 宽度建议 68 到 76，第一阶段可沿用现有 `primarySidebarWidth`。
- 图标优先，标签短文本辅助。
- 选中态使用轻量背景和主题蓝色，不使用强阴影。
- Logo 和设置不再堆在 rail 底部，设置作为一级模块或顶栏入口统一处理。

### ContextSidebar

ContextSidebar 是当前模块的上下文导航，固定在 ModuleRail 右侧。

宽度：

- 展开宽度建议 264。
- 折叠宽度建议 48。
- 第一阶段可沿用现有 `secondarySidebarWidth`，但视觉上调整为截图风格的浅色导航面。

模块映射：

- 待办：快速新建、今天、全部、已完成、日期/项目/视图分组。
- 手记：全部手记、最近编辑、分类、二级目录、标签占位。
- 凭证：全部凭证、分类、最近复制、过期/风险分组。
- 设置：通用、外观、AI、更新、账户、Billing。

规则：

- ContextSidebar 只承载导航、筛选、分组，不承载重编辑流程。
- 当前选中项必须可见、可扫、可键盘聚焦。
- 分组标题使用低对比但可读文本，列表项点击区域要完整覆盖整行。
- 目录树默认展开到常用层级，避免用户反复展开。

### WorkspaceContent

WorkspaceContent 是主工作区。所有模块统一使用三段式：

1. ContentHeader：模块标题、当前上下文、副操作。
2. ContentToolbar / Tabs：视图切换、搜索、排序、筛选、主要创建按钮。
3. ContentBody：真实业务内容。

规则：

- 主内容背景为白色或接近白色，不再嵌套多层卡片。
- 页面 section 可以用全宽带状区域或表格式分隔，不使用装饰性浮动卡片。
- 工具条动作靠右，状态/统计靠左或跟随标题。
- 列表行保持紧凑，重要信息优先展示，辅助信息低对比展示。

## 模块落地

### 待办

待办模块保持当前业务能力，但迁移到统一壳层。

布局：

- ContextSidebar：待办导航和分组。
- ContentHeader：当前视图名称，例如“今天”“全部待办”“本周”。
- Toolbar：搜索、视图模式、筛选、新建待办。
- Body：快速输入和待办列表。

调整：

- 快速输入可以保留在列表上方，但应与工具条形成一个工作流，不再像独立卡片。
- 列表分组使用细分割线和浅灰 section header。
- 空状态、加载状态和错误状态放在 Body 内部，不打断整体 shell。

### 手记

手记模块继续接近 macOS 备忘录的使用模型，但统一到工作台 shell。

布局：

- ContextSidebar：全部手记、分类、二级目录。
- ContentHeader：当前分类或“全部手记”。
- Toolbar：新建、搜索、排序、附件/格式入口。
- Body：手记列表 + 编辑器。

调整：

- 避免出现“备忘录”等与蚁序命名不一致的文案。
- 手记列表和编辑器之间保持清晰分割线。
- 编辑器工具栏放在编辑区顶部，附件入口归入工具栏。
- autosave 状态轻量显示，不使用显眼保存按钮。

### 凭证

凭证模块从工具页调整为工作台内的信息管理页。

布局：

- ContextSidebar：分类、最近复制、过期/风险。
- ContentHeader：凭证管理。
- Toolbar：搜索、新建、筛选。
- Body：凭证列表 + 详情/复制操作。

调整：

- 复制动作优先使用行内图标按钮。
- 敏感信息默认遮挡，hover 或点击后按现有安全策略显示。
- 过期、风险、最近使用作为状态标签，不单独制造复杂面板。

### 设置

设置模块统一进入工作台 shell，不再像独立弹窗式信息堆叠。

布局：

- ContextSidebar：通用、外观、AI、更新、账户、Billing。
- ContentHeader：当前设置分组。
- Body：设置表单。

调整：

- AI 配置纳入设置页，非必要高级项默认折叠或隐藏。
- 更新下载进度保留明确百分比和状态，不出现假死感。
- Account/Billing 第一阶段只做边界占位和不可用说明，不实现真实支付。

## 新主题：工作台

新增一套 `AppSkin`，建议命名：

- raw value: `workspace`
- title: `工作台`
- short title: `工作台`
- icon: `rectangle.3.group`

浅色令牌建议：

```text
canvas:        #F4F5F7
topBar:        #F2F3F5
rail:          #EEF0F3
sidebar:       #FAFAFB
surface:       #FFFFFF
surfaceAlt:    #F7F8FA
hairline:      #E4E7EC
ink:           #24272E
secondaryText: #6B7280
mutedText:     #8A9099
accent:        #2563EB
accentSoft:    #EAF1FF
success:       #16A34A
warning:       #D97706
danger:        #DC2626
```

暗色模式不作为本次主要验收，但不能破坏现有暗色适配。工作台主题在暗色下可以先映射到现有低对比深色令牌。

## 交互原则

1. 模块切换要像工作台上下文切换，不像打开全新页面。
2. ContextSidebar 的选中、hover、focus 状态必须清楚，整行可点击。
3. 主内容优先占满空间，避免右侧内容被多层容器挤压。
4. 顶栏只放全局动作，模块动作只放模块 header/toolbar。
5. 键盘焦点不能因为 autosave、搜索 debounce 或模块重绘丢失。
6. 加载状态应局部出现，不阻塞整个 shell。
7. 所有文本对比度至少满足长时间阅读需求，主要正文不使用过浅灰色。

## 组件边界

建议新增或收敛以下 SwiftUI 组件：

- `WorkspaceShell`
- `GlobalTopBar`
- `ModuleRail`
- `ContextSidebarContainer`
- `WorkspaceContentContainer`
- `ContentHeader`
- `ContentToolbar`
- `WorkspaceSectionHeader`

现有组件迁移方向：

- `ContentView` 只负责组装 shell 和模块状态，不继续承载大量具体 UI。
- `ModuleSwitcherBar` 收敛为 `ModuleRail`。
- `AppTopBar` 收敛为模块级 `ContentHeader`，全局能力迁移到 `GlobalTopBar`。
- `TodoModuleView`、`HandbookModuleView`、`CredentialsModuleView` 只提供各自的 sidebar/content 插槽。

## 分阶段交付

### Phase 1：Shell 和主题

交付：

- 新增 `WorkspaceShell`、`GlobalTopBar`、`ModuleRail` 基础布局。
- 新增 `workspace` 主题。
- 保持待办、手记、凭证、设置当前业务视图可用。

验收：

- 全应用拥有统一顶栏、左一、左二、主内容结构。
- 模块切换无明显布局跳动。
- 现有功能入口没有丢失。

### Phase 2：模块内容适配

交付：

- 待办套入 `ContentHeader + Toolbar + Body`。
- 手记套入统一 header/toolbar，并保持列表 + 编辑器。
- 凭证和设置调整为统一工作台页面。

验收：

- 各模块不再各自维护风格差异明显的顶栏。
- 主内容区域更满，层级更少。
- 左二导航点击区和选中态稳定。

### Phase 3：交互和性能收口

交付：

- 检查模块切换、手记点击、待办输入、设置切换的焦点和加载状态。
- 为全局搜索入口预留模块路由，但不实现完整索引。
- 清理重复的 shell 旧组件。

验收：

- 手记编辑时输入法切换或短暂停顿不丢焦点。
- 模块切换和侧栏点击不出现 1 秒以上视觉卡顿。
- `swift build` 和项目质量检查通过。

## 验收标准

1. 视觉：全应用看起来属于同一个产品，不再像独立页面拼接。
2. 结构：顶栏、左一、左二、主内容的职责清晰。
3. 可用性：常用入口不超过两次点击可达。
4. 阅读：正文、列表标题、元信息对比度可读。
5. 稳定：待办新增、手记编辑、凭证复制、设置更新不受布局改造影响。
6. 扩展：Account/Billing、全局搜索、同步状态有明确入口。

## 风险和缓解

风险：一次性改全应用 shell 容易引入布局回归。
缓解：先做 shell 外壳和主题，再逐模块迁移；每阶段都保持可运行。

风险：全局顶栏和模块顶栏职责重叠。
缓解：全局顶栏只放应用级动作，模块 header 只放当前上下文动作。

风险：新增主题影响现有主题。
缓解：新增 `workspace` 作为独立 `AppSkin`，不重写现有主题令牌。

风险：手记焦点和 autosave 受重绘影响。
缓解：迁移时保持编辑器身份稳定，避免用主题或模块切换触发编辑器不必要重建。
