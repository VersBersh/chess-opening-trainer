# CT-58: Implementation Plan

## Goal

Add an app bar toggle to the Add Line screen that, when enabled, shows grey arrows on the chessboard for all existing repertoire moves at the current position, including transposition-equivalent moves, distinguishing direct children (darker) from transposition children (lighter).

## Steps

**Step 1: Add `showHintArrows` to `AddLineState`** (file: `src/lib/controllers/add_line_controller.dart`)

Add a `bool showHintArrows` field to `AddLineState`, defaulting to `false`. Add it to the constructor with `this.showHintArrows = false`. Every place that constructs a new `AddLineState(...)` must pass through the current value of `showHintArrows` (there are approximately 10 construction sites in the controller -- each creates a full `AddLineState(...)` with all fields).

**Step 2: Add toggle method to `AddLineController`** (file: `src/lib/controllers/add_line_controller.dart`)

Add a `void toggleHintArrows()` method that creates a new `AddLineState` with the `showHintArrows` field flipped, then calls `notifyListeners()`. Follow the same pattern as `flipBoard()`.

**Step 3: Add `getHintArrows()` method to `AddLineController`** (file: `src/lib/controllers/add_line_controller.dart`)

Add new imports: `dart:ui` for `Color`, `chessground` for `Arrow` and `Shape`, `fast_immutable_collections` for `ISet`/`ISetConst`, and `services/chess_utils.dart` for `sanToMove`.

Add a public method `ISet<Shape> getHintArrows()` that:

1. Returns `const ISetConst({})` if `!_state.showHintArrows` or `_state.treeCache == null`.
2. Determines the current position's FEN: use `_state.currentFen`.
3. Determines the current move ID at the focused pill (if any): use `getMoveIdAtPillIndex(_state.focusedPillIndex)` if `focusedPillIndex` is not null, otherwise null. This is null at the initial position and for unsaved pills.
4. Computes direct children:
   - If current move ID is not null: `cache.getChildren(currentMoveId)`.
   - If current move ID is null and `currentFen == kInitialFEN`: `cache.getRootMoves()`.
   - Otherwise (unsaved pill at a non-initial position): empty list.
5. Collects the set of direct-child move IDs into a `Set<int>` for fast membership testing: `final directChildIds = directChildren.map((m) => m.id).toSet()`.
6. Computes position-key children:
   - `positionKey = RepertoireTreeCache.normalizePositionKey(currentFen)`.
   - `allPositionChildren = cache.getChildrenAtPosition(positionKey)`.
   - If at initial position, also include root moves in the pool.
7. Parses the current position: `Chess.fromSetup(Setup.parseFen(currentFen))`.
8. Merges direct children and position-key children into a single iteration list. Process direct children first so their arrows take priority during deduplication.
9. Iterates over all moves, deduplicating by from/to/promotion triple:
   - For each child, calls `sanToMove(parentPosition, child.san)` to get the `NormalMove`.
   - Skips null results.
   - Builds a deduplication key: `"${move.from.name}-${move.to.name}-${move.promotion?.name ?? ''}"`. This includes the promotion piece so that distinct promotion moves on the same squares (e.g., promote to queen vs promote to knight) each get their own arrow.
   - Uses darker grey `Color(0x60000000)` if `directChildIds.contains(child.id)`, otherwise lighter grey `Color(0x30000000)` (transposition).
   - Creates `Arrow(color: color, orig: move.from, dest: move.to)`.
   - Uses a `Set<String>` with the dedup key to skip already-seen moves. Because direct children are processed first, a direct-child arrow is never overwritten by a lighter transposition arrow for the same move.
10. Returns `ISet(shapes)`.

**Step 4: Add app bar toggle button** (file: `src/lib/screens/add_line_screen.dart`)

In the `build` method, modify the `AppBar` to include an `actions` list with one `IconButton`:
- Icon: `_controller.state.showHintArrows ? Icons.visibility : Icons.visibility_off`
- Tooltip: `_controller.state.showHintArrows ? 'Hide existing moves' : 'Show existing moves'`
- `onPressed`: calls `_controller.toggleHintArrows()` (state update triggers rebuild via existing listener)

The toggle button should only be shown when `!state.isLoading` to avoid showing it during the loading state.

**Step 5: Pass arrows to `ChessboardWidget`** (file: `src/lib/screens/add_line_screen.dart`)

In both `_buildNarrowContent` and `_buildWideContent`, update the `ChessboardWidget` constructor calls to include:
```
shapes: _controller.getHintArrows(),
```

Since `getHintArrows()` returns `const ISetConst({})` when toggled off, and the `ChessboardWidget` already handles null/empty shapes gracefully, this is safe.

**Step 6: Write unit tests for arrow generation** (file: `src/test/controllers/add_line_controller_test.dart`)

