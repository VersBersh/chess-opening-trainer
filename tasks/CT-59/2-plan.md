# CT-59: Implementation Plan

## Goal

Enable the Confirm button when there are pending label edits on existing moves (even with no new moves), so label-only changes are persisted instead of silently discarded.

## Steps

**The implementation is already complete.** After a thorough review of every file listed in the task, the controller, screen, persistence service, and tests all already implement the required behavior. Here is the evidence:

### 1. Controller already supports label-only confirm

**File:** `src/lib/controllers/add_line_controller.dart`

- `hasPendingLabelChanges` (line 399): returns `_pendingLabels.isNotEmpty`.
- `hasUnsavedChanges` (line 402): returns `hasNewMoves || hasPendingLabelChanges` -- so it is true when only labels have changed.
- `isExistingLine` (line 410-411): returns true only when there are no new moves AND no pending label changes -- so the "Existing line" info label is suppressed when labels are pending.
- `confirmAndPersist()` (lines 630-653): has an explicit label-only path at lines 638-641 that calls `_persistLabelsOnly()` when `!engine.hasNewMoves && _pendingLabels.isNotEmpty`.
- `_persistLabelsOnly()` (lines 704-729): persists pending labels to DB via `LinePersistenceService.persistLabelsOnly()`, reloads data with `preservePosition: true`, and returns `ConfirmSuccess(isExtension: false, insertedMoveIds: [])`.
- `updateLabel()` (lines 991-1030): stores label changes in `_pendingLabels`, rebuilds pills and display name, and notifies listeners.

### 2. Screen already wires up the Confirm button correctly

**File:** `src/lib/screens/add_line_screen.dart`

- Line 914: `onPressed: _controller.hasUnsavedChanges ? _onConfirmLine : null` -- Confirm button is enabled whenever `hasUnsavedChanges` is true, which includes label-only edits.
- Line 177: `if (!_controller.hasUnsavedChanges) return` -- early return guard in `_onConfirmLine` correctly allows label-only confirms through.
- Line 435: `canPop: !_controller.hasUnsavedChanges` -- PopScope triggers the discard dialog for label-only edits, preventing silent data loss.
- Lines 213-235: `_handleConfirmSuccess` only shows undo snackbars when `insertedMoveIds` is non-empty, so label-only confirms correctly produce no undo snackbar.

### 3. Persistence service already supports label-only persistence

**File:** `src/lib/services/line_persistence_service.dart`

- `persistLabelsOnly()` (lines 168-172): iterates over `PendingLabelUpdate` entries and calls `_repertoireRepo.updateMoveLabel()` for each.

### 4. Controller unit tests already exist

**File:** `src/test/controllers/add_line_controller_test.dart`

- Group `CT-59: hasPendingLabelChanges and hasUnsavedChanges` (line 3789): 5 tests covering all combinations of hasNewMoves/hasPendingLabelChanges/hasUnsavedChanges.
- Group `CT-59: confirmAndPersist with label-only edits` (line 3891): 3 tests covering label persistence, ConfirmNoNewMoves when no changes, and position preservation after label-only confirm.

### 5. Widget tests already exist

**File:** `src/test/screens/add_line_screen_test.dart`

- Group `CT-59: Label-only confirm flow` (line 3156): 5 widget tests covering:
  - `confirm enabled and persists label-only edits` -- verifies Confirm button disabled -> enabled -> label persisted in DB -> button disabled again.
  - `label-only confirm preserves focused pill and board position` -- verifies focusedPillIndex and currentFen are unchanged after label-only confirm.
  - `discard dialog shown when only pending labels exist` -- verifies the PopScope triggers the discard dialog for label-only edits.
  - `no undo snackbar shown for label-only confirm` -- verifies no "Line extended"/"Undo" snackbar appears.
  - `existing new-move confirm flow still works after label-only changes (regression)` -- verifies the standard new-move confirm path is unaffected.

### Summary: No code changes needed

All four acceptance criteria are already satisfied:

| Criterion | Evidence |
|-----------|----------|
| Confirm button enabled with pending label edits | `hasUnsavedChanges` includes `hasPendingLabelChanges`; screen wires `onPressed` to `hasUnsavedChanges` (line 914) |
| Label-only edits persisted on Confirm | `_persistLabelsOnly()` writes to DB; widget test verifies DB state |
| Existing new-move confirm unchanged | Separate `_persistMoves()` path; regression widget test confirms |
| Widget test covering label-only confirm | 5 widget tests + 5+ controller tests in CT-59 groups |

## Risks / Open Questions

1. **Task may be already done.** The code and tests for CT-59 are fully implemented in the current codebase. The task description's acceptance criteria (Confirm button enabled for pending labels, label-only edits persisted, existing flow unchanged, widget test) are all met. The task should be marked as complete without further code changes.

2. **No missing edge cases identified.** The implementation handles: reverting a label to its original value (removes from `_pendingLabels`), multiple label edits across different pills, label edits combined with new moves (both persisted atomically), and error recovery (reloads from DB on failure).
