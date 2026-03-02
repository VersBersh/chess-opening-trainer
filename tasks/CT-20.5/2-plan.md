# CT-20.5 Implementation Plan

## Goal

Replace the N+1 sequential query loops in `HomeController` and `RepertoireBrowserController` with single aggregated SQL queries in the repository layer, keeping UI behavior and state shapes identical.

## Steps

### Step 1: Add `getRepertoireSummaries` to `ReviewRepository` interface

**File:** `src/lib/repositories/review_repository.dart`

Add a new abstract method that returns due count and total count per repertoire in a single call:

```dart
/// Returns (repertoireId -> (dueCount, totalCount)) for all repertoires
/// that have at least one review card, computed in a single query.
Future<Map<int, ({int dueCount, int totalCount})>> getRepertoireSummaries({DateTime? asOf});
```

This replaces the per-repertoire calls to `getDueCardsForRepertoire` (used only for `.length`) and `getCardCountForRepertoire`.

**Dependencies:** None.

---

### Step 2: Add `getDueCountForSubtrees` to `ReviewRepository` interface

**File:** `src/lib/repositories/review_repository.dart`

Add a new abstract method that computes due counts for multiple subtree roots in a single query:

```dart
/// Returns (moveId -> dueCount) for each move ID in [moveIds] that has at
/// least one due card in its subtree. Move IDs with zero due cards are
/// omitted from the result.
Future<Map<int, int>> getDueCountForSubtrees(List<int> moveIds, {DateTime? asOf});
```

This replaces the per-labeled-node calls to `getCardsForSubtree(moveId, dueOnly: true)`.

**Dependencies:** None.

---

### Step 3: Stub new methods in all test fake `ReviewRepository` implementations

**Files:**
- `src/test/screens/home_screen_test.dart` (FakeReviewRepository at line 122)
- `src/test/screens/drill_screen_test.dart` (FakeReviewRepository at line 165)
- `src/test/screens/drill_filter_test.dart` (FakeReviewRepository at line 171)

Adding abstract methods in Steps 1-2 will break compilation for all classes that `implements ReviewRepository`. Three test fakes must be updated with stub overrides so the project compiles throughout development.

For each fake, add:

```dart
@override
Future<Map<int, ({int dueCount, int totalCount})>> getRepertoireSummaries({DateTime? asOf}) async => {};

@override
Future<Map<int, int>> getDueCountForSubtrees(List<int> moveIds, {DateTime? asOf}) async => {};
```

The `home_screen_test.dart` fake needs a working implementation of `getRepertoireSummaries` because the `HomeController` under test will call it after Step 6. Derive the result from the fake's existing `dueCards` and `allCards` fields:

```dart
@override
Future<Map<int, ({int dueCount, int totalCount})>> getRepertoireSummaries({DateTime? asOf}) async {
  final map = <int, ({int dueCount, int totalCount})>{};
  for (final card in allCards) {
    final rid = card.repertoireId;
    final prev = map[rid] ?? (dueCount: 0, totalCount: 0);
    final isDue = dueCards.contains(card);
    map[rid] = (
      dueCount: prev.dueCount + (isDue ? 1 : 0),
      totalCount: prev.totalCount + 1,
    );
  }
  return map;
}
```

The `drill_screen_test.dart` and `drill_filter_test.dart` fakes do not exercise paths that call the new methods, so returning empty maps is sufficient.

**Dependencies:** Steps 1, 2.

---

### Step 4: Implement `getRepertoireSummaries` in `LocalReviewRepository`

**File:** `src/lib/repositories/local/local_review_repository.dart`

Implement the method using a single `GROUP BY` query with conditional aggregation:

```sql
SELECT
  repertoire_id,
  COUNT(*) AS total_count,
  COUNT(CASE WHEN next_review_date <= ? THEN 1 END) AS due_count
FROM review_cards
GROUP BY repertoire_id
```

This produces one row per repertoire with both counts, using a single table scan against `idx_cards_repertoire`. The `?` parameter is the `asOf` cutoff (defaulting to `DateTime.now()`).

Parse the results into the `Map<int, ({int dueCount, int totalCount})>` return type.

