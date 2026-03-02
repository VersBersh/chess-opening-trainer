# 4-impl-notes.md

## Files Modified

- **`src/lib/repositories/review_repository.dart`** — Added `Future<int> getCardCountForRepertoire(int repertoireId)` to the abstract interface, after `getAllCardsForRepertoire`.
- **`src/lib/repositories/local/local_review_repository.dart`** — Implemented `getCardCountForRepertoire` using `customSelect` with `SELECT COUNT(*) AS cnt FROM review_cards WHERE repertoire_id = ?`, following the `countLeavesInSubtree` pattern.
- **`src/lib/screens/home_screen.dart`** — Replaced `getAllCardsForRepertoire` + `.length` with `getCardCountForRepertoire` in `HomeController._load()`.
- **`src/test/screens/home_screen_test.dart`** — Added `getCardCountForRepertoire` override to `FakeReviewRepository`.
- **`src/test/screens/drill_screen_test.dart`** — Added `getCardCountForRepertoire` override to `FakeReviewRepository`.
- **`src/test/screens/drill_filter_test.dart`** — Added `getCardCountForRepertoire` override to `FakeReviewRepository`.
- **`architecture/repository.md`** — Added `getCardCountForRepertoire` to the `ReviewRepository` interface definition.

## Files Created

- **`src/test/repositories/local_review_repository_test.dart`** — Integration tests for `getCardCountForRepertoire`: returns 0 for empty repertoire, returns correct count after seeding, counts only cards for the specified repertoire. Follows the pattern from `local_repertoire_repository_test.dart` with duplicated `seedLineWithCard` helper.

## Deviations from Plan

- None. All steps followed as specified.

## Follow-up Work

- **Due count optimization (out of scope for CT-19):** The home screen still calls `getDueCardsForRepertoire(...).length` to get the due count. A `getDueCountForRepertoire` method with `SELECT COUNT(*)` + date filter would be the natural next optimization.
- **Shared test helpers:** The `seedLineWithCard` and `createTestDatabase` helpers are now duplicated between `local_repertoire_repository_test.dart` and `local_review_repository_test.dart`. A shared test helper file could reduce duplication if more repository test files are added.
