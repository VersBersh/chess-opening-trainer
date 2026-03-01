# CT-1.1 Plan

## Goal

Create a reusable `ChessboardWidget` that wraps chessground and dartchess, exposing a clean API for rendering positions, accepting user moves with legality validation, programmatic move execution, and visual highlights (last move, arrows, annotations).

## Steps

1. **Add `fast_immutable_collections` as a direct dependency in `src/pubspec.yaml`.**
   - File: `src/pubspec.yaml`
   - Add `fast_immutable_collections: ^11.0.0` under `dependencies`. Already a transitive dep from chessground/dartchess but needed directly since the wrapper's public API uses `IMap`, `ISet`.

2. **Create `ChessboardController` class in `src/lib/widgets/chessboard_controller.dart`.**
   - A `ChangeNotifier` that owns the `Position` state and exposes:
     - `Position get position`
     - `String get fen`
     - `Side get sideToMove`
     - `bool get isCheck`
     - `ValidMoves get validMoves`
     - `Move? get lastMove`
     - `void setPosition(String fen)` — parse FEN, update position, notify listeners
     - `bool playMove(NormalMove move)` — validate and play a move, notify listeners. Returns true if legal.
     - `void resetToInitial()` — convenience for setPosition(kInitialFEN)
   - Follows Flutter's controller pattern (like `TextEditingController`, `ScrollController`).
   - Parent widgets (DrillController, LineEntryController) own and manage the controller instance.

3. **Create the `ChessboardWidget` StatefulWidget in `src/lib/widgets/chessboard_widget.dart`.**
   - File to create: `src/lib/widgets/chessboard_widget.dart`
   - Constructor parameters:
     - `ChessboardController controller` (required) — source of truth for position state
     - `Side orientation` — which side at bottom (default `Side.white`)
     - `PlayerSide playerSide` — which side the user can interact with (`.white`, `.black`, `.both`, `.none`)
     - `void Function(NormalMove move, {required bool isDrop})? onMove` — callback after a legal user move
     - `Move? lastMoveOverride` — optional externally-provided last move highlight
     - `ISet<Shape>? shapes` — arrows, circles for correction hints
     - `ChessboardSettings? settings` — optional board theme/behavior settings
   - Internal `_onUserMove` handler:
     - Receives `Move` from chessground
     - For promotion pawns (pawn reaching rank 1/8 without promotion role): store as `_promotionMove`, return (chessground shows promotion dialog)
     - Otherwise: call `controller.playMove(move)`, invoke `onMove` callback
   - Internal `_onPromotionSelection` handler:
     - Cancelled: clear `_promotionMove`
     - Selected: create final move with promotion role, play via controller, invoke `onMove`
   - `initState`/`dispose`: listen to controller via `addListener`/`removeListener`
   - Build method:
     - `LayoutBuilder` to determine available size
     - Return `Chessboard` with: size, orientation, fen from controller, lastMove, shapes, annotations, `GameData` with playerSide, sideToMove, validMoves, isCheck, promotionMove, onMove, onPromotionSelection

4. **Create SAN-to-Move utility function in `src/lib/services/chess_utils.dart`.**
   - Function: `NormalMove? sanToMove(Position position, String san)`
   - Uses dartchess's SAN parsing if available (`position.parseSan(san)` or PGN module)
   - Fallback: iterate `position.legalMoves`, play each candidate, generate SAN, return matching move
   - Handles promotion SANs (e.g., "a8=Q")
   - Pure function, no state.

5. **Write unit tests for `ChessboardController` in `src/test/widgets/chessboard_controller_test.dart`.**
   - Pure Dart tests:
     - Initial state: position is initial, fen is initial, sideToMove is white
     - `setPosition()` with a known FEN updates position correctly
     - `playMove()` with legal move updates position, returns true
     - `playMove()` with illegal move returns false, position unchanged
     - `resetToInitial()` restores initial position
     - Controller notifies listeners on state changes

6. **Write unit tests for `sanToMove` utility in `src/test/services/chess_utils_test.dart`.**
   - Tests:
     - `sanToMove` with "e4" from initial position returns correct NormalMove
     - `sanToMove` with "Nf3" returns correct knight move
     - `sanToMove` with invalid SAN returns null
     - `sanToMove` with promotion SAN returns move with promotion role

7. **Write widget tests for `ChessboardWidget` in `src/test/widgets/chessboard_widget_test.dart`.**
   - Tests should cover:
     - Board renders with initial position
     - Board renders with configured orientation
     - Setting new FEN via controller updates displayed position
     - Programmatic move via `controller.playMove()` updates position and FEN
     - `resetToInitial()` returns to starting position
     - `playerSide` set to `.none` prevents interaction
     - Shapes are forwarded to chessground
   - Per testing strategy: don't test dartchess or chessground internals
   - Depends on: Steps 2, 3

## Risks / Open Questions

1. **Controller pattern vs. Riverpod.** The plan proposes a `ChangeNotifier` controller (Flutter convention for widget-level state). The architecture doc specifies Riverpod. Recommendation: keep the controller as a plain `ChangeNotifier`, and let Riverpod notifiers (DrillController, LineEntryController) own the controller instance. This keeps the widget framework-agnostic and testable.

2. **SAN-to-Move resolution.** dartchess may or may not expose `parseSan()` directly. Need to verify during implementation. If available, use it; otherwise iterate legal moves.

3. **Chessground `size` parameter.** The widget must determine available size at build time via `LayoutBuilder`. Parent screens must cooperate with sizing. This is a layout concern for consuming screens (CT-1.3, CT-2.x).

4. **Promotion during programmatic moves.** When the drill engine auto-plays a promotion move, the controller's `playMove()` should handle it silently (move already has promotion role set), not show the promotion selector.

5. **Board FEN format.** Chessground's `readFen()` accepts full FEN (extracts board part). dartchess `Position.fen` returns full FEN. No conversion needed.
