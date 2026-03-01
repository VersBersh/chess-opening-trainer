# CT-1.1 Implementation Notes

## Files Created or Modified

### Modified
- `src/pubspec.yaml` -- Added `fast_immutable_collections: ^11.0.0` as a direct dependency.

### Created
- `src/lib/widgets/chessboard_controller.dart` -- ChangeNotifier owning Position state with getters for fen, sideToMove, isCheck, validMoves, lastMove, and mutators setPosition(), playMove(), resetToInitial().
- `src/lib/widgets/chessboard_widget.dart` -- StatefulWidget wrapping chessground's Chessboard, bridging controller state to GameData, handling promotion flow and user move callbacks.
- `src/lib/services/chess_utils.dart` -- Pure function `sanToMove(Position, String)` using dartchess `parseSan()` to resolve SAN strings to NormalMove.
- `src/test/widgets/chessboard_controller_test.dart` -- Unit tests for ChessboardController: initial state, setPosition, playMove (legal/illegal), resetToInitial, listener notifications, isCheck, validMoves count, promotion.
- `src/test/services/chess_utils_test.dart` -- Unit tests for sanToMove: pawn moves, piece moves, invalid SAN, promotion SAN, capture SAN, castling SAN.
- `src/test/widgets/chessboard_widget_test.dart` -- Widget tests: renders Chessboard, orientation forwarded, position updates via controller, resetToInitial, playerSide none, shapes forwarded, default/custom ChessboardSettings.

## Deviations from Plan

1. **`onMove` callback signature** -- Changed from `{required bool isDrop}` to `{required bool isDrag}` per review item #2. The parameter indicates drag-and-drop vs tap-tap input, not a piece drop (Crazyhouse concept). The name `isDrag` matches chessground's `viaDragAndDrop` semantics.

2. **`sanToMove` simplified** -- No fallback iteration over legal moves. Per review item #3, `position.parseSan(san)` is a concrete method on `Position` in dartchess 0.12.1 and handles all standard SAN forms. The function simply delegates to it and type-checks the result.

3. **`playMove` uses `isLegal` check** -- Per review item #4, the controller calls `position.isLegal(move)` before `position.play(move)` instead of using try/catch on PlayException. This avoids exception-based control flow.

4. **`GameData.onMove` type handling** -- Per review item #1, the widget's `_onUserMove` receives `Move` (sealed class) and pattern-matches with `if (move is! NormalMove) return;` to handle the type safely.

5. **Castling test expectation** -- The castling SAN test ("O-O") expects the move target to be `Square.h1` (the rook square) because dartchess encodes castling as king-to-rook internally. This is correct for dartchess's internal representation; chessground's `makeLegalMoves` utility maps it to the conventional king destination (g1) for display.

## Follow-up Work

- **CT-1.3 / CT-2.x**: Consuming screens (DrillScreen, LineEntryScreen) need to use `ChessboardWidget` with appropriate `playerSide` and `onMove` callbacks. They will own the `ChessboardController` instance.
- **Take-back support**: The controller does not currently support undo/take-back. Line entry mode (CT-2.x) will need this. Options: maintain a move history stack in the controller, or let the parent manage position history externally via `setPosition()`.
- **Board sizing**: The widget uses `LayoutBuilder` to determine size. Parent screens must provide bounded constraints (e.g. via `SizedBox` or `Expanded` inside a `Column`).