Add a new `group('getHintArrows', ...)` with tests:

1. **Returns empty when toggled off** -- Create controller, load data with seeded moves, verify `getHintArrows()` returns empty ISet when `showHintArrows` is false (default).

2. **Shows root move arrows at initial position** -- Seed repertoire with two root moves (e.g., `e4` and `d4`). Toggle on, verify arrows for both root moves appear.

3. **Shows direct-child arrows with darker color** -- Seed `['e4', 'e5']` and `['e4', 'c5']`. Navigate to e4 pill. Toggle on. Verify two arrows appear with `Color(0x60000000)`.

4. **Shows transposition arrows with lighter color** -- Seed two lines reaching the same position via different move orders, and critically, seed at least one child move under the transposed node so there is something for `getChildrenAtPosition` to return. For example, seed `['e4', 'd6', 'd4', 'Nf6']` and `['d4', 'd6', 'e4', 'e5']`. Navigate to the `d4` node at the end of line A (the position after `1. e4 d6 2. d4`). Toggle on. The move `Nf6` is a direct child of the current node. The move `e5` is a child of the transposed node (line B's `e4`), so it should appear as a lighter arrow. This works because `getChildrenAtPosition` returns children OF nodes at the position -- both `Nf6` (child of line A's `d4`) and `e5` (child of line B's `e4`) are returned, and the direct-child ID set correctly distinguishes them.

5. **Distinguishes direct-child vs transposition arrows** -- Seed a position that has both direct children and transposition children. Verify correct colors using `directChildIds.contains()` logic.

6. **Updates arrows on pill tap** -- Tap a different pill, verify arrows change to reflect the new position.

7. **Returns empty when no existing moves at position** -- Play a new (buffered) move to a position with no existing children. Verify empty arrows.

**Step 7: Write widget test for toggle** (file: `src/test/screens/add_line_screen_test.dart`)

Add a new `group('hint arrows toggle', ...)` with tests:

1. **Toggle button appears in app bar** -- Verify an `IconButton` with the visibility icon exists in the app bar.

2. **Arrows appear/disappear on toggle** -- Seed moves, tap the toggle button, verify that `ChessboardWidget` receives a non-empty `shapes` parameter. Tap again, verify it receives empty/null shapes.

**Step 8: Update feature spec** (file: `features/add-line.md`)

Add a "## Hint Arrows" section describing:
- The toggle in the app bar (icon, tooltip, default state)
- What arrows are shown (all existing moves at the current position via position-key lookup)
- The colour distinction: darker grey (`0x60000000`) for direct children, lighter grey (`0x30000000`) for transposition children
- That arrows are display-only and do not affect move entry
- That arrows update on every position change (move, take-back, pill tap)
- That toggle state is local to the screen session (not persisted)

## Risks / Open Questions

1. **Initial position root-move handling**: `getChildrenAtPosition(normalizePositionKey(kInitialFEN))` returns empty because no move in the tree has the initial FEN as its resulting FEN. The implementation must special-case the initial position by using `getRootMoves()`. This is noted in Step 3 above.

2. **Deduplication of arrows**: When direct children and transposition children produce the same from/to/promotion triple (e.g., the same SAN move exists as both a direct child and a transposition child), the arrow should only appear once, with the darker (direct-child) color taking priority. The deduplication in Step 3 handles this by processing direct children first and keying on from/to/promotion.

3. **Performance on large trees**: `getChildrenAtPosition` iterates all nodes at a position key. For most repertoires this is a small set, but for heavily transposed openings it could return many children. Since this only runs on each position change (not on every frame), and the number of distinct arrows is bounded by the number of legal moves (~30-40), this should be fine.

4. **Focused pill at an unsaved (buffered) move**: When the user is at a buffered (unsaved) move's position, there is no move ID in the tree. The implementation should still show transposition arrows via `getChildrenAtPosition(positionKey)` -- all as lighter grey since there are no direct children. This is a useful case: it tells the user "this position exists in your repertoire via a different path."

5. **No `copyWith` on `AddLineState`**: Every state construction site in the controller must be updated to pass through `showHintArrows`. There are approximately 10 such sites. This is mechanical but must be done carefully to avoid breaking any state transition.

6. **Review fix: direct-child colour rule uses ID set membership, not parentMoveId comparison** (addresses review issue 1). The original plan used `child.parentMoveId == currentMoveId` to decide direct vs transposition colour. While this happens to work in most cases (including root position in Dart where `null == null` is `true`), it is fragile and indirect. The revised plan builds a `Set<int>` of direct-child IDs (Step 3.5) and checks `directChildIds.contains(child.id)` instead. This is explicit, works uniformly for root and non-root positions, and avoids any confusion about null semantics.
