# CT-12.1: Always seed review cards in debug mode -- Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/services/dev_seed.dart` | The dev seed function (`seedDevData`). Currently creates sample repertoire data and review cards only when the database is empty (no existing repertoires). This is the primary file to modify. |
| `src/lib/main.dart` | App entry point. Calls `seedDevData(repertoireRepo, reviewRepo)` inside a `kDebugMode` guard on every debug startup. Passes both repository instances. |
| `src/lib/repositories/review_repository.dart` | Abstract `ReviewRepository` interface. Defines `getDueCards`, `getAllCardsForRepertoire`, `saveReview`, and other card access methods. The seed function depends on this interface. |
| `src/lib/repositories/local/local_review_repository.dart` | Concrete `LocalReviewRepository`. Implements `saveReview` which handles both insert (no `id` present) and update (with `id` present) via a `ReviewCardsCompanion`. |
| `src/lib/repositories/local/database.dart` | Drift database schema. Defines `ReviewCards` table with `nextReviewDate` column (type `DateTimeColumn`). Also defines `Repertoires` and `RepertoireMoves`. |
| `src/lib/repositories/local/database.g.dart` | Generated Drift code. Contains `ReviewCard` data class, `ReviewCardsCompanion` (with `copyWith` supporting `nextReviewDate`), and `ReviewCardsCompanion.insert`. |
| `src/lib/repositories/repertoire_repository.dart` | Abstract `RepertoireRepository` interface. Defines `getAllRepertoires` (used by the seed to check for existing data). |
| `src/lib/repositories/local/local_repertoire_repository.dart` | Concrete repertoire repository. Standard Drift CRUD implementation. |
| `architecture/testing-strategy.md` | Testing strategy spec. Referenced by the task as relevant context; confirms test conventions and the "boilerplate (main.dart)" exclusion from testing. |

## Architecture

The dev seed subsystem is a simple startup hook:

1. **`main()`** in `main.dart` initializes the database and repository instances, then conditionally calls `seedDevData()` when `kDebugMode` is `true` (Flutter's compile-time debug flag).

2. **`seedDevData()`** in `dev_seed.dart` is an async function that accepts both repository interfaces (`RepertoireRepository` and `ReviewRepository`). It currently uses a **one-shot guard**: if `getAllRepertoires()` returns any repertoires, it returns immediately without doing anything. Otherwise, it creates a "Dev Openings" repertoire with 4 leaf lines and 4 corresponding review cards, all with `nextReviewDate = DateTime.now()` (i.e., due today).

3. **Review cards** are stored in the `review_cards` table. A card is "due" when `next_review_date <= now`. The `getDueCards()` query in `LocalReviewRepository` uses `isSmallerOrEqualValue(cutoff)` to filter. After a drill session, SM-2 updates the `nextReviewDate` to a future date, which means seed cards that have been reviewed once will no longer be due.

4. **The problem**: After the first debug launch, seed data exists so the guard (`if (existing.isNotEmpty) return`) exits early on subsequent launches. Even if we removed that guard, re-inserting the same seed data would violate the unique constraint on `leaf_move_id` in the `review_cards` table. Meanwhile, any previously reviewed cards now have future `nextReviewDate` values, so drill mode shows "No cards due for review."

5. **The `saveReview` method** on `ReviewRepository` supports both insert and update: when a `ReviewCardsCompanion` has `id.present`, it performs an UPDATE; otherwise it performs an INSERT. This is the mechanism available for updating existing card dates.

Key constraints:
- The seed must remain a no-op in release builds (the `kDebugMode` guard in `main.dart` handles this).
- The function operates through the abstract repository interfaces, not direct database access.
- The `ReviewCardsCompanion.copyWith` supports partial updates including `nextReviewDate`.
- There is a unique index on `leaf_move_id` preventing duplicate review cards for the same leaf.
