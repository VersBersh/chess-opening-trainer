# CT-64: Implementation Notes

## Files modified

### `src/lib/controllers/add_line_controller.dart`
- Added `_hasConfirmedSinceLastReset` private boolean field (initially `false`).
- Added `canResetForNewLine` getter that exposes the flag.
- Set flag to `true` in `_persistMoves()` and `_persistLabelsOnly()` after successful `_loadData` calls (before `return ConfirmSuccess`).
- Cleared flag to `false` at the top of the public `loadData()` method.
- Added `resetForNewLine()` method that increments `_undoGeneration` and calls `loadData()`.

### `src/lib/screens/add_line_screen.dart`
- Added `_onNewLine()` async handler that clears `_isLabelEditorVisible` and `_parityWarning`, clears snackbars, calls `resetForNewLine()`, and syncs the board controller.
- Added conditionally rendered "New Line" `TextButton.icon` in `_buildActionBar()` after the Label button, guarded by `if (_controller.canResetForNewLine)`.

## Deviations from plan

None. All three steps were implemented exactly as specified.

## Follow-up work discovered

None.
