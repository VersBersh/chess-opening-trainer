# CT-44: Implementation Plan

## Goal

Enable arrow-based branch visualization and default-line forward navigation in the Repertoire Browser, so users can see all continuation arrows on the board, tap arrows to follow a branch, and press forward to walk the default line through branch points.

## Steps

### Step 1: Add methods to compute arrow shapes and resolve tapped squares

**File:** `src/lib/controllers/repertoire_browser_controller.dart`

Add `getChildArrows()` returning `ISet<Shape>` for the current position:
- If `treeCache` is null, return empty `ISet`.
- Get children from cache: if `selectedMoveId != null`, use `cache.getChildren(selectedId)`; else use `cache.getRootMoves()`.
- If children is empty, return empty `ISet`.
- Determine parent FEN: if selected, use `cache.movesById[selectedId]!.fen`; else `kInitialFEN`.
- Parse parent FEN into a `Position`. Use `Chess.fromSetup(Setup.parseFen(parentFen))`.
- For each child, call `sanToMove(parentPosition, child.san)` to get source/dest squares. **If `sanToMove` returns null (invalid/corrupt SAN), skip that child** — do not assert or throw.
- First child (i==0) gets `Color(0x60000000)` (darker gray), rest get `Color(0x30000000)` (lighter gray).
- Return `ISet<Shape>` of `Arrow` objects.

Add `getChildMoveIdByDestSquare(Square dest)` returning `int?`:
- If `treeCache` is null, return null.
- Same child/parent resolution as above.
- Iterate children, call `sanToMove` for each. **Skip children where `sanToMove` returns null.**
- Return the first child's ID whose `normalMove.to == dest`, or null if no match.

**Imports needed:** `dart:ui` (Color), chessground models (Arrow, Shape), fast_immutable_collections (ISet), dartchess (Chess, Setup, Square, kInitialFEN), `chess_utils.dart` (sanToMove).

### Step 2: Change `navigateForward()` to always advance at branch points

**File:** `src/lib/controllers/repertoire_browser_controller.dart`

Modify `navigateForward()` so that multi-child branches no longer return `null`. Instead, always select `children.first` (the default line). Keep the tree-expand side-effect for multi-child so the sidebar stays useful.

Also handle `selectedMoveId == null` (initial position): get root moves and select the first one.

### Step 3: Update `navigateBack()` for root moves

**File:** `src/lib/controllers/repertoire_browser_controller.dart`

When the selected move has no parent (it's a root move), clear the selection (`selectedMoveId = null`) and return `kInitialFEN`. This lets users navigate back to the initial position after stepping forward from it.

### Step 4: Add `onTouchedSquare` support to `ChessboardWidget`

**File:** `src/lib/widgets/chessboard_widget.dart`

Add an `onTouchedSquare` parameter (`void Function(Square)?`) and pass it through to the chessground `Chessboard` widget in the build method.

### Step 5: Add `shapes` and `onTouchedSquare` to `BrowserChessboard`

**File:** `src/lib/widgets/browser_board_panel.dart`

Extend `BrowserChessboard` constructor and fields to accept `shapes: ISet<Shape>?` and `onTouchedSquare: void Function(Square)?`. Pass both through to `ChessboardWidget`.

**Depends on:** Step 4.

### Step 6: Wire shapes and square tap callback through `BrowserContent`

**File:** `src/lib/widgets/browser_content.dart`

Add new parameters to `BrowserContent`: `shapes: ISet<Shape>?` and `onSquareTapped: void Function(Square)?`.

**Import updates:** Add `import 'package:chessground/chessground.dart';` (for `Shape`, `ISet`) and `import 'package:dartchess/dartchess.dart';` (for `Square`) if not already present.

Update `_canNavigateForward` to also be true when no move is selected but root moves exist.

Update `_canNavigateBack` to be true whenever there is a selection (so back works from root moves).

Pass `shapes` and `onSquareTapped` to `BrowserChessboard` in both narrow and wide layout builders.

**Depends on:** Step 5.

### Step 7: Compute shapes and handle square taps in the screen

**File:** `src/lib/screens/repertoire_browser_screen.dart`

**Import updates:** Add `import 'package:chessground/chessground.dart';` and `import 'package:dartchess/dartchess.dart';` if not already present (needed for `Square` type in callback signature).

Add `_onSquareTapped(Square square)` handler: calls `_controller.getChildMoveIdByDestSquare(square)`, and if non-null, calls `_onNodeSelected(moveId)` to navigate.

Pass `_controller.getChildArrows()` as `shapes` and `_onSquareTapped` as `onSquareTapped` to `BrowserContent`.

**Depends on:** Steps 1, 6.

### Step 8: Update and add controller tests

**File:** `src/test/controllers/repertoire_browser_controller_test.dart`

1. Update existing test for "expands node with multiple children and returns null" — now it should assert `navigateForward()` returns a non-null FEN and selects the first child.
2. Add controller tests:
   - `navigateForward` selects first child at branch point
   - `navigateForward` from null selection selects first root move
   - `navigateBack` from root move clears selection and returns initial FEN
   - `getChildArrows` returns arrows for children of selected node
   - `getChildArrows` returns arrows for root moves when no selection
   - `getChildArrows` first child arrow is darker color
   - `getChildMoveIdByDestSquare` returns correct move ID
   - `getChildMoveIdByDestSquare` returns null for non-child squares

**Depends on:** Steps 1, 2, 3.

### Step 9: Add screen-level widget tests

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

Add widget tests covering the new UI wiring:
- Verify that arrows are rendered on the board when a move with children is selected (check that `shapes` is passed to the board widget).
- Verify that forward button navigates the default line at branch points (tap forward, check board position updates).
- Verify back navigation from a root move returns to initial position.

These tests follow existing patterns in the file (which already tests the repertoire browser screen).

**Depends on:** Steps 1-7.

## Risks / Open Questions

1. **SAN parsing ambiguity for arrow taps:** When two child moves share the same destination square (e.g., different pieces moving to the same square), tapping that square is ambiguous. The plan resolves by selecting the first match. A more precise approach would match on both `orig` and `dest`, but that requires tracking which part of the arrow was tapped. Destination-only matching should suffice for initial implementation.

2. **Arrow tap uses `onTouchedSquare`:** This fires on the destination square, not on the arrow itself. Tapping an empty square that is an arrow's dest will navigate. This is actually intuitive (tap where the piece goes), but is not true "arrow hit testing."

3. **Performance:** `getChildArrows()` parses SAN strings on every rebuild. For typical repertoires (≤5 children at a branch), this is negligible. Could cache in state if needed.

4. **Tree expand side-effect:** The plan keeps tree-expand when navigating forward at branch points. Remove the `expandedNodeIds` update if this is not wanted.

5. **Color tuning:** `Color(0x60000000)` and `Color(0x30000000)` may need visual adjustment for different board themes.
