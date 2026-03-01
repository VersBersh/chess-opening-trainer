# CT-2.1 Implementation Review -- Design

## Verdict

**Approved with Notes**

The implementation is well-structured and follows the plan closely. The code is readable, the responsibilities are clearly separated between `RepertoireTreeCache` (data/query), `MoveTreeWidget` (presentation), and `RepertoireBrowserScreen` (orchestration). The plan review issues were addressed. The issues below are mostly Minor, with one Major item around state modeling that warrants attention before the next task builds on this code.

## Issues

### 1. Major -- `RepertoireBrowserState` is a mutable bag of fields with no encapsulation (Single Responsibility, Data Structures)

**File:** `src/lib/screens/repertoire_browser_screen.dart`, lines 22-30

```dart
class RepertoireBrowserState {
  RepertoireTreeCache? treeCache;
  Set<int> expandedNodeIds = {};
  int? selectedMoveId;
  Side boardOrientation = Side.white;
  Map<int, int> dueCountByMoveId = {};
  bool isLoading = true;
  String repertoireName = '';
}
```

This class has no encapsulation -- all fields are public, mutable, and non-final. It is instantiated once and mutated in-place across six different methods (`_loadData`, `_onNodeSelected`, `_onNodeToggleExpand`, `_onFlipBoard`, `_onNavigateBack`, `_onNavigateForward`). The internal collections (`expandedNodeIds`, `dueCountByMoveId`) leak their mutable structure to any consumer.

**Why it matters:** When CT-2.2, CT-2.3, and CT-2.4 wire up their action handlers, they will add more mutation sites against this same object. The mutable-everything design makes it easy to introduce inconsistent state (e.g., `selectedMoveId` pointing to a node not in `treeCache` after a deletion). With Riverpod migration planned, this class will need to become immutable state anyway.

**Suggested fix:** Make all fields `final` and use a `copyWith` pattern, or at minimum make the class fields private and expose mutation through named methods that enforce invariants. The `isLoading` / `treeCache` nullable pairing is a loading-state discriminated union waiting to happen -- consider `sealed class` or at least separate the loading and loaded states. This does not need to block this task, but should be addressed before CT-2.4 (deletion) adds state transitions that modify the tree.

### 2. Minor -- `RepertoireBrowserState` colocated in the screen file (File Organization)

**File:** `src/lib/screens/repertoire_browser_screen.dart`

The `RepertoireBrowserState` class is defined at the top of the screen file. This is fine for now at 353 lines, but the file is already at the 300-line threshold. When action handlers for CT-2.2 through CT-2.4 are added, this file will grow. Consider extracting `RepertoireBrowserState` to its own file when it becomes an immutable data class with `copyWith`.

### 3. Minor -- `_loadData` mixes orchestration with per-node query logic (Abstraction Levels)

**File:** `src/lib/screens/repertoire_browser_screen.dart`, lines 74-114

```dart
Future<void> _loadData() async {
  final repRepo = LocalRepertoireRepository(widget.db);
  final reviewRepo = LocalReviewRepository(widget.db);
  final repertoire = await repRepo.getRepertoire(widget.repertoireId);
  final allMoves = await repRepo.getMovesForRepertoire(widget.repertoireId);
  final cache = RepertoireTreeCache.build(allMoves);
  final expandedIds = _computeInitialExpandState(cache);

  // Low-level: iterating over moves and issuing per-node queries
  final dueCountMap = <int, int>{};
  for (final move in allMoves) {
    if (move.label != null) {
      final cards = await reviewRepo.getCardsForSubtree(move.id, dueOnly: true);
      if (cards.isNotEmpty) {
        dueCountMap[move.id] = cards.length;
      }
    }
  }
  ...
}
```

This method mixes high-level orchestration (load repertoire, build cache, compute expand state) with low-level detail (iterating moves, filtering by label, issuing individual queries). The due-count computation loop is a natural candidate for extraction into a named helper method (e.g., `_loadDueCounts(List<RepertoireMove> moves, ReviewRepository repo)`).

**Why it matters:** Readability. A reader should be able to understand `_loadData` as a sequence of high-level steps without parsing a nested loop. This also makes it easier to swap in the single-query optimization noted in the implementation notes.

### 4. Minor -- Concrete repository types in screen widgets (Dependency Inversion)

**Files:** `src/lib/screens/repertoire_browser_screen.dart` (lines 75-76), `src/lib/screens/home_screen.dart` (lines 35-36)

```dart
final repRepo = LocalRepertoireRepository(widget.db);
final reviewRepo = LocalReviewRepository(widget.db);
```

