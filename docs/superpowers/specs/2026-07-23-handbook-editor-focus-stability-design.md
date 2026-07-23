# Handbook Editor Focus Stability

## Problem

The handbook editor autosaves 650 ms after text changes. Persistence publishes a
new `HandbookItem`, the selected item is refreshed, and SwiftUI may update the
`NSViewRepresentable` that owns the active `NSTextView`. During that system update,
AppKit can send `textDidEndEditing` even though the user did not leave the editor.

`HandbookPastingTextEditor.Coordinator` currently treats every
`textDidEndEditing` notification as user intent and clears `.body` from the shared
focus binding. The autosave therefore persists the text correctly but can remove
the insertion point and interrupt continued input.

The previous outline fixes keep local text during same-item writeback and delay
outline publication until the body loses focus. They do not distinguish an
explicit outside click from a system-generated end-editing notification.

## Confirmed Behavior

- Body and title changes continue to autosave after 650 ms.
- Autosave must not clear `canvasFocus`, replace the active input target, move the
  insertion point, or refresh the outline.
- The editor region consists of the title, body, toolbar, and attachment area.
- Clicking inside that region keeps the editing session active. Clicking the title
  or body may normally transfer the input target between those two fields.
- Clicking the outline, handbook list, sidebar, or another module explicitly exits
  the editing session.
- An explicit exit saves the latest draft, refreshes the outline from that exact
  saved body, and then clears editor focus.
- Opening or selecting a different item continues to load that item's stored
  outline immediately.

The focus guarantee applies inside the active DailyTodos window. Window or
application deactivation may temporarily remove the macOS first responder, but it
does not count as an editor exit; the editing session and selection are restored
when the window becomes active again.

## Considered Approaches

### Selected: Explicit User Exit Policy

Separate persistence, editing-session state, and outline publication. A window
mouse-down classifier grants permission to end the session only for a click outside
the registered editor regions. System updates cannot grant that permission.

This directly represents the product rule and covers current and future sources of
system-generated `textDidEndEditing` notifications.

### Rejected: Silent Store Persistence

Autosave could write SQLite without publishing `handbookItems`, then publish only
on editor exit. This would reduce SwiftUI invalidation but require a second store
contract and still would not protect against unrelated AppKit end-editing events.

### Rejected: Unconditional Focus Recovery

The text editor could always reclaim first responder after losing it. This is a
small change, but it would also reclaim focus after a real outline, list, or sidebar
click and violate explicit user intent.

## Design

### Editing Session Controller

Add a focused controller owned by `HandbookDetailPanel`. It has one responsibility:
classify focus transitions for the current editing session.

The controller tracks:

- whether an editing session is active;
- the currently selected item ID;
- registered editor-region rectangles in window coordinates;
- the last mouse-down classification: body input, title input, non-input editor
  control, outside, or unknown while valid geometry is unavailable;
- the body selection ranges needed for system recovery;
- whether an external exit is already being processed.

While a session is active, the controller installs a window-local mouse-down
monitor. The monitor only classifies the event and allows the original event to
continue. It is removed when the panel disappears or the session is disposed.
Region registration uses stable IDs so geometry updates replace existing values
instead of accumulating stale rectangles.

### Region Semantics

Title and body regions are input targets. A click in either may transfer first
responder normally and updates `canvasFocus` to `.title` or `.body`.

Toolbar and attachment regions are editor controls. Their actions execute without
ending the session. If AppKit emits an incidental body end-editing notification,
the body remains the intended input target and is restored after the control action.

Once valid editor geometry is registered, every location outside those regions is
outside the editor. This includes the outline even though it is rendered inside the
detail scroll view. It also includes the handbook list, application sidebar, and
other modules without requiring each external view to own editor-specific logic.
Before the first valid geometry snapshot, classification is unknown and preserves
the session.

### AppKit Focus Bridge

`HandbookPastingTextEditor.Coordinator.textDidEndEditing` stops writing `nil`
directly to the focus binding. It asks the editing session controller how to handle
the transition:

- explicit outside click: allow the session exit already initiated by the
  controller;
