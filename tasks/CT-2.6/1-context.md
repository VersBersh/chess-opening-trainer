# CT-2.6 Context

## Relevant Files

### Specs

- `features/line-management.md` -- Primary spec for take-back behavior during line entry. Defines: take-back button removes the last move from the buffer and reverts the board to the previous position; can be pressed repeatedly; is disabled at the starting position or at a branch point (boundary of existing repertoire data).
- `architecture/state-management.md` -- Defines the Riverpod + ChangeNotifier + controller patterns used throughout the app. ChessboardController follows Flutter's controller pattern (like TextEditingController). Parent widgets (DrillController, RepertoireBrowserScreen) own and manage controller instances.

### Source files (to modify)

- `src/lib/widgets/chessboard_controller.dart` -- The core file for this task. A `ChangeNotifier` that owns the chess `Position` state. Current API: `setPosition(fen)`, `playMove(move)`, `resetToInitial()`. Exposes `fen`, `sideToMove`, `isCheck`, `validMoves`, `lastMove`, `isPromotionRequired(move)`. Has no move history or undo capability. This file will be extended with a history stack and `undo()` method.

### Source files (consumers of ChessboardController -- context for understanding usage)

- `src/lib/widgets/chessboard_widget.dart` -- Stateful widget wrapping the `chessground` package. Receives a `ChessboardController`, listens for changes, and rebuilds the board. Reads `controller.fen`, `controller.sideToMove`, `controller.validMoves`, `controller.isCheck`, `controller.lastMove`. The widget does not directly call mutators other than `playMove` (via user interaction). Does not need modification for this task.
- `src/lib/screens/drill_screen.dart` -- `DrillController` owns a `ChessboardController`. Uses `resetToInitial()` at card start, `playMove(move)` for intro/opponent moves, and `setPosition(_preMoveFen)` to revert after mistakes. The drill screen does NOT need undo -- it reverts to a known FEN after mistakes. The drill controller will be unaffected by adding undo to the ChessboardController.
- `src/lib/screens/repertoire_browser_screen.dart` -- `_RepertoireBrowserScreenState` owns a `ChessboardController`. In browse mode, uses `setPosition(move.fen)` for navigation and `resetToInitial()` for reset. In edit mode, the board is interactive (`PlayerSide.both`) with an `onMove` callback. Take-back is currently implemented via `LineEntryEngine.takeBack()` which returns a FEN, then calls `_boardController.setPosition(result.fen)`. This is the primary consumer that would benefit from `undo()`.
- `src/lib/services/line_entry_engine.dart` -- Pure business-logic service for line entry. Manages an in-memory buffer of new moves. `takeBack()` removes the last buffered move and returns a `TakeBackResult` with the FEN to revert to. `canTakeBack()` returns true only when buffered moves exist. The engine handles the logical take-back (buffer management), while the screen handles the board revert via `setPosition`. This separation means the engine does not need to change.

### Source files (reference for existing patterns)

- `src/lib/models/repertoire.dart` -- `RepertoireTreeCache`: eagerly-loaded indexed tree. Not directly involved but provides context for how the repertoire tree is navigated.
- `src/lib/models/review_card.dart` -- `DrillSession` and `DrillCardState` transient models. Shows patterns for in-memory state.
- `src/lib/services/chess_utils.dart` -- `sanToMove(Position, String)` utility. Converts SAN to NormalMove.
- `src/pubspec.yaml` -- Dependencies. `dartchess: ^0.12.1` provides `Position`, `Chess`, `NormalMove`, `Side`, etc. `chessground: ^8.0.1` is the board renderer. No new dependencies needed for this task.

### Test files

- `src/test/widgets/chessboard_controller_test.dart` -- Existing unit tests for `ChessboardController`. Tests `setPosition`, `playMove` (legal/illegal), `resetToInitial`, listener notifications, `isCheck`, `validMoves`, promotion. This file will be extended with undo tests.
- `src/test/widgets/chessboard_widget_test.dart` -- Widget tests for ChessboardWidget. Reference for patterns.
- `src/test/screens/repertoire_browser_screen_test.dart` -- Widget tests for the browser screen including edit mode and take-back. The `_onTakeBack` handler currently calls `_boardController.setPosition(result.fen)`. Tests verify board revert behavior via LineEntryEngine + setPosition.

## Architecture

The ChessboardController is a lightweight `ChangeNotifier` that owns a single `Position` object (from the `dartchess` package) and exposes derived board properties (FEN, side to move, legal moves, check status, last move highlight). It follows Flutter's controller pattern -- parent widgets create, own, and dispose it.

### Current position management

The controller has three mutator methods:

1. **`setPosition(fen)`** -- Replaces the entire position from a FEN string. Clears `lastMove`. Used for navigation (jumping to a position) and reverting after mistakes/take-back.
2. **`playMove(move)`** -- Validates and plays a `NormalMove`. Sets `lastMove` for highlight. Returns `false` if illegal.
3. **`resetToInitial()`** -- Resets to the standard starting position. Clears `lastMove`.

All three invalidate the `_validMovesCache` and call `notifyListeners()`.

### How undo is currently handled (without a history stack)

Take-back in the repertoire browser's edit mode works through a two-layer approach:
- **LineEntryEngine** manages the logical state (buffer of new moves) and computes which FEN to revert to.
- **RepertoireBrowserScreen** calls `_boardController.setPosition(result.fen)` with the FEN returned by the engine.

This works but requires the caller to manage position history externally. The drill screen uses a similar pattern: it saves `_preMoveFen` before each user turn and reverts to it after mistakes via `setPosition`.

### Key constraint: controller is position-only, not chess-game-aware

The controller holds a `Position` (board state at a single point in time), not a `Game` (a sequence of moves with history). It has no notion of "the sequence of moves that led here." Adding undo requires tracking previous positions, which is a new capability.

### Consumers and their undo needs

- **RepertoireBrowserScreen (edit mode):** Needs undo during line entry. Currently achieved via LineEntryEngine + setPosition. An `undo()` method on the controller would simplify the screen's `_onTakeBack` handler but is not strictly required since the engine already tracks what to revert to.
- **DrillScreen:** Does NOT need undo. Reverts to a known pre-move FEN after mistakes, which is a different pattern (revert to a specific point, not "undo the last thing").
- **RepertoireBrowserScreen (browse mode):** Uses setPosition for navigation (back/forward through tree nodes). This is not undo -- it's navigation to arbitrary positions.

### Design decision: history stack inside the controller

The task description asks whether the history stack belongs inside the controller (simpler API) or outside (more flexible for tree-based navigation). Given the existing usage patterns:
- The controller is used by multiple screens with different undo semantics.
- The LineEntryEngine already handles the logical undo (buffer management) and computes the revert FEN.
- Adding a history stack inside the controller keeps it self-contained and enables a simple `undo()` call without requiring callers to manage FEN history.
- The history stack should only record entries from `playMove()`, not from `setPosition()` or `resetToInitial()` (which represent jumps to arbitrary positions, not incremental moves that should be undoable).
- `setPosition()` and `resetToInitial()` should clear the history (they represent a position discontinuity).
