# CT-54: Context

## Relevant Files

### Feature Specs
- `features/add-line.md` -- Add Line screen spec; Entry Flow, Undo Feedback Lifetime, and pill/button behavior sections need updating.
- `features/line-management.md` -- Line management spec; defines the builder pattern (buffer + confirm), take-back, branching, and card creation rules. Read-only for this task.
- `design/ui-guidelines.md` -- Cross-cutting UI conventions (pill styling, inline warnings). May need a note about "saved line" indicator styling.

### Controller Layer
- `src/lib/controllers/add_line_controller.dart` -- The main controller. Owns `AddLineState`, `LineEntryEngine`, pending labels, and all user action handlers. The `_persistMoves()` method calls `loadData()` after confirm, which rebuilds the engine from scratch (effectively resetting the builder). The `confirmAndPersist()` and `flipAndConfirm()` methods are the confirm entry points. `isExistingLine` computed property drives the "Existing line" label. `_undoGeneration` and `_dismissSnackBarOnNextMove` (tracked in screen) manage snackbar lifecycle.
- `src/lib/controllers/add_line_controller.dart` (`AddLineState`) -- Immutable state class with `pills`, `currentFen`, `preMoveFen`, `focusedPillIndex`, `engine`, `treeCache`, `boardOrientation`, `aggregateDisplayName`, `isLoading`, `repertoireName`. Currently has no "line is saved" flag.
- `src/lib/controllers/add_line_controller.dart` (`ConfirmSuccess`, `ConfirmResult` hierarchy) -- Sealed result types returned by confirm. `ConfirmSuccess` carries `isExtension`, `oldLeafMoveId`, `insertedMoveIds`, `oldCard`.

### Screen Layer
- `src/lib/screens/add_line_screen.dart` -- The UI widget. `_handleConfirmSuccess()` resets the board position after confirm. `_onControllerChanged()` manages the `_dismissSnackBarOnNextMove` flag for clearing undo snackbars on the first move of a new line. Builds the "Existing line" info label via `_buildExistingLineInfo()`. Shows undo snackbars via `_showExtensionUndoSnackbar()` and `_showNewLineUndoSnackbar()`.

### Engine Layer
- `src/lib/services/line_entry_engine.dart` -- Pure business logic. Manages `_existingPath`, `_followedMoves`, `_bufferedMoves`, and `_hasDiverged`. `acceptMove()` follows existing tree branches or buffers new moves. `hasNewMoves` returns whether buffer is non-empty. `getConfirmData()` produces the data for persistence. The engine is stateless w.r.t. persistence -- it is rebuilt by `loadData()` after every confirm.

### Persistence Layer
- `src/lib/services/line_persistence_service.dart` -- Handles actual DB writes. `persistNewMoves()` delegates to extension or branch path. Returns `PersistResult`. Not directly modified by this task.

### Widget Layer
- `src/lib/widgets/move_pills_widget.dart` -- Renders pills. `MovePillData` has `san`, `isSaved`, and `label`. Currently `isSaved` does not affect visual styling (all pills look the same per spec). The "already saved" indicator would need either a new field or a new styling path.
- `src/lib/theme/pill_theme.dart` -- Theme extension with `pillColor`, `focusedBorderColor`, `textOnPillColor`. Would need extension if the "saved line" indicator is pill-level styling.

### Supporting Files
- `src/lib/widgets/chessboard_controller.dart` -- Board position controller. `setPosition()`, `resetToInitial()`, `playMove()`, `undo()`. Used by the screen to sync the board after confirm.
- `src/lib/models/repertoire.dart` -- `RepertoireTreeCache` class. `getLine()`, `isLeaf()`, `getChildren()`, `getRootMoves()`. Rebuilt by `loadData()`.
- `src/lib/navigation/route_observers.dart` -- Route observer for snackbar cleanup on navigation.

### Test Files
- `src/test/controllers/add_line_controller_test.dart` -- Extensive controller tests including confirm flow, parity, branching, labels, undo. Tests will need new cases for persistent-pill behavior.
- `src/test/screens/add_line_screen_test.dart` -- Widget tests for the screen including undo snackbar lifecycle, parity warnings, label editing. Tests will need new cases for post-confirm pill persistence.
- `src/test/widgets/move_pills_widget_test.dart` -- Unit tests for the pill widget.

## Architecture

### Subsystem Overview

The Add Line screen follows a **controller-engine-screen** architecture:

1. **`LineEntryEngine`** is a pure business logic service (no Flutter/DB dependencies). It maintains three internal lists: `_existingPath` (moves from root to the starting position, already in DB), `_followedMoves` (existing tree moves the user followed during this session), and `_bufferedMoves` (new moves not yet persisted). It tracks whether the user has diverged from the tree (`_hasDiverged`).

2. **`AddLineController`** (a `ChangeNotifier`) wraps the engine, owns the `AddLineState`, handles pending labels, and orchestrates the confirm flow. On confirm, it calls `LinePersistenceService.persistNewMoves()` then calls `loadData()`, which rebuilds the tree cache and engine from scratch. This is the "reset" -- after `loadData()`, the engine has no `_startingMoveId` (unless one was passed at construction), so `_existingPath` is empty, `_followedMoves` is empty, `_bufferedMoves` is empty, and the pill list comes back empty.

3. **`AddLineScreen`** is a `ConsumerStatefulWidget` that renders the board, pills, action bar, and inline editors. After confirm success, `_handleConfirmSuccess()` syncs the board to the controller's `currentFen` (which is `kInitialFEN` after `loadData()` with no `startingMoveId`). The screen also manages the undo snackbar lifecycle using `_dismissSnackBarOnNextMove` -- armed on confirm, fires on the first `hasNewMoves` false-to-true transition.

### Key Constraint: The `loadData()` Reset

The critical behavior to change is in `_persistMoves()` (line 607 of the controller): after successful persistence, it calls `await loadData()`. This rebuilds the engine from the DB, which means:
- The engine is created fresh with no `startingMoveId`, so `_existingPath` is `[]`.
- `_followedMoves` and `_bufferedMoves` are both empty.
- The pills list rebuilds as `[]`.
- `currentFen` resets to `kInitialFEN`.
- `focusedPillIndex` becomes `null`.

The task requires that after confirm, the pills and board position **persist** at their current state, with all previously-buffered moves now showing as saved. The "Existing line" indicator should appear since `hasNewMoves` is false.

### Key Constraint: Undo Snackbar Coexistence

The undo snackbar (`_dismissSnackBarOnNextMove`) currently fires on the first `hasNewMoves` false-to-true transition. With persistent pills, the snackbar should still be dismissed when the user starts a genuinely new variation (plays a different move from a navigated-back position), but should **not** be cleared by the mere presence of persistent pills.
