# CT-59: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/controllers/add_line_controller.dart` | Controller owning AddLineState, LineEntryEngine, pending-labels map, and all business logic (hasNewMoves, hasUnsavedChanges, hasPendingLabelChanges, confirmAndPersist, _persistLabelsOnly, updateLabel). This is the primary file for this task. |
| `src/lib/screens/add_line_screen.dart` | UI widget. Reads `hasUnsavedChanges` to enable/disable the Confirm button (line 914) and to guard the PopScope/discard dialog (line 435). Calls `_onConfirmLine()` which delegates to `controller.confirmAndPersist()`. |
| `src/lib/services/line_persistence_service.dart` | Service layer that persists moves and labels to DB. Contains `persistLabelsOnly()` which writes pending label updates without inserting moves. |
| `src/lib/services/line_entry_engine.dart` | Engine tracking existingPath, followedMoves, and bufferedMoves. Provides `hasNewMoves` property. Not directly changed for this task. |
| `src/lib/widgets/move_pills_widget.dart` | Defines `MovePillData` (san, isSaved, label). Display-only; not changed. |
| `src/lib/repositories/repertoire_repository.dart` | Defines `PendingLabelUpdate` and `updateMoveLabel`. Already supports label persistence. |
| `src/test/controllers/add_line_controller_test.dart` | Existing controller unit tests, including a CT-59 group verifying `hasPendingLabelChanges`, `hasUnsavedChanges`, `confirmAndPersist` with label-only edits, and position preservation. |
| `src/test/screens/add_line_screen_test.dart` | Existing widget tests, including a CT-59 group verifying the Confirm button enables/disables for label-only edits, label persistence in DB, discard dialog with pending labels, no undo snackbar for label-only confirms, and regression for existing new-move confirm flow. |
| `features/add-line.md` | Spec for the Add Line screen. Defines deferred persistence, confirm-to-save, and the "Existing line" info label behavior. |

## Architecture

The Add Line screen uses a **controller + immutable state** pattern:

1. **AddLineController** (ChangeNotifier) owns:
   - A `LineEntryEngine` that tracks three lists: `existingPath` (the starting saved moves from DB), `followedMoves` (saved moves the user navigated through), and `bufferedMoves` (new unsaved moves).
   - A `_pendingLabels` map (`Map<int, String?>`) keyed by pill index, tracking label edits on saved moves. Buffered moves store their labels directly on `BufferedMove.label`.
   - Computed properties: `hasNewMoves` (buffered moves exist), `hasPendingLabelChanges` (pending labels map non-empty), `hasUnsavedChanges` (either of the previous two), `isExistingLine` (pills visible, no new moves, no pending labels).

2. **Confirm flow**: `confirmAndPersist()` has three paths:
   - No changes at all: returns `ConfirmNoNewMoves`.
   - Label-only (no new moves, pending labels non-empty): calls `_persistLabelsOnly()` which writes labels to DB via `LinePersistenceService.persistLabelsOnly()`, then reloads data with `preservePosition: true`.
   - New moves: validates parity, then calls `_persistMoves()` which delegates to `LinePersistenceService.persistNewMoves()`.

3. **UI wiring**: The screen's `_buildActionBar` enables/disables the Confirm button based on `_controller.hasUnsavedChanges`. The `_onConfirmLine` handler has an early return `if (!_controller.hasUnsavedChanges) return` guard. The `PopScope.canPop` also uses `hasUnsavedChanges` to trigger the discard dialog.

4. **Key constraint**: The label-only confirm path returns `ConfirmSuccess(isExtension: false, insertedMoveIds: [])`. The screen's `_handleConfirmSuccess` only shows undo snackbars when `insertedMoveIds` is non-empty or `isExtension` is true with an old card, so label-only confirms correctly produce no undo snackbar.
