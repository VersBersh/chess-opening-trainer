# CT-11.3: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/add_line_screen.dart` | Screen widget; wires up ChessboardWidget, MovePillsWidget, and action buttons (Take Back, Confirm, Label, Flip). Delegates take-back to `AddLineController.onTakeBack`. |
| `src/lib/controllers/add_line_controller.dart` | Business logic controller for the Add Line screen. Owns `LineEntryEngine`, manages `AddLineState`, translates user actions (board move, pill tap, take-back, confirm) into engine calls and state updates. `onTakeBack` calls `engine.takeBack()` then `boardController.setPosition()`. |
| `src/lib/services/line_entry_engine.dart` | Pure business-logic service managing line entry state. Tracks `existingPath`, `followedMoves`, and `bufferedMoves`. `canTakeBack()` returns `_bufferedMoves.isNotEmpty`. `takeBack()` removes the last buffered move and returns a `TakeBackResult` with the FEN to revert to. |
| `src/lib/widgets/chessboard_controller.dart` | ChangeNotifier owning the chess `Position`. Provides `playMove()`, `setPosition()`, `undo()`, and `resetToInitial()`. `setPosition()` clears move history and sets `_lastMove = null`. `undo()` restores the previous position and `_lastMove` from history. |
| `src/lib/widgets/chessboard_widget.dart` | Stateful widget wrapping `chessground`. Listens to `ChessboardController` for position updates. Calls `controller.playMove()` on user moves, then invokes `onMove` callback to notify the screen. |
| `src/lib/widgets/move_pills_widget.dart` | Stateless widget rendering move pills as a wrapping row. Receives `List<MovePillData>` and `focusedIndex` from the parent. |
| `src/lib/models/repertoire.dart` | `RepertoireTreeCache` -- eagerly-loaded indexed view of the repertoire move tree. Provides path reconstruction, children lookups, leaf detection. |
| `src/test/services/line_entry_engine_test.dart` | Unit tests for `LineEntryEngine` including take-back scenarios (buffered moves, back to initial, branch boundary). |
| `src/test/controllers/add_line_controller_test.dart` | Integration tests for `AddLineController` including take-back with pill count verification. |
| `src/test/screens/add_line_screen_test.dart` | Widget tests for `AddLineScreen` including take-back button disabled state. |
| `features/add-line.md` | Spec: take-back works for all moves including the first; take-back is the only way to remove moves; no X on pills. |
| `features/line-management.md` | Spec: take-back removes last move from buffer, reverts board; disabled at starting position or branch point boundary. |
| `design/ui-guidelines.md` | Spec: no delete (X) on pills; Take Back is the only delete mechanism. |

## Architecture

### Subsystem Overview

The Add Line screen allows users to build repertoire lines by playing moves on a chessboard. The architecture has three main layers:

1. **Screen layer** (`AddLineScreen`): A `ConsumerStatefulWidget` that owns both an `AddLineController` and a `ChessboardController`. It wires up the chessboard widget, move pills, and action buttons. User actions flow from the screen to the controller.

2. **Controller layer** (`AddLineController`): A `ChangeNotifier` that manages `AddLineState` (immutable state class). It owns a `LineEntryEngine` and translates UI events into engine operations. It also coordinates with `ChessboardController` to keep the board in sync.

3. **Engine layer** (`LineEntryEngine`): A pure business-logic service (no Flutter dependencies) that tracks three move lists:
   - `existingPath` -- moves from root to the starting node (already in DB)
   - `followedMoves` -- existing tree moves the user followed after the starting position
   - `bufferedMoves` -- new moves not yet in the DB

### Move Flow

