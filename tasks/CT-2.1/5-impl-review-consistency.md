# CT-2.1 Implementation Review

## Verdict

**Approved with Notes**

## Progress

- [x] **Step 1: Add `getAggregateDisplayName` and `getMoveNotation` to `RepertoireTreeCache`** -- Done. Both methods implemented correctly. `getMoveNotation` extended with optional `plyCount` parameter (documented deviation #3).
- [x] **Step 2: Create `RepertoireBrowserState` model class** -- Done. Mutable data class in `repertoire_browser_screen.dart`. Matches the plan's field list (treeCache, expandedNodeIds, selectedMoveId, boardOrientation, dueCountByMoveId, isLoading). Adds `repertoireName` field not in plan but necessary for the AppBar title.
- [x] **Step 3: Create `MoveTreeWidget`** -- Done. Stateless widget with correct constructor parameters. `buildVisibleNodes` extracted as top-level function for testability (documented deviation #1). `VisibleNode` includes `plyCount` (documented deviation #2). Uses `ListView.builder` for efficient rendering.
- [x] **Step 4: Create `RepertoireBrowserScreen`** -- Done. StatefulWidget with AppBar, aggregate display name header, ChessboardWidget (read-only), navigation controls, action bar with stubs, and MoveTreeWidget in Expanded. All handlers implemented (node selection, toggle expand, flip board, forward/back navigation).
- [x] **Step 5: Wire navigation from `HomeScreen`** -- Done. `_onRepertoireTap` method matches the plan's code exactly (create default repertoire if none exist, navigate to first).
- [x] **Step 6: Unit tests for `getAggregateDisplayName` and `getMoveNotation`** -- Done. 7 test cases covering all specified scenarios plus extras (branching tree, plyCount parameter).
- [x] **Step 7: Unit tests for `MoveTreeWidget` / `buildVisibleNodes`** -- Done. 7 unit tests for `buildVisibleNodes` plus 7 widget tests for `MoveTreeWidget`. Covers empty tree, single node, collapsed/expanded, selective expansion, multiple roots, plyCount tracking, due badges, empty state, labeled nodes, selected node styling.
- [x] **Step 8: Widget tests for `RepertoireBrowserScreen`** -- Done. 10 test cases using in-memory Drift database. Covers loading indicator, node selection updates board, aggregate display name, expand/collapse, board flip, back navigation, forward at branch point, action button enabled/disabled states, empty repertoire, repertoire name in AppBar.

## Issues

### 1. Minor -- Initial expand state contradicts plan for label-free branches

**Files:** `src/lib/screens/repertoire_browser_screen.dart` (lines 117-135), `src/test/screens/repertoire_browser_screen_test.dart` (line 210-211 comment)

**Problem:** The plan (Step 4, point 4) and Risks section #5 state: "If a branch has no labeled nodes at all, it should remain collapsed at the root." However, `_computeInitialExpandState` expands ALL unlabeled nodes that have children, fully expanding branches with no labels. The browser screen test confirms this behavior ("No labels, so all nodes are auto-expanded initially").

**Impact:** For a repertoire with no labels, the entire tree is expanded on load, which may be unwieldy for large trees. However, for the typical v1 use case (small trees, labels added incrementally), this is a reasonable UX choice -- showing everything is arguably better than hiding everything when there are no labels to navigate to.

**Suggestion:** This is a deliberate UX deviation rather than a bug. Either update the plan to match the implementation, or add a guard: if a branch has no labeled descendants at all, don't expand it. Example fix:

```dart
void walk(List<RepertoireMove> nodes) {
  for (final node in nodes) {
    if (node.label != null) continue;
    final children = cache.getChildren(node.id);
    if (children.isNotEmpty && _hasLabeledDescendant(cache, node.id)) {
      expanded.add(node.id);
      walk(children);
    }
  }
}
```

### 2. Minor -- Duplicated `buildLine` test helper across three test files

**Files:** `src/test/services/drill_engine_test.dart`, `src/test/models/repertoire_tree_cache_test.dart`, `src/test/widgets/move_tree_widget_test.dart`

**Problem:** The `buildLine` helper function is duplicated in each test file (with slight variations -- the tree cache and move tree tests add `labels` support). If the helper needs to change (e.g., if `RepertoireMove` gains a new required field), it must be updated in three places.

**Suggestion:** Extract `buildLine` (and `buildBranch`) into a shared test utility file (e.g., `src/test/helpers/tree_test_helpers.dart`). This is low priority and purely a maintenance concern.

### 3. Minor -- Back navigation test assertion is weak

**File:** `src/test/screens/repertoire_browser_screen_test.dart` (lines 256-282)

**Problem:** The "back navigation selects parent node" test selects e5, then navigates back, then asserts the board FEN is `isNot(kInitialFEN)`. This assertion only proves the board is not at the starting position -- it doesn't verify the board shows the e4 position specifically. The assertion would pass even if back navigation was broken and the board still showed the e5 position (since both e4 and e5 positions are `isNot(kInitialFEN)`).

**Suggestion:** Capture the board FEN after selecting e5, then assert the FEN changed after pressing back:

```dart
final fenAfterE5 = tester.widget<Chessboard>(find.byType(Chessboard)).fen;
await tester.tap(find.byIcon(Icons.arrow_back));
await tester.pump();
final fenAfterBack = tester.widget<Chessboard>(find.byType(Chessboard)).fen;
expect(fenAfterBack, isNot(fenAfterE5));
```

### 4. Minor -- Impl notes claim drift import was added to home_screen.dart

**File:** `tasks/CT-2.1/4-impl-notes.md` (line 8)

**Problem:** The impl notes state "Added imports for drift, local_repertoire_repository, and repertoire_browser_screen" for home_screen.dart. However, `home_screen.dart` does not have a `drift` import (and doesn't need one since `RepertoiresCompanion.insert` takes a raw `String`). This is a documentation inaccuracy, not a code issue.

**Suggestion:** Remove the mention of drift from the impl notes for home_screen.dart.

### 5. Minor -- `RepertoireBrowserState` uses nullable `treeCache` instead of late initialization

**File:** `src/lib/screens/repertoire_browser_screen.dart` (line 23)

**Problem:** `RepertoireBrowserState.treeCache` is nullable (`RepertoireTreeCache?`) and force-unwrapped with `!` in `_buildContent` (line 211) and event handlers (lines 140, 171, 181). This is safe because `_buildContent` is only called when `isLoading == false`, but it's a mild code smell -- the null-safety contract is implicit rather than enforced by the type system.

**Impact:** Low. The loading guard prevents null access. This is consistent with the existing `StatefulWidget` patterns in the codebase.

**Suggestion:** No change needed for v1. When migrating to Riverpod, this will naturally become an `AsyncValue` where the loading/data/error states are explicit.

### 6. Minor -- No test for forward navigation with a single child

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

**Problem:** The plan specifies two forward navigation behaviors: (a) single child -> auto-select, (b) multiple children -> expand. The test for (b) exists ("forward at a branch point expands instead of selecting") but there is no test for (a) -- forward navigation auto-selecting the single child. The code at lines 184-186 of `repertoire_browser_screen.dart` implements this correctly, but it lacks test coverage.

**Suggestion:** Add a test case:

```dart
testWidgets('forward with single child auto-selects it', (tester) async {
  final repId = await seedRepertoire(db, lines: [['e4', 'e5']]);
  await tester.pumpWidget(buildTestApp(db, repId));
  await tester.pumpAndSettle();
  await tester.tap(find.text('1. e4'));
  await tester.pump();
  await tester.tap(find.byIcon(Icons.arrow_forward));
  await tester.pump();
  // Board should show position after e5
  // Selected node should be e5
});
```
