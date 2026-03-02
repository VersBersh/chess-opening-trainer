# 1-context.md

## Relevant Files

- **`src/lib/repositories/review_repository.dart`** — Abstract `ReviewRepository` interface. The new `getCardCountForRepertoire` method must be added here.
- **`src/lib/repositories/local/local_review_repository.dart`** — SQLite/Drift implementation of `ReviewRepository`. Must implement the new method with a `SELECT COUNT(*)` query.
- **`src/lib/screens/home_screen.dart`** — Home screen and `HomeController._load()`. Currently calls `getAllCardsForRepertoire(repertoire.id)` and uses `.length` for `totalCardCount`. Must switch to `getCardCountForRepertoire`.
- **`src/lib/repositories/local/database.dart`** — Drift database definition with `ReviewCards` table and `idx_cards_repertoire` index on `review_cards(repertoire_id)`. The COUNT query will leverage this index. No changes needed.
- **`src/test/screens/home_screen_test.dart`** — Home screen widget tests with `FakeReviewRepository`. Must add the `getCardCountForRepertoire` override.
- **`src/test/screens/drill_screen_test.dart`** — Drill screen widget tests with `FakeReviewRepository`. Must add the `getCardCountForRepertoire` override.
- **`src/test/screens/drill_filter_test.dart`** — Drill filter widget tests with `FakeReviewRepository`. Must add the `getCardCountForRepertoire` override.
- **`src/test/repositories/local_repertoire_repository_test.dart`** — Existing repository integration test file. Pattern reference for writing new repository tests (uses `createTestDatabase()`, `seedLineWithCard()` helpers, in-memory SQLite).
- **`src/lib/repositories/local/local_repertoire_repository.dart`** — Contains `countLeavesInSubtree` implementation, which is the closest existing pattern for a `customSelect` COUNT query returning a single int.
- **`architecture/repository.md`** — Architecture spec defining repository interfaces and database schema.
- **`features/home-screen.md`** — Home screen feature spec. Key Decision 4 discusses due count efficiency and mentions a dedicated count query approach.

## Architecture

The repository layer provides abstract interfaces (`ReviewRepository`, `RepertoireRepository`) that decouple business logic from storage. The sole implementation uses SQLite via Drift (`LocalReviewRepository`, `LocalRepertoireRepository`). The `AppDatabase` class defines tables and indexes declaratively; custom SQL is used for complex queries via `_db.customSelect()`.

The home screen's `HomeController` loads summary data for each repertoire by calling repository methods and computing derived values. Currently it calls `getAllCardsForRepertoire(id)` which loads every `ReviewCard` row into memory as Dart objects, then uses `.length` to get the count. This is wasteful for a count-only use case, since the card data itself is discarded.

The `review_cards` table already has an index on `repertoire_id` (`idx_cards_repertoire`), so a `SELECT COUNT(*) FROM review_cards WHERE repertoire_id = ?` query will be efficient.

Key constraints:
- The abstract interface must stay backend-agnostic (returns `Future<int>`, not tied to SQL).
- Three test files have their own `FakeReviewRepository` implementations that must implement any new interface methods.
- The existing `countLeavesInSubtree` method in `LocalRepertoireRepository` is the established pattern for COUNT queries: `customSelect` with `getSingle()`, reading the count via `result.read<int>('cnt')`.
