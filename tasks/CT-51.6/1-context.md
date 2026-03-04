# CT-51.6 Context

## Relevant Files

- `src/lib/screens/add_line_screen.dart` — Add Line screen widget. Owns `_parityWarning: ParityMismatch?` in local widget state. `_onFlipBoard` clears the warning and toggles orientation. `_onConfirmLine` calls `confirmAndPersist` and handles `ConfirmParityMismatch` by setting `_parityWarning`. `_onFlipAndConfirm` is triggered by the "Flip and confirm as $side" button inside the parity warning panel.
- `src/lib/controllers/add_line_controller.dart` — Business logic controller. `flipBoard()` creates a new `AddLineState` with only `boardOrientation` toggled; engine reference and buffer are preserved. `confirmAndPersist()` calls `engine.validateParity(_state.boardOrientation)` and returns `ConfirmParityMismatch` on failure. `flipAndConfirm()` flips orientation then calls `_persistMoves(engine)` directly without re-checking parity.
- `src/lib/services/line_entry_engine.dart` — Pure logic layer. Owns `_existingPath`, `_followedMoves`, `_bufferedMoves` (all mutable `List`s). `totalPly` = sum of all three lengths. `validateParity(Side)` checks whether `totalPly.isOdd` matches the expected side for the given orientation. `hasNewMoves` = `_bufferedMoves.isNotEmpty`.
- `src/test/controllers/add_line_controller_test.dart` — Controller-level unit tests. Has "Flip board" group (only tests orientation toggle) and "Parity validation" group (tests mismatch detection against engine). Missing tests: buffer invariance under flip, and `ConfirmParityMismatch` being returned when the user flips before confirming a valid white line.
- `src/test/screens/add_line_screen_test.dart` — Widget integration tests. Has tests for parity warning appearing (via the `triggerParityMismatchWarning` helper which plays e4, e5 to get an even-ply mismatch). Missing tests: valid odd-ply line + flip to black + confirm → parity warning shown; buffer intact after warning dismissal.

## Architecture

The Add Line subsystem has three layers:

**Screen** (`_AddLineScreenState`) — holds `_parityWarning: ParityMismatch?` as local widget state. The parity warning panel is rendered when `_parityWarning != null`. The panel has a close button (`_onDismissParityWarning`) and a "Flip and confirm as $side" action button (`_onFlipAndConfirm`). The regular flip button (`_onFlipBoard`) is in the action bar.

**Controller** (`AddLineController`) — bridges the screen and engine. `AddLineState` is an immutable value object passed to the screen via `notifyListeners`. `boardOrientation` lives on `AddLineState`. The `LineEntryEngine` is stored inside `AddLineState.engine` as the same object reference across flips.

**Engine** (`LineEntryEngine`) — pure business logic with no Flutter/DB dependencies. Maintains three ordered lists: `_existingPath` (moves from root to starting node, pre-loaded from DB), `_followedMoves` (existing tree moves the user followed after the starting node), `_bufferedMoves` (new moves not yet in DB). `validateParity` checks total ply parity against a supplied orientation. `getConfirmData` packages all buffered moves for persistence.

**Key constraints:**
- `flipBoard()` must only change `boardOrientation`. It is not a valid entry point for `takeBack` or any buffer mutation.
- `confirmAndPersist()` is the only point where parity is validated. It must always check before calling `_persistMoves`.
- `flipAndConfirm()` is only safe to call from the parity warning button because it skips parity re-validation (the assumption is that the flip resolves the mismatch). If called in an unexpected context, it could allow an invalid save.
