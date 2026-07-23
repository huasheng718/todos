# Handbook Outline Refresh on Body Blur

## Problem

The `v1.2.39` fix separated outline state from editor state, but it still treats
every save as an outline refresh boundary. The 650 ms autosave calls
`submitEdit`, and `submitEdit` always calls `refreshOutline`. Attachment,
category, and folder updates use the same path. As a result, outline extraction
and publication can still occur while the body editor owns focus and interrupt
continuous input.

The current focus handler also saves only when the entire canvas loses focus.
Moving from the body editor to the title does not satisfy that condition even
though the body editor has been left.

## Desired Behavior

- Body input may autosave after 650 ms, but autosave must not extract or publish
  the outline.
- The outline refreshes when the body editor loses focus, including a focus move
  from body to title.
- Attachment, category, folder, title, image-paste, and legacy-cleanup saves do
  not refresh the outline while body focus remains active.
- Opening or switching to an item immediately loads the outline for that item's
  stored body.
- Switching away from an item persists its latest draft. The selected item's
  initial synchronization owns the visible outline after the switch.
- Existing item-ownership checks and cooperative cancellation continue to block
  obsolete outline work from publishing into the selected item.

## Design

### Explicit Refresh Policy

Add an explicit outline refresh policy to `submitEdit`. Persistence and outline
publication are separate effects:

- `.preserveOutline` saves the current draft and clears dirty state without
  invoking `refreshOutline`.
- `.refreshOutline` saves the same captured body and then invokes
  `refreshOutline` for the saved item.

The default policy is `.preserveOutline`, so new save call sites cannot
accidentally resume outline publication during editing. Only the body-blur path
passes `.refreshOutline`.

### Focus Boundary

Replace the canvas-wide blur condition with a body-specific transition:

```swift
oldValue == .body && newValue != .body
```

This condition covers body-to-title and body-to-no-focus transitions. It does
not refresh for title-to-body, title-to-no-focus, or unrelated state changes.
When it matches, cancel the pending autosave through the existing `submitEdit`
flow, synchronously persist the latest editor text, and refresh the outline from
that exact saved snapshot.

### Other Save Paths

The following paths persist with `.preserveOutline`:

- debounced body and title autosave;
- item switching before the new draft is synchronized;
- attachment, category, and folder changes;
- pasted-image attachment persistence;
- legacy pasted-image cleanup.

`syncDraft` remains an explicit outline-loading boundary. It refreshes from the
stored body when an item first appears or the selection changes. This ensures the
visible outline always belongs to the selected item without requiring a refresh
of the item being left.

### Cancellation and Failure Behavior

`refreshOutline` keeps its existing cancellation handler and selected-item ID
guard. A cancelled or obsolete extraction cannot change persistence, dirty state,
focus, or selection. The save callback is synchronous and non-throwing, so a
normal return remains the persistence boundary before an allowed refresh.

## Verification

Extend the existing quality checks with a source-level regression guard that
proves:

- `submitEdit` defaults to preserving the outline;
- the 650 ms autosave path cannot request an outline refresh;
- the focus handler recognizes body-to-title and body-to-no-focus transitions;
- only that body-blur handler requests `.refreshOutline`;
- initial item synchronization still invokes `refreshOutline`;
- the existing selected-item guard and cancellation handler remain present.

Follow test-driven development: add the guard first and record its failure
against the current unconditional refresh, then make the smallest production
change and rerun it to green. Finally run the complete quality suite and Swift
build with the compatible macOS 15.4 SDK and isolated module caches.

## Acceptance Criteria

- Continuous typing for longer than 650 ms persists content without changing
  the visible outline or interrupting input.
- Clicking the title after editing body text saves the latest body and refreshes
  the outline once.
- Clicking outside the editor after editing body text saves the latest body and
  refreshes the outline once.
- Title-only editing and metadata changes do not refresh the outline.
- Opening or switching items immediately shows the selected item's stored
  outline and never publishes results from the previous item.
- Focused regression checks, the complete quality suite, and `swift build` pass.

## Release Scope

Ship this correction as the next patch version after `v1.2.39`, including the
source change, regression guard, package artifacts, pushed branch, pull request,
GitHub release, and merge after verification.
