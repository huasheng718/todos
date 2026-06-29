# 蚁序

一款轻量 macOS 桌面待办应用，用来管理部门经理每天要推进的个人事项。

## 功能

- 默认进入「全部待办 / 紧凑模式」，优先阅读完整任务池
- 自动聚合逾期未完成、今天要推进、等待反馈、本周固定
- 添加标题、优先级、推进状态、跟进日、备注
- 支持待处理、推进中、等待他人、已完成状态
- 支持每周固定事项，完成后自动生成下周同一天事项
- 标记完成、编辑、删除
- 搜索标题或备注
- 本地 SQLite 持久化，不依赖网络服务

数据默认保存在：

```text
~/Library/Application Support/DailyTodos/todos.sqlite
```

其中 `DailyTodos` 是为了兼容旧版本数据保留的内部目录名。

如果旧版本已有 `todos.json`，首次启动会自动导入到 SQLite。

## 自动更新

应用通过 `Info.plist` 中的 `YXUpdateManifestURL` 读取远程 `latest.json`。该地址和
`downloadURL` 必须对未登录用户公开可访问；如果仓库是 GitHub Private，应用会收到
404，无法获取新版本。发布时可使用公开仓库、GitHub Pages、对象存储或其他静态文件源。

## 开发运行

```bash
swift run
```

## 质量检查

当前机器的 Command Line Tools 缺少 XCTest/Testing 模块，项目提供了轻量质量门覆盖快记解析和 SQLite 存储行为：

```bash
swiftc -parse-as-library Sources/DailyTodos/TodoItem.swift Sources/DailyTodos/HandbookItem.swift Sources/DailyTodos/TodoQuickInputParser.swift Sources/DailyTodos/AppStateModels.swift Sources/DailyTodos/ViewDerivedModels.swift Sources/DailyTodos/HandbookRepository.swift Sources/DailyTodos/HandbookWorkspaceViewModel.swift Sources/DailyTodos/PerformanceMonitor.swift Sources/DailyTodos/TodoStore.swift Sources/DailyTodos/AppUpdateAvailability.swift Sources/DailyTodos/AppUpdateDownloadProgress.swift scripts/quality_checks.swift -o /tmp/DailyTodosChecks
/tmp/DailyTodosChecks
python3 scripts/release_version_guard.py --self-test
```

## 打包为 macOS App

```bash
chmod +x scripts/package_app.sh
./scripts/package_app.sh
```

打包产物会生成在：

```text
build/蚁序.app
```

## 发布准备

先从任意 checkout 创建干净发布工作区。该命令只从 `origin/main` 创建新 worktree，不复制当前目录的脏改：

```bash
scripts/create_release_worktree.sh --version 1.1.16
cd /path/to/printed/worktree
```

功能改动必须在该 worktree 内完成并提交，再执行发布。发布脚本会拒绝脏工作区、`main` 分支、或未包含最新 `origin/main` 的分支，避免发布时再处理迁移和冲突。

```bash
scripts/ship_release.sh --version 1.1.16 --notes "蚁序 1.1.16 更新：..."
```

该命令会更新 `Info.plist` 和 `releases/latest.json`，运行 Swift 构建，生成
`build/AntOrder-<version>.pkg` 与 `build/AntOrder-<version>.dmg`，并输出 SHA256。

确认无误后可发布：

```bash
scripts/ship_release.sh --version 1.1.16 --notes "蚁序 1.1.16 更新：..." --publish --merge-pr
```

当前项目用 Swift Package + SwiftUI 实现，不需要联网安装依赖。若要获得完整 Xcode 工程体验，可以安装 Xcode 后用 Xcode 打开该目录或迁移为 `.xcodeproj`。
