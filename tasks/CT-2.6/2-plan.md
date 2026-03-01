# CT-2.6 Plan

## Goal

Add a move history stack and `undo()` method to `ChessboardController` so that moves played via `playMove()` can be reverted, restoring the previous position, side to move, last-move highlight, and legal moves.

## Steps

### 1. Add a position history stack to `ChessboardController`

**File:** `src/lib/widgets/chessboard_controller.dart`

Add a private field to track previous positions:

```dart
final List<_HistoryEntry> _history = [];
```

Define a private helper class (or use a record) within the file to store the state needed to restore a position:

```dart
class _HistoryEntry {
  final Position position;
  final NormalMove? lastMove;
  const _HistoryEntry({required this.position, this.lastMove});
}
```

This stores the `Position` and `lastMove` that were active *before* the most recent `playMove()` call. The `_validMovesCache` does not need to be stored -- it is derived and will be recomputed on undo.

**Depends on:** Nothing.

### 2. Modify `playMove()` to push history entries

**File:** `src/lib/widgets/chessboard_controller.dart`

Before applying the move, push the current state onto the history stack:

```dart
bool playMove(NormalMove move) {
  if (!_position.isLegal(move)) return false;
  _history.add(_HistoryEntry(position: _position, lastMove: _lastMove));
  _position = _position.play(move);
  _lastMove = move;
  _validMovesCache = null;
  notifyListeners();
  return true;
}
```

Only `playMove()` pushes to the history. `setPosition()` and `resetToInitial()` do not push -- they represent position jumps/resets, not incremental moves.

**Depends on:** Step 1.

### 3. Implement the `undo()` method

**File:** `src/lib/widgets/chessboard_controller.dart`

Add a public method that pops the last history entry and restores the position:

```dart
/// Reverts to the position before the most recent [playMove] call.
///
/// Returns `true` if a move was undone. Returns `false` (no-op) if there
/// is no history to undo.
bool undo() {
  if (_history.isEmpty) return false;
  final entry = _history.removeLast();
  _position = entry.position;
  _lastMove = entry.lastMove;
  _validMovesCache = null;
  notifyListeners();
  return true;
}
```

Returning a `bool` makes it easy for callers to check whether undo had any effect, consistent with the `playMove()` return pattern.

**Depends on:** Steps 1, 2.

### 4. Add `canUndo` getter

**File:** `src/lib/widgets/chessboard_controller.dart`

Add a read-only property:

```dart
/// Whether there is at least one move in the history that can be undone.
bool get canUndo => _history.isNotEmpty;
```

This allows UI code (e.g., enabling/disabling an undo button) to check without attempting the operation.

**Depends on:** Step 1.

### 5. Clear history on `setPosition()` and `resetToInitial()`

**File:** `src/lib/widgets/chessboard_controller.dart`

Both methods jump to an arbitrary position, breaking the move-by-move continuity. The history stack should be cleared to prevent undoing into a position from a different context.

**`setPosition(fen)` -- parse-then-mutate for atomicity:** The current implementation calls `Chess.fromSetup(Setup.parseFen(fen))` which can throw `FenException` (from `Setup.parseFen`) or `PositionSetupException` (from `Chess.fromSetup`) on invalid input. All state mutations (clearing history, updating `_position`, `_lastMove`, cache) must happen only *after* the FEN has been successfully parsed, so that a failed call leaves the controller completely unchanged (including its undo history).

Rewrite `setPosition` as:

```dart
void setPosition(String fen) {
  final newPosition = Chess.fromSetup(Setup.parseFen(fen));
  _history.clear();
  _position = newPosition;
  _lastMove = null;
  _validMovesCache = null;
  notifyListeners();
}
```

The key change: `parseFen` and `fromSetup` are called into a local variable *before* any state is modified. If either throws, the method exits via the exception and no fields have been touched.

In `resetToInitial()`, add `_history.clear();` before the existing logic. (`resetToInitial` uses `Chess.initial` which is a compile-time constant, so there is no failure path to worry about.)

**Depends on:** Step 1.

### 6. Write unit tests for undo functionality

**File:** `src/test/widgets/chessboard_controller_test.dart`

Add tests within the existing `'ChessboardController'` group:

- **undo after a single move:** Play e2-e4, call `undo()`. Verify returns `true`, position reverts to initial, `sideToMove` is white, `lastMove` is `null` (matching the state before any move was played), `fen` equals `kInitialFEN`.
- **undo after multiple moves:** Play e2-e4, then d7-d5 (switch to black's perspective via `sideToMove` check). Call `undo()` once. Verify position is after e2-e4 (black to move), `lastMove` is the e2-e4 move. Call `undo()` again. Verify initial position.
- **undo with no history is a no-op:** Call `undo()` on a fresh controller. Verify returns `false`, position unchanged, no listener notification.
- **undo after setPosition clears history:** Play e2-e4, then call `setPosition(someFen)`. Call `undo()`. Verify returns `false` (history was cleared by setPosition).
- **undo after resetToInitial clears history:** Play e2-e4, then call `resetToInitial()`. Call `undo()`. Verify returns `false`.
- **canUndo is false initially:** Fresh controller, `canUndo` is `false`.
- **canUndo is true after playMove:** Play a move, `canUndo` is `true`.
- **canUndo is false after all undos:** Play e2-e4, `undo()`, `canUndo` is `false`.
- **canUndo is false after setPosition:** Play e2-e4, `setPosition(fen)`, `canUndo` is `false`.
- **undo notifies listeners:** Play a move, add listener, call `undo()`. Verify listener was called.
- **undo does not notify when no history:** Add listener, call `undo()`. Verify listener was NOT called.
- **undo restores correct legal moves:** Play e2-e4 (now it is black's turn with black's legal moves). Call `undo()`. Verify `validMoves` matches white's 20 initial legal moves.
- **undo after illegal move attempt:** Attempt an illegal move (returns false, no state change). Verify `canUndo` is still false (illegal moves don't push to history).
- **setPosition with invalid FEN preserves history and state:** Play e2-e4 (so `canUndo` is `true` and position is after e4). Call `setPosition` with an invalid FEN string (e.g., `'not-a-fen'`). Verify that `FenException` is thrown, `canUndo` is still `true`, `fen` still matches the post-e4 position, and `lastMove` is still the e2-e4 move. This validates the parse-then-mutate atomicity from Step 5.

**Depends on:** Steps 1-5.

### 7. (Optional) Simplify `_onTakeBack` in RepertoireBrowserScreen to use `undo()`

**File:** `src/lib/screens/repertoire_browser_screen.dart`

The current `_onTakeBack` handler calls `engine.takeBack()` to get a FEN, then calls `_boardController.setPosition(result.fen)`. This works but has a subtle issue: `setPosition()` clears the controller's new history stack, so interleaving `playMove()` + `setPosition()` means the controller's history is always empty.

There are two options:

**Option A (Recommended): Keep the current approach unchanged.** The LineEntryEngine already handles the logical take-back and provides the correct FEN. The `setPosition()` call resets the board to that FEN. The controller's history stack is cleared each time, but that's fine because take-back logic is owned by the engine, not the controller. The `undo()` method on the controller is available for other consumers (or future use) but the browser screen does not need to use it.

**Option B: Use `undo()` instead of `setPosition()`.** Change `_onTakeBack` to call `_boardController.undo()` instead of `_boardController.setPosition(result.fen)`. This would use the controller's history stack directly. However, this creates a coupling: the controller's history must stay in sync with the engine's buffer. If the engine says `canTakeBack() == false` but the controller still has history (e.g., from following existing moves), there would be a mismatch. The engine's take-back boundary (only buffered moves, not followed existing moves) would need to be enforced at the controller level too, which is fragile.

**Decision: Option A.** Do not change the browser screen. The controller's `undo()` method is a general-purpose capability exposed for consumers that manage positions purely through `playMove()` without an external engine. The line entry flow has its own take-back logic via LineEntryEngine.

**Depends on:** Steps 1-5 (the decision is to make no changes here, but document the reasoning).

## Risks / Open Questions

1. **Memory usage of unbounded history.** The history stack stores `Position` objects (which are lightweight immutable value objects in dartchess -- they hold a `Board` bitmask, turn, castling rights, etc., not move trees). For typical chess lines (< 100 moves), memory is negligible. No cap is needed for v1. If a consumer plays thousands of moves without clearing (unlikely), the stack would grow but each entry is small (under 200 bytes).

2. **History semantics for `setPosition` and `resetToInitial`.** The plan clears history on both. An alternative is to push a history entry before `setPosition` so it can be undone. However, `setPosition` is used for navigation jumps (e.g., clicking a tree node) which are not "moves" in the undo sense. Clearing is the safer and more intuitive default. Callers who need "undo navigation" can manage their own stack externally (as the browser screen already does with tree node selection).

3. **Interaction with the `_preMoveFen` pattern.** The drill screen and browser screen both maintain a `_preMoveFen` field for SAN computation (the FEN before the last move, needed to convert a `NormalMove` back to SAN). After an `undo()`, the `_preMoveFen` would need to be updated to match the restored position. Since the plan recommends not changing the browser screen's take-back flow (it continues using `setPosition`), this is not an issue now. But if a future consumer uses `undo()`, they must update their `_preMoveFen` accordingly.

4. **`lastMove` restoration.** After `undo()`, the `lastMove` is restored to whatever it was before the undone move was played. If only one move was played and then undone, `lastMove` becomes `null` (the initial state). If two moves were played and the second is undone, `lastMove` becomes the first move. This correctly re-highlights the previous move on the board, matching user expectations.

5. **Thread safety / reentrancy.** The controller is a synchronous `ChangeNotifier` used only on the main isolate. There are no concurrency concerns with the history stack.

6. **Atomicity of `setPosition` on invalid FEN (review issue #1).** The original plan placed `_history.clear()` before FEN parsing, which would destroy undo history if the FEN was invalid and parsing threw. The revised plan (Step 5) parses into a local variable first, then mutates state only on success. This makes `setPosition` atomic with respect to failures: either all state updates happen (valid FEN) or none do (invalid FEN throws). The same concern does not apply to `resetToInitial()` because it uses the compile-time constant `Chess.initial`.