Both screens construct `Local*Repository` concretions directly. The abstract interfaces `RepertoireRepository` and `ReviewRepository` exist but are not used. This was flagged in the plan review (issue #4) and acknowledged as acceptable tech debt pending Riverpod adoption.

**Why it matters now:** The screen tests use a real in-memory database rather than mocks, which is pragmatic but means the screen is untestable with alternative repository implementations. This is acceptable for v1 but should not propagate further.

### 5. Minor -- `buildVisibleNodes` recomputes on every `build()` call (Performance, Side Effects)

**File:** `src/lib/widgets/move_tree_widget.dart`, lines 102-103

```dart
Widget build(BuildContext context) {
  final visibleNodes = buildVisibleNodes(treeCache, expandedNodeIds);
```

Every call to `build()` recomputes the full visible-node list by walking the tree. For typical repertoire sizes (tens to low hundreds of nodes), this is negligible. However, `MoveTreeWidget` is a `StatelessWidget` that receives its inputs from the parent -- Flutter may rebuild it on any parent `setState`, even for unrelated state changes (e.g., flipping the board orientation triggers a full column rebuild, which rebuilds the tree widget and recomputes visible nodes even though the tree did not change).

**Why it matters:** Not a performance concern at current scale, but worth noting. If tree sizes grow or rebuild frequency increases, memoizing the visible-node list (e.g., caching it in the parent state keyed on `expandedNodeIds` identity) would be a straightforward optimization.

### 6. Minor -- `_MoveTreeNodeTile` uses `GestureDetector` inside `InkWell` for chevron (Hidden Coupling)

**File:** `src/lib/widgets/move_tree_widget.dart`, lines 167-193

```dart
child: InkWell(
  onTap: onTap,
  child: Padding(
    ...
    child: Row(
      children: [
        if (node.hasChildren)
          GestureDetector(
            onTap: onToggleExpand,
            behavior: HitTestBehavior.opaque,
```

A `GestureDetector` is nested inside an `InkWell`. Both respond to taps. The `GestureDetector` uses `HitTestBehavior.opaque` which should correctly absorb the tap and prevent it from reaching the `InkWell`, so this works. However, tapping the chevron will not show the `InkWell`'s ink splash effect, which is a minor UX inconsistency. Consider using an `IconButton` for the chevron instead, which provides its own splash feedback and handles hit testing cleanly.

### 7. Minor -- Duplicated `buildLine` test helper (DRY)

**Files:** `src/test/models/repertoire_tree_cache_test.dart` (lines 16-50), `src/test/widgets/move_tree_widget_test.dart` (lines 16-50)

The `buildLine` helper function is duplicated verbatim across two test files. The `move_tree_widget_test.dart` file also adds a `buildBranch` helper.

**Why it matters:** If the `RepertoireMove` constructor signature changes (e.g., adding a required field), both copies must be updated. Extract into a shared test utility file (e.g., `src/test/helpers/repertoire_test_helpers.dart`).

### 8. Minor -- `plyCount` semantics are subtly correct but undocumented (Naming / Embedded Design)

**File:** `src/lib/widgets/move_tree_widget.dart`, lines 17-19, 48

```dart
/// 1-based ply count (depth from the line root, not the tree nesting depth).
/// Equals `depth + 1` since root moves are at depth 0 and are ply 1.
final int plyCount;
```

And:

```dart
final plyCount = depth + 1;
```

The comment says "depth from the line root, not the tree nesting depth" but then equates it to `depth + 1` where `depth` *is* the tree nesting depth. This works because in this tree structure, tree nesting depth always equals ply depth (every parent-child edge is one ply). But the comment is misleading -- it suggests the two could differ, then computes from the one it says not to use.

**Suggested fix:** Simplify the doc comment: "1-based ply count, equal to tree depth + 1. Root moves are depth 0, ply 1."

### 9. Minor -- `_computeInitialExpandState` walks breadth-first per doc but depth-first per code (Naming)

**File:** `src/lib/screens/repertoire_browser_screen.dart`, lines 116-135

```dart
/// Expand nodes breadth-first until a labeled node is found on each branch.
Set<int> _computeInitialExpandState(RepertoireTreeCache cache) {
  ...
  void walk(List<RepertoireMove> nodes) {
    for (final node in nodes) {
      if (node.label != null) continue;
      final children = cache.getChildren(node.id);
      if (children.isNotEmpty) {
        expanded.add(node.id);
        walk(children);  // <-- recursive depth-first, not breadth-first
      }
    }
  }
```

The doc comment says "breadth-first" but the implementation is depth-first (recursive descent). For the purpose of this algorithm (expand all unlabeled nodes, stop at labeled ones), the traversal order does not affect the result -- the same set of nodes gets expanded either way. But the comment is inaccurate.

**Suggested fix:** Change the comment to "Expand nodes until a labeled node is found on each branch" (removing the traversal order claim), or simply "Expand all unlabeled interior nodes, stopping expansion at labeled nodes."

### 10. Minor -- Screen test `seedRepertoire` helper has branch-sharing logic that could mask bugs (Test Design)

**File:** `src/test/screens/repertoire_browser_screen_test.dart`, lines 25-81

The `seedRepertoire` helper automatically deduplicates shared prefixes between lines by matching on `"parentId:san"`. This is clever and convenient, but it means the tests rely on an implicit convention: the key format `"${parentMoveId ?? "root"}:$san"` must uniquely identify a move in the tree. If two different branches have the same SAN from the same parent (which cannot happen in chess, but could happen in a test setup error), the helper would silently merge them.

This is a minor observation, not an actionable issue. The helper is well-designed for its purpose.
