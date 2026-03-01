# CT-2.1 Implementation Notes

## Files Created or Modified

### Modified

- `src/lib/models/repertoire.dart` -- Added `getAggregateDisplayName(int moveId)` and `getMoveNotation(int moveId, {int? plyCount})` methods to `RepertoireTreeCache`.
- `src/lib/screens/home_screen.dart` -- Added `_onRepertoireTap()` handler that loads/creates a repertoire and navigates to `RepertoireBrowserScreen`. Added imports for `drift`, `local_repertoire_repository`, and `repertoire_browser_screen`.

### Created

- `src/lib/widgets/move_tree_widget.dart` -- `MoveTreeWidget` (stateless), `VisibleNode` model class, `buildVisibleNodes()` top-level function, and `_MoveTreeNodeTile` private widget.
- `src/lib/screens/repertoire_browser_screen.dart` -- `RepertoireBrowserScreen` (stateful), `RepertoireBrowserState` data class. Composes chessboard preview, aggregate display name header, action bar with stub buttons, navigation controls, and `MoveTreeWidget`.
- `src/test/models/repertoire_tree_cache_test.dart` -- Unit tests for `getAggregateDisplayName` and `getMoveNotation` (7 test cases).
- `src/test/widgets/move_tree_widget_test.dart` -- Unit tests for `buildVisibleNodes` (7 test cases) and widget tests for `MoveTreeWidget` (7 test cases).
- `src/test/screens/repertoire_browser_screen_test.dart` -- Widget tests for `RepertoireBrowserScreen` using in-memory Drift database (10 test cases).

## Deviations from Plan

1. **`_VisibleNode` renamed to `VisibleNode` and made public.** The plan described `_VisibleNode` as a private class inside `MoveTreeWidget`. Per review issue #9, `buildVisibleNodes` was extracted as a top-level function for testability, which required `VisibleNode` to also be public so tests can inspect the results.

2. **`plyCount` field added to `VisibleNode`.** Per review issue #1, the `plyCount` is computed during tree walk (as `depth + 1`) and stored on `VisibleNode`, then passed to `getMoveNotation` via the `plyCount` parameter. This avoids an O(depth) `getLine` call per visible node during rendering.

3. **`getMoveNotation` accepts optional `plyCount` parameter.** Per review issue #1, when `plyCount` is provided it is used directly instead of calling `getLine`. The fallback (calling `getLine`) is retained for callers that don't have the ply count readily available.

4. **`getChildren` called once per node in `buildVisibleNodes`.** Per review issue #3, the result is stored in a local variable and reused for both the `isNotEmpty` check and the recursive walk.

5. **Test directory `src/test/models/` created.** Per review issue #8, tree cache tests are placed in `src/test/models/repertoire_tree_cache_test.dart` rather than `src/test/services/`.

6. **`RepertoireBrowserState` is a mutable class, not immutable.** The plan described it as a "plain data class" but did not specify immutability. Since the current codebase uses `StatefulWidget` + `setState` (not Riverpod), a mutable state holder is the simplest approach. Fields are mutated directly and `setState` is called to trigger rebuilds.

7. **Browser screen test uses `seedRepertoire` helper with in-memory Drift DB.** The plan mentioned "mocking the database or repositories" but did not specify the approach. Using an in-memory `NativeDatabase.memory()` is more realistic than mocking, exercises the actual schema, and requires no mock framework.

## Follow-up Work

- **CT-2.2 (Edit mode):** Will wire the "Edit" action button's `onPressed` in `repertoire_browser_screen.dart`.
- **CT-2.3 (Labeling):** Will wire the "Label" action button's `onPressed`.
- **CT-2.4 (Deletion):** Will wire the "Delete" action button's `onPressed` with confirmation dialog.
- **CT-4 (Focus mode):** Will wire the "Focus" action button's `onPressed`.
- **Riverpod migration:** Both `HomeScreen` and `RepertoireBrowserScreen` create repositories inline. When Riverpod is adopted, both should be refactored to use providers.
- **Due-count performance:** Currently issues one `getCardsForSubtree` query per labeled node. For large trees, consider loading all cards once via `getAllCardsForRepertoire` and computing counts in-memory using `getSubtree`.
- **Line list view:** The spec describes a flat line-list view as an alternative to the tree view. Deferred from CT-2.1.
- **Swipe gesture navigation:** The spec mentions swipe gestures on mobile for forward/back. Only button navigation is implemented. Can be added with a `GestureDetector` wrapping the board.
- **Keyboard navigation:** Arrow key support for desktop/web is not implemented.
- **Tree cache rebuild on return from edit mode:** The browser screen loads data once in `initState`. When returning from edit mode (CT-2.2), the cache needs to be rebuilt. This will likely require adding a callback or using `didChangeDependencies`/`Navigator.pop` result.
