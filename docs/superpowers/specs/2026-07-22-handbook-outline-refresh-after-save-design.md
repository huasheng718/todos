# Handbook Outline Refresh After Save

## Problem

The handbook body editor and the Markdown outline currently observe the same
`HandbookEditorState`. The state publishes both body metrics and outline entries.
When outline extraction publishes a new value, SwiftUI invalidates every view that
observes the shared object, including `HandbookBodyEditorSection`. That can rebuild
the `NSViewRepresentable` path around the active `NSTextView` and interrupt typing.

The existing 100 ms body-metrics task also extracts and publishes the outline while
the user is typing. Moving the properties out of the parent detail panel reduced the
scope of invalidation, but it did not isolate the editor from outline notifications.

## Desired Behavior

- Continuous body input must not trigger outline extraction or publication.
- The outline refreshes after the 650 ms autosave completes.
- Leaving the editor triggers the existing forced save and then refreshes the outline.
- Opening or switching to a handbook item immediately shows the outline for its stored
  body.
- Body metrics may continue updating during input because they drive character count
  and editor height.
- Saving, outline extraction, and outline rendering must not replace the active text
  editor or reset its selection.

## Design

### State Isolation

Keep `HandbookEditorState` responsible for editor-only state:

- dirty state;
- body metrics;
- the body-metrics task;
- the autosave task.

Move outline entries into a separate `HandbookOutlineState`. Only
`HandbookOutlineContainer` observes that object. `HandbookBodyEditorSection` and
`HandbookEditableCanvas` continue to observe `HandbookEditorState` and therefore do
not receive outline-change invalidations.

### Refresh Boundaries

Split the current combined metrics-and-outline work into two paths:

1. `scheduleBodyMetricsUpdate` runs after body input and updates only body metrics.
2. `refreshOutline` extracts headings and publishes entries only at a persistence
   boundary.

`syncDraft` refreshes the outline from the stored body when an item is first loaded or
when selection changes. `submitEdit` captures the current editor text, calls the
existing synchronous `onUpdate` persistence closure, and refreshes the outline from
that same saved text after the closure returns. This covers both the debounced
autosave and the forced save when focus leaves the editor.

Outline extraction remains off the main actor. Publication returns to the main actor,
checks that the requested item is still selected, and ignores an obsolete result if
the user switched items while extraction was running.

### Failure Behavior

The existing update callback does not expose a throwing result, so successful return
continues to define the persistence boundary. A cancelled or obsolete outline task
does not affect saved text, dirty state, focus, or selection; it only leaves the last
saved outline visible until the next refresh boundary.

## Verification

Add a regression guard to the existing DailyTodos quality checks that proves:

- outline entries are no longer published by `HandbookEditorState`;
- the body-input metrics path does not extract or publish an outline;
- the outline is refreshed by initial draft synchronization and by `submitEdit`;
- the body editor does not observe the new outline state.

Run:

```bash
XDG_CACHE_HOME=/tmp/daily-todos-outline-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-outline-cache/clang \
SWIFT_MODULE_CACHE_PATH=/tmp/daily-todos-outline-cache/swift \
./scripts/run_quality_checks.sh /tmp/DailyTodosOutlineChecks

XDG_CACHE_HOME=/tmp/daily-todos-outline-build-cache \
CLANG_MODULE_CACHE_PATH=/tmp/daily-todos-outline-build-cache/clang \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/daily-todos-outline-build-cache/swiftpm \
swift build --disable-sandbox --scratch-path /tmp/daily-todos-outline-swift-build
```

## Acceptance Criteria

- Typing continuously in a handbook body does not refresh the outline.
- The outline reflects saved headings after autosave or after leaving the editor.
- Opening or switching handbook items shows the stored outline immediately.
- The insertion point and active input session remain intact while typing.
- The focused quality checks and Swift build pass with the compatible Command Line
  Tools configuration above.
