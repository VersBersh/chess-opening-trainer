# CT-64: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/add_line_screen.dart` | Screen widget; builds the app bar, board, pills area, and action bar. Handles UI events and delegates to the controller. |
| `src/lib/controllers/add_line_controller.dart` | Business logic controller (`ChangeNotifier`); owns `LineEntryEngine`, `RepertoireTreeCache`, and `AddLineState`. Exposes `loadData()`, `confirmAndPersist()`, `flipBoard()`, `onBoardMove()`, `onTakeBack()`, etc. |
| `src/lib/services/line_entry_engine.dart` | In-memory move buffer engine; tracks `existingPath`, `followedMoves`, and `bufferedMoves`. Provides `acceptMove()`, `takeBack()`, `getConfirmData()`, `validateParity()`. |
| `src/lib/widgets/chessboard_controller.dart` | Wrapper around the chessground board; provides `setPosition()`, `resetToInitial()`, `undo()`, `playMove()`. |
| `src/lib/widgets/move_pills_widget.dart` | Widget that renders move pills; consumes `List<MovePillData>`. |
| `src/lib/services/line_persistence_service.dart` | Handles DB persistence of new moves, label updates, and reroutes. |
| `src/test/screens/add_line_screen_test.dart` | Widget tests for the Add Line screen; uses `buildTestApp()`, `seedRepertoire()`, `pumpWithNewLine()`, `pumpWithExtendingMove()` helpers. Tests inject a `controllerOverride` + `ChessboardController` for programmatic moves. |
| `src/test/controllers/add_line_controller_test.dart` | Unit tests for `AddLineController`; tests `loadData`, move acceptance, take-back, confirm, undo, labels, branching, and hint arrows. |
| `features/add-line.md` | Spec for the Add Line screen; defines layout, entry flow, confirm behavior, undo, labels, transpositions, and hint arrows. |

## Architecture

The Add Line screen follows a **controller + screen** pattern:

- **`AddLineController`** (extends `ChangeNotifier`) holds all state in an immutable `AddLineState` object. The screen listens via `addListener` and calls `setState` on every change. The controller owns a `LineEntryEngine` (the in-memory move buffer) and a `RepertoireTreeCache` (the repertoire tree snapshot). It also maintains a `_pendingLabels` map for deferred label edits and an `_undoGeneration` counter for snackbar invalidation.

- **`AddLineScreen`** (`ConsumerStatefulWidget`) creates the controller in `initState` (or accepts a `controllerOverride` for testing), creates a `ChessboardController`, and wires up UI events. The `_localMessengerKey` scopes snackbars to this screen's scaffold.

- **Reset mechanism already exists:** The `loadData()` method (public) calls `_loadData()` (internal), which reloads all data from the DB, builds a fresh `LineEntryEngine` from `_startingMoveId`, clears `_pendingLabels`, and rebuilds state. This is exactly what the undo handlers (`undoNewLine`, `undoExtension`) call after rolling back DB changes. For a "New Line" reset, the same `loadData()` call achieves the desired effect -- it clears the board, pills, and pending labels back to the starting position -- without any DB changes needed (since nothing needs to be undone; the confirmed line stays).

- **Post-confirm state:** After a successful confirm, `_loadData(leafMoveId: result.newLeafMoveId)` is called, which rebuilds the engine starting at the new leaf. All pills appear as saved, `hasNewMoves` is false, `isExistingLine` is true, and the Confirm button is disabled. This is the state where the "New Line" button should become available.

- **Key constraints:**
  - The repertoire ID and color (board orientation) must be preserved across reset.
  - The `_startingMoveId` is immutable on the controller -- `loadData()` always resets to it.
  - The screen uses `PopScope` to guard against losing unsaved changes; after a successful confirm there are no unsaved changes, so the guard does not apply.
  - Snackbar lifecycle: the "Line saved"/"Line extended" snackbar is dismissed on the first new move (`_dismissSnackBarOnNextMove` flag). A "New Line" reset should also clear any active snackbar.
