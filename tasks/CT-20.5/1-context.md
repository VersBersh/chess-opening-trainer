# CT-20.5 Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/controllers/home_controller.dart` | Contains the N+1 loop: iterates all repertoires calling `getDueCardsForRepertoire` and `getCardCountForRepertoire` per repertoire to build `RepertoireSummary` list. |
| `src/lib/controllers/repertoire_browser_controller.dart` | Contains the N+1 loop: iterates all labeled moves calling `getCardsForSubtree(move.id, dueOnly: true)` per labeled move to build `dueCountByMoveId` map. |
| `src/lib/repositories/review_repository.dart` | Abstract interface for review card queries. Needs new batch/aggregated methods. |
| `src/lib/repositories/local/local_review_repository.dart` | SQLite/Drift implementation of `ReviewRepository`. Needs new aggregated SQL queries. |
| `src/lib/repositories/repertoire_repository.dart` | Abstract interface for repertoire/move queries. May need a helper if labeled-move identification is pushed to SQL. |
| `src/lib/repositories/local/local_repertoire_repository.dart` | SQLite/Drift implementation of `RepertoireRepository`. |
| `src/lib/repositories/local/database.dart` | Drift database definition: table schemas for `Repertoires`, `RepertoireMoves`, `ReviewCards`, and all indexes. |
| `src/lib/screens/home_screen.dart` | UI consumer of `HomeController` state. No changes expected -- it reads `HomeState` which keeps the same shape. |
| `src/lib/screens/repertoire_browser_screen.dart` | UI consumer of `RepertoireBrowserController`. No changes expected -- it reads `RepertoireBrowserState` which keeps the same shape. |
| `src/lib/widgets/repertoire_card.dart` | Renders per-repertoire card on home screen using `RepertoireSummary.dueCount` and `.totalCardCount`. |
| `src/lib/widgets/move_tree_widget.dart` | Renders move tree in browser; consumes `dueCountByMoveId` map for badge display. |
| `src/lib/widgets/browser_content.dart` | Passes `state.dueCountByMoveId` to `MoveTreeWidget`. |
| `src/lib/models/repertoire.dart` | `RepertoireTreeCache` -- eagerly loaded in-memory tree. Already loaded in one query; used to identify labeled moves in the browser controller. |
| `src/lib/providers.dart` | Riverpod providers for `RepertoireRepository` and `ReviewRepository`. |
| `src/test/repositories/local_review_repository_test.dart` | Existing test file for `LocalReviewRepository`. New batch methods must be tested here. |
| `src/test/controllers/repertoire_browser_controller_test.dart` | Existing tests for `RepertoireBrowserController`. Verifies `loadData` populates `dueCountByMoveId`. |

## Architecture

### Subsystem overview

The home screen and repertoire browser are the two primary data-loading screens:

1. **Home screen** displays a list of repertoires, each with a due-card count and total-card count. The `HomeController` (Riverpod `AsyncNotifier`) loads all repertoires, then for each repertoire calls two separate repository queries (`getDueCardsForRepertoire` and `getCardCountForRepertoire`). This produces 2N+1 queries for N repertoires.

2. **Repertoire browser** displays a move tree with due-count badges on labeled nodes. The `RepertoireBrowserController` (`ChangeNotifier`) loads all moves in one query, builds a `RepertoireTreeCache`, then for every move that has a non-null `label`, calls `getCardsForSubtree(move.id, dueOnly: true)` -- a recursive CTE query. For a repertoire with L labeled moves, this is L+2 queries, and each CTE walks the subtree.

### Data flow

```
ReviewRepository (abstract)
    |
    v
LocalReviewRepository (SQLite/Drift)
    |
    v
Controller (_load / loadData)
    |   - iterates items, issues per-item queries (N+1 pattern)
    |   - builds state objects (HomeState / RepertoireBrowserState)
    v
Widget (HomeScreen / BrowserContent)
    - reads state, renders UI
```

### Key constraints

- **Abstract repository interface**: New methods must be added to `ReviewRepository` (abstract), then implemented in `LocalReviewRepository`. This keeps the storage backend swappable.
- **State shapes unchanged**: `HomeState` (with `List<RepertoireSummary>`) and `RepertoireBrowserState` (with `Map<int, int> dueCountByMoveId`) must keep the same structure so no UI widget changes are needed.
- **SQL indexes already exist**: `idx_cards_repertoire ON review_cards(repertoire_id)` and `idx_cards_due ON review_cards(next_review_date)` support efficient group-by queries. `idx_moves_parent ON repertoire_moves(parent_move_id)` supports the recursive CTE.
- **Drift custom queries**: Complex aggregation must use `_db.customSelect()` since Drift's type-safe query builder does not support GROUP BY with multiple aggregates or recursive CTEs natively.
- **Browser due counts are only for labeled nodes**: The `dueCountByMoveId` map only needs entries for moves with non-null labels. The current loop filters on `move.label != null` before querying. The batch replacement must produce the same filtering.

### The two N+1 patterns in detail

**Pattern 1: HomeController._load() (lines 53-64)**
```dart
for (final repertoire in repertoires) {
  final dueCards = await reviewRepo.getDueCardsForRepertoire(repertoire.id);
  final totalCardCount = await reviewRepo.getCardCountForRepertoire(repertoire.id);
  summaries.add(RepertoireSummary(
    repertoire: repertoire,
    dueCount: dueCards.length,
    totalCardCount: totalCardCount,
  ));
  totalDue += dueCards.length;
}
```
Note: `getDueCardsForRepertoire` returns full `ReviewCard` objects just to compute `.length`. This is wasteful -- only a COUNT is needed.

**Pattern 2: RepertoireBrowserController.loadData() (lines 132-143)**
```dart
final dueCountMap = <int, int>{};
for (final move in allMoves) {
  if (move.label != null) {
    final cards = await _reviewRepo.getCardsForSubtree(
      move.id,
      dueOnly: true,
    );
    if (cards.isNotEmpty) {
      dueCountMap[move.id] = cards.length;
    }
  }
}
```
Each `getCardsForSubtree` runs a recursive CTE to walk the move tree downward from the labeled node, joins to `review_cards`, and returns full card objects -- again only to count them.
