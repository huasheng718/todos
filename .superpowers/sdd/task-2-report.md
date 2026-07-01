Status: DONE_WITH_CONCERNS
Commits created: pending
One-line test summary: `swift build` passed; `git diff --check` passed.
Concerns: The local Swift toolchain in this workspace does not expose `XCTest` or `Testing`, so I could not add executable search-engine tests without widening toolchain/package setup; Task 2 was completed with compile verification only.
Report file path: /Users/wusheng/Documents/cuke-think/loop-engineering/.loop/workspaces/daily-todos-handbook-sidebar-tags/daily-todos/.superpowers/sdd/task-2-report.md

## Fix after review

- Updated credential global search policy in `Sources/DailyTodos/GlobalCommandSearch.swift` to match only `title`, `type.title`, and curated `tags`.
- Removed credential global-search indexing and display use of `username`, `serviceURL`, and `displayService`.
- Credential global-search result detail now returns either `敏感字段默认隐藏` or a capped `标签：...` summary from visible tags only.
- The global-search fix does not decrypt credentials or inspect secret payloads.
- Executable tests were not added: this package defines only an executable target in `Package.swift`, with no existing test target and no lightweight in-package self-test harness for `GlobalCommandSearch`. Verification is recorded via command results below.

### Command results

- `swift build`: passed
- `git diff --check`: passed
- `scripts/run_quality_checks.sh`: passed (`DailyTodosChecks passed`)
