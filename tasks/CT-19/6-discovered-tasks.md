# 6-discovered-tasks.md

## Discovered Tasks

### CT-20: Due Card Count Query Optimization
**Title:** Add `getDueCountForRepertoire` using `SELECT COUNT(*)` with date filter
**Description:** The home screen still calls `getDueCardsForRepertoire(...).length` to get the due count, loading all due card objects into memory just to count them. Add a dedicated `getDueCountForRepertoire(int repertoireId, {DateTime? asOf})` method backed by `SELECT COUNT(*) FROM review_cards WHERE repertoire_id = ? AND next_review_date <= ?`.
**Why discovered:** While implementing CT-19, the same pattern (loading objects just to count) was observed for due cards in `HomeController._load()`. This is the natural follow-up optimization mentioned in Key Decision 4 of the home screen spec.

### CT-21: Extract Shared Test Helpers for Repository Tests
**Title:** Extract `createTestDatabase` and `seedLineWithCard` into shared test helper module
**Description:** The `createTestDatabase()` and `seedLineWithCard()` helpers are now duplicated between `local_repertoire_repository_test.dart` and `local_review_repository_test.dart`. Extract them into a shared `test/repositories/test_helpers.dart` file.
**Why discovered:** The new `local_review_repository_test.dart` file needed to duplicate these helpers from the existing test file.
