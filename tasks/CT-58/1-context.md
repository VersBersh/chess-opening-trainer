# CT-58: Context

## Relevant Files

- **`features/add-line.md`** -- Spec for the Add Line screen; needs a new "Hint Arrows" subsection added.
- **`features/line-management.md`** -- Broader line management spec; referenced for context but not modified.
- **`src/lib/controllers/add_line_controller.dart`** -- Add Line business logic controller. Arrow generation method will be added here. Contains `AddLineState` (needs new `showHintArrows` field) and all state mutation methods.
- **`src/lib/screens/add_line_screen.dart`** -- Add Line screen widget. Needs toggle icon button in the app bar and passing computed arrows to `ChessboardWidget`.
- **`src/lib/models/repertoire.dart`** -- `RepertoireTreeCache` with `getChildrenAtPosition(positionKey)`, `getChildren(moveId)`, `getRootMoves()`, `normalizePositionKey()`. Core lookup methods for finding existing moves at a position.
- **`src/lib/widgets/chessboard_widget.dart`** -- Already accepts `ISet<Shape>? shapes` parameter. No changes needed.
- **`src/lib/controllers/repertoire_browser_controller.dart`** -- Contains `getChildArrows()` (lines 267-298), the reference implementation for arrow generation. Uses `sanToMove()` and `Arrow` from chessground.
- **`src/lib/services/chess_utils.dart`** -- Contains `sanToMove(position, san)` utility for converting SAN to `NormalMove` with from/to squares.
- **`src/lib/services/line_entry_engine.dart`** -- `LineEntryEngine` with `existingPath`, `followedMoves`, `bufferedMoves`, `lastExistingMoveId`. Provides the data needed to determine the current tree node.
- **`src/test/controllers/add_line_controller_test.dart`** -- Existing unit tests for the controller; new arrow generation tests go here.
- **`src/test/screens/add_line_screen_test.dart`** -- Existing widget tests for the screen; toggle visibility tests go here.
- **`src/test/controllers/repertoire_browser_controller_test.dart`** -- Reference test patterns for arrow tests (group `'getChildArrows'`).

## Architecture

The Add Line subsystem is a move-entry screen backed by:

1. **`AddLineController`** (ChangeNotifier) -- holds immutable `AddLineState`, delegates move logic to `LineEntryEngine`, and exposes computed properties. Every state change constructs a new `AddLineState(...)` object (no `copyWith`).

2. **`LineEntryEngine`** -- pure business-logic service tracking three move lists: `existingPath` (root-to-startingMoveId), `followedMoves` (existing tree moves followed after start), and `bufferedMoves` (new unsaved moves). Tracks `lastExistingMoveId` as the current tree position.

3. **`RepertoireTreeCache`** -- eagerly-loaded index of the full move tree. Provides O(1) lookups by move ID, FEN, and normalized position key. `getChildrenAtPosition(positionKey)` returns children of ALL nodes at a position (including transpositions). `getChildren(moveId)` returns only direct children of a specific node. `getRootMoves()` returns children of the initial position.

4. **`AddLineScreen`** (ConsumerStatefulWidget) -- renders ChessboardWidget, move pills, action bar. `ChessboardWidget` already accepts `shapes: ISet<Shape>?` but the Add Line screen currently passes nothing.

5. **`ChessboardWidget`** -- wraps `chessground`'s `Chessboard`. The `shapes` parameter passes through directly to the underlying board for rendering arrows, circles, etc.

Key constraints:
- State is constructed as new `AddLineState(...)` objects (no copyWith pattern).
- Arrow computation needs the parent FEN (the position arrows originate from) and the tree cache.
- At the initial position, `getChildrenAtPosition` returns nothing because no move results in `kInitialFEN` -- root moves must be fetched via `getRootMoves()`.
- Arrow computation must distinguish direct children (same parent node) from transposition children (different parent, same position key) by color.
- The focused pill index and `getMoveIdAtPillIndex()` determine the current tree node for direct-child lookup.
