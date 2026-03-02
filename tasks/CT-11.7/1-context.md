# CT-11.7: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/add_line_screen.dart` | Screen widget; owns the `AddLineController` and `ChessboardController`. Contains `_onConfirmLine()` which currently calls `_showParityWarningDialog()` (an `AlertDialog`) when `ConfirmParityMismatch` is returned. Also owns `_isLabelEditorVisible` state for inline label editing -- a pattern to follow for inline warning visibility. |
| `src/lib/controllers/add_line_controller.dart` | Business logic controller. `confirmAndPersist()` validates parity and returns a `ConfirmResult` sealed type (`ConfirmParityMismatch`, `ConfirmSuccess`, `ConfirmNoNewMoves`). `flipAndConfirm()` flips orientation and persists. `AddLineState` is the immutable state class holding all screen state. |
| `src/lib/services/line_entry_engine.dart` | Pure business-logic engine. `validateParity()` returns `ParityMismatch` (with `expectedOrientation`) or `ParityMatch`. Source of the warning data. No changes needed. |
| `src/lib/widgets/inline_label_editor.dart` | Existing inline widget pattern. Appears below the pill area, is dismissible, non-blocking. Architectural template for how an inline warning should integrate. |
| `src/lib/widgets/move_pills_widget.dart` | Renders move pills in a wrapping row. Located between the chessboard and the action bar. |
| `src/test/screens/add_line_screen_test.dart` | Widget tests for the Add Line screen. Will need new tests for the inline warning. |
| `src/test/controllers/add_line_controller_test.dart` | Controller-level tests. Already has a "Parity validation" group. No changes needed. |

## Architecture

The Add Line screen has three layers: Screen (`AddLineScreen`), Controller (`AddLineController`), and Engine (`LineEntryEngine`).

The **confirmation flow** currently works as follows:

1. User presses Confirm. Screen calls `_onConfirmLine()`.
2. `_onConfirmLine()` calls `_controller.confirmAndPersist()`.
3. `confirmAndPersist()` calls `engine.validateParity(boardOrientation)`. If parity mismatches, it returns `ConfirmParityMismatch(mismatch)` without persisting.
4. The screen switches on the result. For `ConfirmParityMismatch`, it calls `_showParityWarningDialog(mismatch)` which opens an `AlertDialog`.
5. If the user taps "Flip and confirm", the screen calls `_controller.flipAndConfirm()`.

The screen already has an inline widget pattern: the `InlineLabelEditor`, controlled by a boolean `_isLabelEditorVisible`. This is exactly the pattern to follow for the inline parity warning.

Key constraint: Confirm button is only enabled when `hasNewMoves` is true, and the label editor only shows when `hasNewMoves` is false, so they cannot both be active simultaneously. Similarly, the parity warning only appears after a confirm attempt (which requires `hasNewMoves`), so the label editor and parity warning are mutually exclusive.
