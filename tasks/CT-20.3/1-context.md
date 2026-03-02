# CT-20.3 Context

## Relevant Files

| File | Role |
|------|------|
| `src/test/repositories/local_review_repository_test.dart` | Target test file. Currently has only `getCardCountForRepertoire` tests and a `seedLineWithCard` helper. Expand with comprehensive coverage. |
| `src/lib/repositories/local/local_review_repository.dart` | Production class under test. Contains `getDueCards`, `getDueCardsForRepertoire`, `getCardsForSubtree`, `getCardForLeaf`, `saveReview`, `deleteCard`, `getAllCardsForRepertoire`, `getCardCountForRepertoire`. |
| `src/lib/repositories/review_repository.dart` | Abstract `ReviewRepository` interface defining the contract. |
| `src/lib/repositories/local/database.dart` | Drift database definition. Defines `ReviewCards`, `RepertoireMoves`, `Repertoires` tables with schema, foreign keys, indexes. Tests use `AppDatabase(NativeDatabase.memory())`. |
| `src/lib/repositories/local/database.g.dart` | Generated Drift code. Defines `ReviewCardsCompanion.insert` (required: `repertoireId`, `leafMoveId`, `nextReviewDate`; defaults: `easeFactor` 2.5, `intervalDays` 1, `repetitions` 0). |
| `src/test/repositories/local_repertoire_repository_test.dart` | Sibling test file. Provides established patterns: `createTestDatabase()`, `seedLineWithCard`, `seedSingleMove` helpers, `setUp`/`tearDown` lifecycle, group-based organization. |
| `architecture/testing-strategy.md` | Testing spec. Prescribes repository tests against real in-memory SQLite, deterministic data, behavior-focused naming. |
| `architecture/repository.md` | Repository architecture spec. Documents interface contracts, table schemas, indexes (`idx_cards_due`, `idx_cards_leaf` UNIQUE), foreign key cascades. |

## Architecture

The repository layer abstracts data access behind the `ReviewRepository` interface. `LocalReviewRepository` uses SQLite via Drift, wrapping an `AppDatabase`.

- **Drift queries** (`getDueCards`, `getDueCardsForRepertoire`, `getCardForLeaf`, etc.) use the type-safe query builder with automatic DateTime-to-epoch serialization.
- **Raw SQL** (`getCardsForSubtree`, `getCardCountForRepertoire`) use `_db.customSelect` for recursive CTEs. `getCardsForSubtree` walks the `repertoire_moves` adjacency-list tree downward, joins to `review_cards`, and optionally filters by `next_review_date <= cutoff` using `Variable<DateTime>` (fixed in CT-20.1).
- Drift stores `DateTime` as Unix epoch seconds (integer). The CT-20.1 fix replaced string interpolation with `Variable<DateTime>` for correct comparisons.
- `review_cards.leaf_move_id` has a UNIQUE index — each leaf move has at most one card.
- Foreign key cascades (`ON DELETE CASCADE`) propagate move deletions to cards.
- Tests use `NativeDatabase.memory()` for isolated in-memory databases.
