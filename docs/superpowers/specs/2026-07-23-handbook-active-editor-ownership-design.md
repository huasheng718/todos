# Handbook Active Editor Ownership

## Problem

The `v1.2.41` focus fix prevents system-generated `textDidEndEditing`
notifications from unconditionally clearing the handbook body focus. It does not
stop SwiftUI from updating the active `NSTextView`.

Every body change updates the SwiftUI binding. The 650 ms autosave also publishes
`handbookItems`, refreshes `HandbookWorkspaceViewModel.selectedItem`, and updates
the detail panel with another value for the same note. Each of these paths may run
`HandbookPastingTextEditor.updateNSView`, which currently reapplies document-wide
text storage attributes even when the native editor owns the current input
session. Focus can therefore remain `.body` while an input method's marked text,
selection, or insertion flow is disturbed.

The existing quality checks validate focus policy and source wiring. They do not
exercise a live AppKit marked-text state, so they could pass without protecting
the native editor update boundary.

## Confirmed Behavior

- Title and body edits continue to autosave after 650 ms.
- While the same note is being edited, the active editor is the authoritative body
  source. Same-note store publication or external model writeback must not replace
  its text, document attributes, marked text, selection, or insertion point.
- Autosave may continue to publish list and selected-item models. The handbook
  list can update without synchronizing those values back into the active body.
- Only an explicit click outside the registered editor region ends the editing
  session and refreshes the outline.
- An explicit exit persists the latest editor value before refreshing the outline
  and allowing the stored model to synchronize back into the detail panel.
- Switching notes saves the old draft and creates the new note's editor from the
  new stored body. It must not reuse the old note's native input state.
- Window deactivation does not end the logical editing session. Reactivation
  restores the same note, focus, and selection.

## Considered Approaches

### Selected: Active Editor Ownership Gate

Keep the existing store publication contract, but make native editor
reconciliation aware of whether the same note has an active editing session.
During that session, model writeback is treated as an acknowledgement and cannot
mutate the existing text storage. This keeps the change local to the editor
boundary and preserves current list behavior.

### Rejected: Silent Autosave Persistence

Write SQLite during editing without publishing `handbookItems`, then publish on
exit. This reduces SwiftUI invalidation but introduces two store update contracts
and leaves list summaries and timestamps stale during editing.

### Rejected: Independent Draft Architecture

Move all handbook editing into a draft model detached from `selectedItem` and
commit it on exit. This provides a strong long-term boundary but requires a wider
detail, persistence, and synchronization refactor than the patch warrants.

## Design

### Reconciliation Policy

Add a small, pure reconciliation policy that decides whether an external body may
replace the native text view. Its inputs include note identity, logical session
ownership, native first-responder state, and whether marked text exists.

The policy returns one of two actions:

- `preserveEditor`: keep the native string, text storage, marked range, selected
  ranges, and insertion point unchanged;
- `synchronizeExternalText`: replace the native string with the external body,
  clamp the previous selection only when appropriate, and apply full document
  attributes to the new content.

The same-note active session always returns `preserveEditor`. A different note or
an inactive session may return `synchronizeExternalText`. Marked text is an
additional hard guard: no external reconciliation may mutate text storage while
an input method owns a marked range.

### Native Text View Updates

`makeNSView` remains the only unconditional initialization boundary. It configures
the `NSTextView`, assigns the initial body, and applies initial document and typing
attributes.

`updateNSView` always refreshes coordinator ownership and callbacks. Under active
ownership it may update only `typingAttributes` and the insertion-point color,
because those changes affect future input rather than existing characters. It
must not reassign `NSTextView.font` or `textColor`; those setters may affect the
current plain-text storage.

Before changing `string`, document-wide attributes, or selected ranges,
`updateNSView` consults the reconciliation policy. Under `preserveEditor`, it
returns without touching those values. Under `synchronizeExternalText`, it applies
the external value once and styles the resulting document. Full
`textStorage.setAttributes` is never run as a general SwiftUI update side effect.

Existing first-responder recovery remains responsible only for a genuine AppKit
responder loss. It does not participate in ordinary same-note model writeback.

### Persistence and Model Publication

Body and title autosave retain the existing 650 ms debounce. `HandbookStore`
continues to write SQLite and publish `handbookItems`; the workspace may continue
to republish `selectedItem` for list and metadata consumers.

`HandbookDetailPanel.syncDraft` preserves the local body while the same note's
editing session is active. The native ownership gate independently ensures that a
parent recomputation cannot mutate the text view even if future model code changes
the detail update order.

An outside click keeps the existing ordered exit:

1. Cancel the pending autosave.
2. Capture and persist the current native editor body.
3. Refresh the outline from that exact captured body.
4. Finish the logical editing session and clear editor focus.
5. Allow subsequent stored-model publication to reconcile into the inactive
   editor.

Switching notes follows the existing reset identity. The old note is persisted
before the new item changes `bodyEditorResetID`, and the newly created native view
loads only the new note's body.

### Failure and Lifecycle Behavior

Persistence failure continues to surface through `HandbookStore.lastError`. This
patch does not change the existing synchronous, non-throwing update callback.
Regardless of persistence outcome, store publication cannot replace the active
native body. Retry and success-aware exit semantics are outside this focused
input-stability change.

Window deactivation suspends physical first responder without changing logical
ownership. Stale asynchronous recovery verifies item and session identity before
restoring focus. A completed outside exit or note switch invalidates that recovery.

## Verification

Follow test-driven development.

Add executable pure-policy checks for:

- active same-note writeback preserves the editor;
- active marked text always preserves the editor;
- inactive same-note external text may synchronize;
- a different note may synchronize only through the note-switch boundary.

Add an AppKit behavior test that creates an `NSTextView`, establishes marked text
and selected ranges, applies an active-session reconciliation, and verifies that
the string, marked range, selected ranges, text storage attributes, and view
identity remain unchanged. A complementary inactive-session case verifies that
external text replacement and document styling still work.

Extend integration guards so the active `updateNSView` path cannot perform a
document-wide `setAttributes`, assign `string`, or restore model-derived selected
ranges without an allow decision. Retain the existing focus, outside-click,
outline-isolation, item-ownership, cancellation, and image-paste checks.

Run the focused RED/GREEN checks, the complete quality suite, and a full Swift
build with isolated caches. Prefer the existing macOS 15.4 SDK compatibility path.
If the installed Swift compiler cannot consume either available SDK, repair the
toolchain before claiming build success.

Finally, run the packaged app and continuously type Chinese across multiple
autosave cycles. Verify that the visible caret, marked text, selection, and input
remain stable, then click outside and verify one save, one outline refresh, and a
normal focus exit.

## Acceptance Criteria

- Continuous Chinese body input across multiple autosave cycles is uninterrupted.
- The same native text view, marked range, selection, caret, and focus survive
  same-note autosave publication.
- Autosave persists the latest body without refreshing the outline.
- Same-note model writeback cannot replace the active body.
- Clicking outside persists the latest body, refreshes the outline once, and then
  releases focus and model ownership.
- Switching notes loads the new stored body without retaining old marked text or
  selection.
- Store errors remain visible through the existing error state and cannot cause
  same-note model writeback into the active body.
- Focused tests, complete quality checks, Swift build, and packaged-app Chinese
  input verification pass.

## Release Scope

Ship the correction as `v1.2.42`, build `71`. The release includes the focused
tests, production change, package artifacts, pushed branch, pull request, GitHub
release, and merge after verification.
