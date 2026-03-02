# CT-20.5 Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/repositories/review_repository.dart` | Added `getRepertoireSummaries` and `getDueCountForSubtrees` abstract methods to the interface. |
| `src/lib/repositories/local/local_review_repository.dart` | Implemented both new methods: `getRepertoireSummaries` uses GROUP BY with conditional COUNT; `getDueCountForSubtrees` uses a recursive CTE seeded with multiple roots. |
| `src/lib/controllers/home_controller.dart` | Replaced per-repertoire N+1 loop in `_load()` with a single `getRepertoireSummaries()` call. Query count reduced from 2N+1 to 2. |
| `src/lib/controllers/repertoire_browser_controller.dart` | Replaced per-labeled-node N+1 loop in `loadData()` with a single `getDueCountForSubtrees()` call. Query count reduced from L+2 to 3. |
| `src/test/screens/home_screen_test.dart` | Added working `getRepertoireSummaries` override to FakeReviewRepository (derives from existing `dueCards`/`allCards` fields) and stub for `getDueCountForSubtrees`. |
| `src/test/screens/drill_screen_test.dart` | Added empty-map stubs for both new methods to FakeReviewRepository. |
| `src/test/screens/drill_filter_test.dart` | Added empty-map stubs for both new methods to FakeReviewRepository. |
| `src/test/repositories/local_review_repository_test.dart` | Added test groups for `getRepertoireSummaries` (5 tests) and `getDueCountForSubtrees` (6 tests). |

## Deviations from Plan

- Added chunking (batches of 900) to `getDueCountForSubtrees` to stay within SQLite's 999 bind-variable limit. Plan Risk #3 noted this possibility; design review flagged it as Major.

## Performance Improvement

- **Home screen:** from 2N+1 queries to 2 queries (where N = number of repertoires).
- **Repertoire browser:** from L+2 queries to 3 queries (where L = number of labeled moves).

## Follow-up Work

- None identified. The existing `getDueCardsForRepertoire`, `getCardCountForRepertoire`, and `getCardsForSubtree` methods remain intact as they are still used by `DrillController` and other callers.
