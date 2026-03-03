# CT-44: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/controllers/repertoire_browser_controller.dart` | Controller owning `RepertoireBrowserState` with `navigateForward()`, `navigateBack()`, `selectNode()`, and tree cache. Core file for navigation logic changes. |
| `src/lib/widgets/browser_board_panel.dart` | `BrowserChessboard` (wraps `ChessboardWidget` with `PlayerSide.none`), `BrowserBoardControls` (back/flip/forward buttons), `BrowserDisplayNameHeader`. |
| `src/lib/widgets/chessboard_widget.dart` | Generic chessboard widget wrapping chessground `Chessboard`. Accepts `shapes: ISet<Shape>?` but does not currently expose `onTouchedSquare`. |
| `src/lib/widgets/browser_content.dart` | Responsive layout widget composing board, action bar, and move tree. Computes `_canNavigateForward`/`_canNavigateBack` booleans and wires callbacks. |
| `src/lib/screens/repertoire_browser_screen.dart` | Top-level screen. Creates controller and board controller. Contains `_onNavigateForward()` and `_onNodeSelected()` event handlers that update board position. |
| `src/lib/models/repertoire.dart` | `RepertoireTreeCache` with `getChildren(moveId)`, `getRootMoves()`, `movesById`, child ordering by `sortOrder`. |
| `src/lib/services/chess_utils.dart` | `sanToMove(Position, String)` — resolves SAN string to `NormalMove` with `.from`/`.to` `Square` fields. |
| `src/lib/widgets/chessboard_controller.dart` | `ChessboardController` — owns chess `Position`, exposes `fen`, `setPosition()`. Needed to get current position for SAN parsing. |
| `src/lib/screens/drill_screen.dart` | Reference implementation for building `ISet<Shape>` arrow overlays (lines 306-330). |
| `src/test/controllers/repertoire_browser_controller_test.dart` | Existing tests for `navigateForward`, `navigateBack`, `selectNode`. Must be updated for new forward behavior. |
| chessground `models.dart` | `Arrow` class: `Arrow({required Color color, required Square orig, required Square dest, double scale = 1.0})`. Also `Shape` sealed class. |
| chessground `board.dart` | `Chessboard` widget with `shapes: ISet<Shape>?` and `onTouchedSquare: void Function(Square)?` callback. |

## Architecture

The Repertoire Browser is a screen that lets users visually explore their chess repertoire tree. The architecture follows a controller + state pattern:

**Data flow:**
1. `RepertoireBrowserController` (a `ChangeNotifier`) loads moves from the database, builds a `RepertoireTreeCache`, and maintains immutable `RepertoireBrowserState`.
2. `RepertoireBrowserScreen` (a `ConsumerStatefulWidget`) creates the controller and a `ChessboardController`. It listens to controller changes and calls `setState()`.
3. `BrowserContent` (a stateless widget) receives state, cache, and callbacks. It computes derived presentation values (display name, button enable states) and handles narrow/wide layout.
4. `BrowserChessboard` wraps `ChessboardWidget` which wraps chessground's `Chessboard`.

**Navigation model:**
- `navigateForward()` currently auto-advances for single-child nodes and merely expands the tree node for multi-child (branch) nodes — it returns `null` in the branch case, so the board position does not change.
- `navigateBack()` always selects the parent move.
- The screen layer converts returned FEN strings into `_boardController.setPosition(fen)` calls.

**Shape system:**
- The chessground library's `Chessboard` widget accepts `shapes: ISet<Shape>?` where `Shape` is a sealed class with `Arrow`, `Circle`, and `PieceShape` subtypes.
- `Arrow` takes `orig` (Square), `dest` (Square), and `color` (Color).
- The `ChessboardWidget` wrapper already accepts and passes through `shapes`, but `BrowserChessboard` does not currently use it.
- Chessground also has an `onTouchedSquare` callback that fires on any pointer-down event regardless of `PlayerSide`, but `ChessboardWidget` does not currently expose it.

**Key constraint:** Each `RepertoireMove` stores a `fen` (the position *after* the move) and a `san` string. To compute arrow source/dest squares, we need to parse the SAN against the *parent* position (the position *before* the move was played). The parent's FEN is available via `movesById[move.parentMoveId]?.fen` or `kInitialFEN` for root moves.
