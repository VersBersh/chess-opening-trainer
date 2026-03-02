# 2-plan.md

## Goal

Add a dedicated `getCardCountForRepertoire(int repertoireId)` method to `ReviewRepository` backed by `SELECT COUNT(*)` in SQLite, and use it on the home screen instead of loading all card objects just to count them.

## Steps

**Step 1: Add method to abstract interface**
File: `src/lib/repositories/review_repository.dart`

Add a new method to the `ReviewRepository` abstract class:
```dart
Future<int> getCardCountForRepertoire(int repertoireId);
```
Place it after `getAllCardsForRepertoire` to group related methods together.

**Step 2: Implement in LocalReviewRepository**
File: `src/lib/repositories/local/local_review_repository.dart`

Add the implementation after the `getAllCardsForRepertoire` method. Follow the `countLeavesInSubtree` pattern from `local_repertoire_repository.dart`:
```dart
@override
Future<int> getCardCountForRepertoire(int repertoireId) async {
  final result = await _db.customSelect(
    'SELECT COUNT(*) AS cnt FROM review_cards WHERE repertoire_id = ?',
    variables: [Variable.withInt(repertoireId)],
    readsFrom: {_db.reviewCards},
  ).getSingle();
  return result.read<int>('cnt');
}
```

This uses the existing `idx_cards_repertoire` index. The `readsFrom` parameter ensures Drift's reactivity system tracks dependencies correctly.

**Step 3: Update HomeController to use count query**
File: `src/lib/screens/home_screen.dart`

In `_load()`, replace:
```dart
final allCards =
    await reviewRepo.getAllCardsForRepertoire(repertoire.id);
```
with:
```dart
final totalCardCount =
    await reviewRepo.getCardCountForRepertoire(repertoire.id);
```

And update the `RepertoireSummary` construction to use `totalCardCount` directly instead of `allCards.length`.

**Step 4: Update FakeReviewRepository in home_screen_test.dart**
File: `src/test/screens/home_screen_test.dart`

Add the override to the `FakeReviewRepository` class:
```dart
@override
Future<int> getCardCountForRepertoire(int repertoireId) async =>
    allCards.where((c) => c.repertoireId == repertoireId).length;
```

**Step 5: Update FakeReviewRepository in drill_screen_test.dart**
File: `src/test/screens/drill_screen_test.dart`

Add the override to the `FakeReviewRepository` class:
```dart
@override
Future<int> getCardCountForRepertoire(int repertoireId) async =>
    _allCards.where((c) => c.repertoireId == repertoireId).length;
```

**Step 6: Update FakeReviewRepository in drill_filter_test.dart**
File: `src/test/screens/drill_filter_test.dart`

Add the override to the `FakeReviewRepository` class:
```dart
@override
Future<int> getCardCountForRepertoire(int repertoireId) async =>
    _allCards.where((c) => c.repertoireId == repertoireId).length;
```

**Step 7: Add repository integration tests**
File: `src/test/repositories/local_review_repository_test.dart` (new file)

Follow the pattern from `local_repertoire_repository_test.dart` (in-memory `AppDatabase`, `setUp`/`tearDown`, reuse/duplicate the `seedLineWithCard` helper).

Tests to write:
1. Returns 0 for empty repertoire
2. Returns correct count after seeding cards
3. Counts only cards for the specified repertoire

**Step 8: Update architecture spec**
File: `architecture/repository.md`

Add the new method to the `ReviewRepository` interface definition after `getAllCardsForRepertoire`.

## Risks / Open Questions

1. **Due count optimization scope.** The task only asks for total card count. Key Decision 4 also mentions `getDueCountForRepertoire` as a potential optimization. The home screen also calls `getDueCardsForRepertoire(...).length` for due count. This is a separate optimization and out of scope for CT-19.

2. **Test helper reuse.** The `seedLineWithCard` helper is defined in `local_repertoire_repository_test.dart`. It will need to be either duplicated in the new test file or extracted to a shared location. Duplicating a small helper is acceptable for now.

3. **No breaking changes in production callers.** The three remaining `getAllCardsForRepertoire` call sites (`drill_screen.dart` x2, `dev_seed.dart` x1) use the full card list, not just the count. They do not need to change.