- title click: allow normal transfer to `.title` and never overwrite it with
  `nil`;
- toolbar or attachment click: preserve `.body` and restore the text view as first
  responder;
- no matching user mouse event: treat the notification as systemic, preserve
  `.body`, restore first responder, and restore the clamped selection ranges.

Recovery is scheduled on the main actor after the current AppKit event finishes.
Before recovery it verifies that the same item and editing session are still
active, so it cannot steal focus from a later user action or another handbook item.

### Persistence and Outline Flow

Autosave remains the current debounced path:

1. Capture the current title, body, metadata, and attachments.
2. Call the synchronous `onUpdate` persistence closure.
3. Clear dirty state.
4. Leave focus, editing-session state, and outline state unchanged.

An outside mouse-down initiates one idempotent session exit:

1. Cancel the pending autosave task.
2. Capture and persist the latest draft for the session's item.
3. Refresh the outline from the captured saved body.
4. Mark the editing session inactive and clear `canvasFocus`.
5. Allow the original outside click to continue to its target.

The ordering guarantees that list or module navigation does not discard the final
keystrokes. A second callback caused by selection change observes that the session
has already exited and cannot publish a second outline refresh for the old item.

`syncDraft` remains the initial outline-loading boundary. Existing task cancellation
and selected-item ID checks remain mandatory, preventing an obsolete extraction
from publishing after the user selects another item.

### Failure and Lifecycle Behavior

The update callback is synchronous and non-throwing, so normal return remains the
persistence boundary. A cancelled outline task affects only outline freshness; it
cannot alter saved text, focus, selection, or the selected item.

If editor geometry is temporarily unavailable during layout, a click cannot be
classified as internal and therefore must not immediately destroy the session. The
controller retains the previous valid regions for the same item until fresh frames
arrive. Regions are cleared when the item or window changes.

Window deactivation suspends first-responder recovery until activation. It does not
save, refresh the outline, or end the session by itself. Recovery is cancelled if an
outside click or item change ended that session while the window was inactive.

## Verification

Follow test-driven development. Add focused policy tests before production changes
and record the failure against the current unconditional focus clearing.

The policy tests cover:

- autosave and same-item writeback cannot authorize a focus exit;
- a system-generated end-editing event preserves `.body` and selection;
- body-to-title transfer ends body editing without clearing the session;
- toolbar and attachment clicks keep the session active;
- outline, list, sidebar, and other outside clicks authorize exactly one exit;
- an outside exit orders persistence before outline refresh and focus clearing;
- stale recovery work cannot reclaim focus for another item or after an explicit
  exit;
- item ownership and cancellation still reject obsolete outline results.

Add a source-level regression guard to the existing quality suite for the critical
integration wiring, then run:

```bash
./scripts/run_quality_checks.sh /tmp/DailyTodosFocusChecks

swift build \
  --disable-sandbox \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  --scratch-path /tmp/DailyTodosFocusBuild
```

Use isolated XDG, Clang, and Swift module cache directories for both commands.
AppKit pasteboard tests may still require the existing macOS desktop permission;
that environment limitation must be reported separately from focus-policy results.

## Acceptance Criteria

- Continuous body typing across multiple autosave cycles keeps the visible caret,
  selected range, and keyboard input in the body editor.
- Autosave persists the latest title and body without refreshing the outline.
- Clicking between body and title transfers input normally without ending the
  editing session.
- Toolbar and attachment interactions do not cause focus loss.
- Clicking the outline, handbook list, sidebar, or another module persists the
  latest draft, refreshes the outline once, and then releases editor focus.
- A system update, window deactivation, or same-item model writeback cannot be
  mistaken for an outside click.
- Switching items never publishes an outline or focus recovery belonging to the
  previous item.
- Focused tests, the complete quality suite, and the compatible-SDK Swift build
  pass.

## Release Scope

After implementation and verification, ship the correction as `v1.2.41` with build
`70`. The release includes the production change, regression tests and guards,
signed package artifacts when the configured signing environment permits them, a
pushed branch, pull request, GitHub release, and merge after verification.