**Dependencies:** Step 1.

---

### Step 5: Implement `getDueCountForSubtrees` in `LocalReviewRepository`

**File:** `src/lib/repositories/local/local_review_repository.dart`

This is the most complex query. The approach: for each root move ID, walk the subtree using a recursive CTE, then join to `review_cards` and group by the root move ID.

Strategy: use a single recursive CTE that tracks which root each descendant belongs to:

```sql
WITH RECURSIVE subtrees(root_id, node_id) AS (
  -- Seed: each requested move ID is its own root
  SELECT id, id FROM repertoire_moves WHERE id IN (?, ?, ...)
  UNION ALL
  -- Recurse: children inherit the root_id
  SELECT s.root_id, m.id
  FROM repertoire_moves m
  JOIN subtrees s ON m.parent_move_id = s.node_id
)
SELECT s.root_id, COUNT(*) AS due_count
FROM subtrees s
JOIN review_cards rc ON rc.leaf_move_id = s.node_id
WHERE rc.next_review_date <= ?
GROUP BY s.root_id
```

Implementation notes:
- The `IN (?, ?, ...)` clause must be built dynamically since Drift does not support list-valued bind parameters. Build the SQL string with the correct number of `?` placeholders and pass `moveIds` as `Variable.withInt` values, followed by the `cutoff` datetime variable.
- If `moveIds` is empty, return an empty map immediately (no query needed).
- Parse results into `Map<int, int>`.
- Consider a batch-size limit (e.g., 500) and chunking if the list could be very large. In practice, labeled node counts are small (tens, not thousands), so a single query is fine.

**Dependencies:** Step 2.

---

### Step 6: Update `HomeController._load()` to use batch method

**File:** `src/lib/controllers/home_controller.dart`

Replace the `for` loop (lines 53-64) with:

```dart
final repertoires = await repertoireRepo.getAllRepertoires();
final summaryMap = await reviewRepo.getRepertoireSummaries();

final summaries = <RepertoireSummary>[];
var totalDue = 0;

for (final repertoire in repertoires) {
  final counts = summaryMap[repertoire.id];
  final dueCount = counts?.dueCount ?? 0;
  final totalCardCount = counts?.totalCount ?? 0;
  summaries.add(RepertoireSummary(
    repertoire: repertoire,
    dueCount: dueCount,
    totalCardCount: totalCardCount,
  ));
  totalDue += dueCount;
}

return HomeState(repertoires: summaries, totalDueCount: totalDue);
```

This reduces the query count from 2N+1 to 2 (one for repertoires, one for all counts).

**Dependencies:** Steps 3, 4.

---

### Step 7: Update `RepertoireBrowserController.loadData()` to use batch method

**File:** `src/lib/controllers/repertoire_browser_controller.dart`

Replace the labeled-node loop (lines 132-143) with:

```dart
// 4. Load due-card counts for labeled nodes in a single query.
final labeledMoveIds = allMoves
    .where((m) => m.label != null)
    .map((m) => m.id)
    .toList();

final dueCountMap = labeledMoveIds.isEmpty
    ? <int, int>{}
    : await _reviewRepo.getDueCountForSubtrees(labeledMoveIds);
```

This reduces the query count from L+2 to 3 (repertoire, all moves, batch subtree counts).

**Dependencies:** Steps 3, 5.

---

### Step 8: Add tests for `getRepertoireSummaries`

**File:** `src/test/repositories/local_review_repository_test.dart`

Add a new `group('getRepertoireSummaries', ...)` with tests:

1. **Returns empty map when no cards exist.** Create repertoires with no cards; verify the map is empty.
2. **Returns correct due and total counts per repertoire.** Use `seedBranchingTree` (which creates 3 cards with various due dates) and verify the due/total split at a specific `asOf` date.
3. **Handles multiple repertoires.** Seed two repertoires with different card counts. Verify both appear in the result with correct counts.
4. **Includes cards due exactly on asOf boundary.** Verify boundary condition with `asOf` equal to a card's `nextReviewDate`.
5. **Repertoires with zero cards are absent from map.** Create an empty repertoire alongside a seeded one. Verify the empty one is not in the map.