When a user plays a move on the board:
1. `ChessboardWidget._onUserMove` calls `controller.playMove(move)` on the `ChessboardController`, which updates the position and adds to the board's internal `_history`.
2. The `onMove` callback fires, reaching `AddLineScreen._onBoardMove`.
3. The screen calls `AddLineController.onBoardMove(move, boardController)`, which reads the resulting FEN from `boardController.fen`, computes SAN from `preMoveFen`, and calls `engine.acceptMove(san, resultingFen)`.
4. The engine either follows an existing tree branch (`FollowedExistingMove`) or buffers the move (`NewMoveBuffered`).
5. The controller rebuilds the pills list and updates `AddLineState`.

### Take-Back Flow (Current)

When Take Back is pressed:
1. `AddLineScreen._onTakeBack` calls `AddLineController.onTakeBack(boardController)`.
2. The controller calls `engine.takeBack()` which removes the last `_bufferedMoves` entry and returns a `TakeBackResult` with the FEN to revert to.
3. The controller calls `boardController.setPosition(result.fen)` to update the board.
4. The controller rebuilds the pills list and updates state.

### Key Constraints

- `canTakeBack()` on `LineEntryEngine` returns `_bufferedMoves.isNotEmpty` -- only buffered (new) moves can be taken back, never followed or existing moves.
- `ChessboardController.setPosition()` clears `_history` and sets `_lastMove = null`, so after a take-back the board shows no last-move highlight.
- `ChessboardController.undo()` preserves the previous `_lastMove` from history, providing a more natural visual transition, but is never called during the take-back flow.

### Identified Issues

**Issue 1: Take Back visual effect is unclear.** The controller calls `boardController.setPosition(fen)` which clears the board history and nulls `_lastMove`. This means after take-back, the board shows the correct position but with no last-move highlight at all. Compare this to `boardController.undo()` which restores the previous position AND the previous `_lastMove`, providing a clear visual transition. However, `undo()` only works for moves in the board controller's history, and `setPosition()` clears that history on every call, so after the first take-back, subsequent ones would fail with `undo()`.

The fundamental problem: the `ChessboardController` maintains its own independent move history via `playMove()`/`undo()`, but the Add Line controller uses `setPosition()` for take-back which destroys that history. The two state-management approaches conflict.

**Issue 2: Can't take back the first move.** The `LineEntryEngine.takeBack()` method correctly handles taking back to `kInitialFEN` (tested at engine level). The `AddLineController.onTakeBack()` calls `boardController.setPosition(result.fen)` which should work for `kInitialFEN`. However, the `canTakeBack` property on the controller delegates to `engine.canTakeBack()` which returns `_bufferedMoves.isNotEmpty`. For the first move to be in `_bufferedMoves`, the user must play a move that does NOT match an existing tree branch (i.e., a genuinely new move). If the first move matches an existing root move, it goes into `followedMoves` instead, and `canTakeBack()` returns false.

The spec says take-back should work for "all moves, including the very first move." The current logic correctly prevents taking back followed (existing) moves since those are at a "branch point boundary." However, when the tree is empty and the user's very first move is buffered, the engine does support take-back. The screen test only verifies the disabled state but never tests an actual first-move take-back at the widget level.

The real issue with the first move take-back may be related to how `boardController.setPosition(kInitialFEN)` interacts with the board rendering. After `setPosition(kInitialFEN)`, the board controller's state is identical to `Chess.initial`, but `_lastMove` is null and `_history` is empty. This is correct behavior -- the board should return to the initial position with no move highlight.

**Root cause theory:** The "take back doesn't work" issue is likely that `boardController.setPosition()` works correctly BUT the board controller's internal history gets out of sync with the engine's state. After a `setPosition()` call, the board controller has NO history. If the user then plays a new move, `playMove()` adds that single move to history. But the engine might have followed multiple moves before the user diverged. The board controller and engine track different histories, and `setPosition()` resets the board controller history each time it's called (including during `onPillTapped`).

The actual "doesn't work" symptom is most likely: **the board position does not update visually** because `setPosition()` with the same FEN as the current position (edge case) might not trigger a rebuild, or there's a timing issue. Or, more likely, the board does update but there's no visual feedback (no animation, no highlight) so it *appears* to do nothing even though pills correctly shrink.
