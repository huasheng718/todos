# Handbook Architecture Optimization Plan

## Objective

Make Handbook feel like a commercial-grade notes workspace: category clicks and note selection must respond immediately, duplicated-looking data must be understandable, and the architecture must be ready for later iPad/iOS and sync work.

## Current Problems

1. Full `HandbookItem` objects drive every column. Sidebar, list, and detail all read the same body-heavy array.
2. Derived data is recomputed inside SwiftUI views. Category counts, folder counts, list filtering, sorting, grouping, and cache keys are view work.
3. Scope and selection are coupled. Changing category/folder can replace the selected detail unexpectedly.
4. List rows carry full note bodies even though rows only need summary fields.
5. SQLite fetches body and attachment JSON for list navigation.
6. Duplicate titles are real data, but the UI does not expose enough metadata to distinguish them.
7. Legacy Handbook views still exist and make the module harder to reason about.

## Target Architecture

```
SQLite / current local store
        |
        v
HandbookRepository protocol
        |
        +--> Sidebar index: total, category counts, folder counts
        +--> Note summaries: id, title, preview, scope, dates, attachment count
        +--> Note detail: body, attachments, editable metadata
        |
        v
HandbookWorkspaceViewModel
        |
        +--> scope: category/folder/search
        +--> selectedNoteID
        +--> sidebar index
        +--> grouped list summaries
        +--> selected detail
        |
        v
SwiftUI views render already-derived data
```

## Phase 1: Summary/Detail Split

Goal: remove body-heavy list rendering while keeping the current local SQLite store.

Deliverables:
- Add `HandbookNoteSummary`, `HandbookSidebarIndex`, `HandbookScope`, and lightweight grouped row models.
- Build summaries from the current in-memory store first, then move SQLite queries behind a repository boundary.
- List rows must not retain full `HandbookItem`.
- Duplicate titles must show differentiating metadata: time, preview, folder, and stable ID-backed selection.

Acceptance:
- Category/folder scope rebuild works from summaries.
- Selecting a note passes an ID, not a full item payload.
- Existing quality checks still pass.

## Phase 2: Repository Boundary

Goal: make Handbook data access portable and sync-ready.

Deliverables:
- Introduce `HandbookRepository` protocol.
- Add current local implementation backed by `TodoStore`/SQLite.
- Expose `fetchSidebarIndex`, `fetchNoteSummaries`, `fetchNoteDetail`, `updateNote`, `deleteNote`, and `moveNote`.
- Add sync-ready fields in the model plan: reuse existing `updatedAt` as the modified timestamp, plus `deletedAt`, `syncVersion`, `remoteID`, and `dirtyFields`.

Acceptance:
- UI no longer reaches directly into all `store.handbookItems` for sidebar/list derivation.
- Detail loads by selected ID.
- Repository can later be implemented by CloudKit or server sync without changing views.

## Phase 3: Workspace ViewModel

Goal: remove interaction work from SwiftUI body evaluation.

Deliverables:
- Add `HandbookWorkspaceViewModel` as the single state coordinator.
- Scope changes update visual selection immediately, then rebuild summaries asynchronously.
- Keep selected note if still visible. If not visible, clear detail instead of auto-selecting the first row.
- Detail sync and autosave must not trigger list rebuild unless summary fields changed.

Acceptance:
- Category click gives immediate active state feedback.
- List updates without blocking the click path.
- Note selection updates highlight immediately and detail follows predictably.
- Creating a note moves scope to the created note's category/folder, so the sidebar, list, and detail stay aligned.
- List snapshots preserve the store-provided order; autosave updates summary text without making rows jump.

## Phase 4: UI Semantics

Goal: make data relationships obvious.

Deliverables:
- Rename left "标签" area to "二级目录" unless true many-to-many tags are added.
- Show duplicate notes as independent notes with time and preview.
- Avoid showing the same category/folder information redundantly across all columns unless it helps disambiguation.
- Add empty states for no selection, no notes in scope, and loading detail.

Acceptance:
- A user can tell whether they are clicking a category, folder, list note, or note metadata.
- Duplicate titles no longer look like a rendering bug.

## Phase 5: Cleanup and Package Direction

Goal: reduce long-term architecture debt.

Deliverables:
- Remove or quarantine unused legacy Handbook views after the new workspace is stable.
- Prepare Package target split:
  - `DailyTodosCore`: models, parser, repository protocols, use cases.
  - `DailyTodosMacApp`: SwiftUI/AppKit UI.
  - `DailyTodosChecks`: quality checks.
- Keep AppKit imports out of Core.

Acceptance:
- Package graph has a clear path to iPad/iOS.
- Shared models and use cases are not tied to macOS UI.

## Verification Gates

Run before shipping:

```bash
swift build
swiftc -parse-as-library Sources/DailyTodos/TodoItem.swift Sources/DailyTodos/HandbookItem.swift Sources/DailyTodos/TodoQuickInputParser.swift Sources/DailyTodos/AppStateModels.swift Sources/DailyTodos/ViewDerivedModels.swift Sources/DailyTodos/HandbookRepository.swift Sources/DailyTodos/HandbookWorkspaceViewModel.swift Sources/DailyTodos/PerformanceMonitor.swift Sources/DailyTodos/TodoStore.swift Sources/DailyTodos/AppUpdateAvailability.swift Sources/DailyTodos/AppUpdateDownloadProgress.swift scripts/quality_checks.swift -o /tmp/DailyTodosChecks
/tmp/DailyTodosChecks
git diff --check
```

Performance evidence:
- Add checks that list snapshot rows do not retain full body payload.
- Add checks that scope changes preserve selection or clear it predictably.
- Use signposts already emitted by `PerformanceMonitor` to compare category click and row select timing before release.
