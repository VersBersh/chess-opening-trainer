# CT-38: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/add_line_screen.dart` | Screen widget for adding lines. Contains `_onConfirmLine()` (lines 142-169) which calls the controller and handles `ConfirmResult` variants. Also contains `_showDiscardDialog()` and `_buildParityWarning()` as existing dialog/warning patterns. |
| `src/lib/controllers/add_line_controller.dart` | Business logic controller. Owns `AddLineState` (which includes `aggregateDisplayName` and `pills`), the `confirmAndPersist()` method that validates parity then persists, and `flipAndConfirm()`. Sealed `ConfirmResult` hierarchy defines all outcomes. |
| `src/lib/widgets/repertoire_dialogs.dart` | Shared dialog utility functions: `showDeleteConfirmationDialog`, `showBranchDeleteConfirmationDialog`, `showOrphanPromptDialog`, `showCardStatsDialog`, `showLabelImpactWarningDialog`. All follow the same `showDialog<T>` + `AlertDialog` + actions pattern. Also exports `LabelChangeCancelledException`. |
| `src/lib/services/line_entry_engine.dart` | Pure business-logic engine. Tracks existing path, followed moves, and buffered moves. `getCurrentDisplayName()` returns the aggregate label-based display name for the current position. `hasNewMoves` indicates whether there are unsaved buffered moves. |
| `src/lib/models/repertoire.dart` | `RepertoireTreeCache` — indexed view of the move tree. `getAggregateDisplayName(moveId)` walks root-to-node concatenating all labels with " --- " separator. Returns empty string if no labels exist along the path. |
| `src/lib/widgets/move_pills_widget.dart` | `MovePillData` model with `san`, `isSaved`, and optional `label`. The `MovePillsWidget` renders pills with label text below labeled pills. |
| `src/lib/widgets/label_conflict_dialog.dart` | Example of a shared dialog utility with `checkLabelConflicts()` helper that checks state then conditionally shows a dialog. |
| `src/lib/widgets/inline_label_editor.dart` | Inline label editor widget. Shows how labels are edited on existing saved moves. Relevant for understanding the full label lifecycle. |
| `src/lib/services/line_persistence_service.dart` | Handles DB persistence of new moves. `persistNewMoves()` is called by the controller after validation passes. |
| `src/test/controllers/add_line_controller_test.dart` | Unit tests for the controller. Uses `seedRepertoire()` helper with `labelsOnSan` parameter. |
| `src/test/screens/add_line_screen_test.dart` | Widget tests for the add line screen. Uses same `seedRepertoire()` helper and tests confirm flows. |

## Architecture

The Add Line subsystem follows a **screen -> controller -> engine -> persistence** layered architecture:

1. **AddLineScreen** (`ConsumerStatefulWidget`) owns an `AddLineController` and a `ChessboardController`. It translates user gestures (board moves, pill taps, button presses) into controller calls and renders state from `AddLineState`.

2. **AddLineController** (`ChangeNotifier`) holds immutable `AddLineState`, owns a `LineEntryEngine` and a `LinePersistenceService`. It orchestrates validation (parity checks), delegates persistence, and rebuilds state after mutations. The controller exposes sealed `ConfirmResult` types that the screen pattern-matches on.

3. **LineEntryEngine** is a pure business-logic class (no Flutter, no DB). It tracks three move sequences: `existingPath` (already in DB, from root to starting node), `followedMoves` (existing tree moves the user followed), and `bufferedMoves` (new unsaved moves). It provides `getCurrentDisplayName()` which uses `RepertoireTreeCache.getAggregateDisplayName()` to derive the label-based name.

4. **Confirmation flow**: `_onConfirmLine()` in the screen calls `controller.confirmAndPersist()`. The controller first validates parity (returning `ConfirmParityMismatch` if wrong). If parity passes, it calls `_persistMoves()`. The screen then handles the result: shows a parity warning widget, calls `_handleConfirmSuccess()`, or shows an error snackbar.

**Key constraints:**
- The controller does not have access to `BuildContext` -- it cannot show dialogs. All user-facing warnings must be initiated by the screen.
- The `aggregateDisplayName` on `AddLineState` reflects only labels on existing/followed moves. Buffered (unsaved) moves never have labels.
- Labels are set on individual moves after they are saved. A newly confirmed line will never have labels at confirmation time unless the line extends an already-labeled path.
- The "no name" check must consider the entire path (existing + followed + to-be-saved moves). If any ancestor move along the path has a label, the line effectively "has a name."