**Dependencies:** Step 4.

---

### Step 9: Add tests for `getDueCountForSubtrees`

**File:** `src/test/repositories/local_review_repository_test.dart`

Add a new `group('getDueCountForSubtrees', ...)` with tests:

1. **Returns empty map for empty moveIds list.** Pass empty list, verify empty map returned.
2. **Returns correct due counts for a branching tree.** Use `seedBranchingTree`, pass the root `e4Id` and branch `e5Id`. Verify counts match the expected due cards in each subtree at the given `asOf`.
3. **Omits entries with zero due count.** Pass a move whose subtree has only future-due cards. Verify it is absent from the result map.
4. **Handles leaf nodes.** Pass a leaf move ID with a due card. Verify count is 1.
5. **Handles overlapping subtrees.** Pass both a parent and its child as roots. Verify each gets its own correct count (a card in the child's subtree is counted for both).
6. **Returns empty map when all cards are future-due.** Use an `asOf` date before any card is due.

**Dependencies:** Step 5.

---

### Step 10: Verify existing tests still pass

Run `flutter test` from `src/` to confirm:
- All existing `LocalReviewRepository` tests pass (the new methods are additive).
- All existing `RepertoireBrowserController` tests pass (the controller still produces the same state shape).
- Home screen tests pass (the controller produces the same `HomeState`).

**Dependencies:** Steps 6, 7, 8, 9.

---

### Step 11: Document performance improvement in impl notes

After implementation, note the query reduction:
- **Home screen:** from 2N+1 queries to 2 queries (where N = number of repertoires).
- **Repertoire browser:** from L+2 queries to 3 queries (where L = number of labeled moves).

For a repertoire with 10 labeled nodes, the browser goes from 12 queries to 3. For a home screen with 5 repertoires, it goes from 11 queries to 2.

**Dependencies:** Step 10.

## Risks / Open Questions

1. **Recursive CTE with multiple roots performance.** The `getDueCountForSubtrees` query seeds the CTE with multiple root IDs and tracks ancestry via `root_id`. For very large trees with many labeled nodes, the CTE could produce a large intermediate table. In practice, chess repertoire trees are moderate in size (hundreds to low thousands of moves), so this should be fine. If performance is a concern, the alternative is to run a single CTE from the repertoire root and aggregate at the application layer using the in-memory `RepertoireTreeCache` -- but this would mix repository and model concerns.

2. **Overlapping subtrees in batch query.** If labeled node A is an ancestor of labeled node B, the batch CTE will walk B's subtree twice (once for A's traversal, once for B's). This produces correct counts but does redundant work. The extra cost is negligible for typical tree sizes. An optimization (walking the tree once from the root and accumulating counts bottom-up in application code) would be more efficient but more complex.

3. **Dynamic SQL for IN clause.** Building the `IN (?, ?, ...)` clause dynamically is straightforward but must handle the edge case of an empty list (return early) and very large lists (SQLite has a default limit of 999 variables per statement). Labeled node counts in practice will be well under this limit, but a chunking safeguard could be added.

4. **`getDueCardsForRepertoire` not removed.** The existing `getDueCardsForRepertoire` method is still used by `DrillController` (to load actual card objects for drilling) and `DevSeed`. It should not be removed. The new `getRepertoireSummaries` is a separate, count-only API.

5. **`getCardsForSubtree` not removed.** The existing `getCardsForSubtree` is still used by `RepertoireBrowserController.getBranchDeleteInfo()` and `DrillController`. It should not be removed. The new `getDueCountForSubtrees` is a separate, count-only batch API.

6. **No UI changes expected.** Both `HomeState` and `RepertoireBrowserState` keep their current shapes. The widgets consume the same data types. The only changes are in the repository interface, its implementation, and the two controllers' load methods.

7. **`home_screen_test.dart` fake needs working `getRepertoireSummaries`.** After Step 6 rewires `HomeController._load()` to call `getRepertoireSummaries` instead of the per-repertoire methods, the home screen test fake must return realistic data (not an empty map) or the existing home screen tests will fail. Step 3 accounts for this with a derived implementation based on the fake's existing `dueCards` and `allCards` fields.
