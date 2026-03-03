# CT-51.5: Context

## Relevant Files

| File | Role |
|---|---|
| `src/lib/screens/add_line_screen.dart` | Screen widget; owns the local ScaffoldMessenger, shows undo snackbars, handles `_onBoardMove` |
| `src/lib/controllers/add_line_controller.dart` | Controller/state; owns `LineEntryEngine`, exposes `onBoardMove`, `confirmAndPersist`, `hasNewMoves` |
| `src/lib/services/line_entry_engine.dart` | Pure move-tracking service; tracks buffered moves |
| `src/test/screens/add_line_screen_test.dart` | Widget tests covering snackbar appearance, undo action, dismiss-without-undo; tests to extend for CT-51.5 |

## Architecture

### Subsystem: Add Line feedback / undo snackbar

The Add Line screen uses a **screen-local ScaffoldMessenger** (keyed by `_localMessengerKey`) rather than the root ScaffoldMessenger. This confines undo snackbars to the Add Line route and prevents them leaking to other screens.

**Snackbar lifecycle today:**

1. User plays moves → taps Confirm → `_onConfirmLine()` is called.
2. `confirmAndPersist()` on the controller returns `ConfirmSuccess`.
3. `_handleConfirmSuccess()` calls `_showExtensionUndoSnackbar()` or `_showNewLineUndoSnackbar()`, both of which call `showSnackBar()` on the local messenger.
4. Snackbar auto-dismisses after ~4 seconds OR is cleared when the user navigates away (`didPushNext` → `clearSnackBars()`) or disposes the screen.

**The bug:** Nothing currently clears the snackbar when the user plays the first board move of a new line on the same screen.

**How moves are processed:**

- Board move → `_onBoardMove(move)` in the screen → `_controller.onBoardMove(move, _boardController)`.
- Returns either `MoveAccepted` or `MoveBranchBlocked`.
- After a successful confirm, the engine is fully reset: pills are empty, `hasNewMoves` is false.
- The first `MoveAccepted` after that reset is the "first move of a new line."

**Key constraints:**

- `clearSnackBars()` must NOT be called on every board move — only for the first move after a confirm. Clearing on every move would dismiss error snackbars prematurely.
- No changes are needed in the controller, engine, or repositories.
