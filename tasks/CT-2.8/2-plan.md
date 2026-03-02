# CT-2.8 Implementation Plan (Revised)

## Goal

Wrap persistence operations in the confirm flow with try/catch, show user-facing SnackBar error messages, and ensure UI consistency after errors. Path B (branching) must be made atomic to prevent partial saves.

## Steps

### 1. Add `ConfirmError` result type

**File:** `src/lib/controllers/add_line_controller.dart`

Add to the sealed `ConfirmResult` hierarchy (after `ConfirmNoNewMoves`):

```dart
class ConfirmError extends ConfirmResult {
  final String userMessage;
  final Object error;
  const ConfirmError({required this.userMessage, required this.error});
}
```

### 2. Move `sqlite3` from dev_dependencies to dependencies

**File:** `src/pubspec.yaml`

Move `sqlite3: ^3.1.6` from `dev_dependencies` to `dependencies`. Needed to import `SqliteException` in production code. Already transitively available at runtime via `sqlite3_flutter_libs`.

### 3. Add `saveBranch()` to `RepertoireRepository` and implement in `LocalRepertoireRepository`

**File (interface):** `src/lib/repositories/repertoire_repository.dart`
**File (implementation):** `src/lib/repositories/local/local_repertoire_repository.dart`

Add to `RepertoireRepository`:

```dart
Future<List<int>> saveBranch(
  int? parentMoveId,
  List<RepertoireMovesCompanion> newMoves,
  ReviewCardsCompanion reviewCard,
);
```

Implement in `LocalRepertoireRepository` by wrapping the move loop and card insertion in a Drift `transaction()`, following the same pattern as `extendLine()`:

```dart
@override
Future<List<int>> saveBranch(
  int? parentMoveId,
  List<RepertoireMovesCompanion> newMoves,
  ReviewCardsCompanion reviewCard,
) {
  return _db.transaction(() async {
    int? parentId = parentMoveId;
    final insertedIds = <int>[];
    for (final move in newMoves) {
      final withParent = parentId != null
          ? move.copyWith(parentMoveId: Value(parentId))
          : move;
      parentId = await _db.into(_db.repertoireMoves).insert(withParent);
      insertedIds.add(parentId);
    }
    final cardWithLeaf = reviewCard.copyWith(leafMoveId: Value(parentId!));
    await _db.into(_db.reviewCards).insert(cardWithLeaf);
    return insertedIds;
  });
}
```

This keeps transaction boundaries inside the repository layer. The controller constructor does NOT change.

### 4. Update `_persistMoves()` Path B to use `saveBranch()`

**File:** `src/lib/controllers/add_line_controller.dart`

Replace the Path B move loop + `_reviewRepo.saveReview()` call with a single call to `_repertoireRepo.saveBranch()`.

### 5. Wrap `_persistMoves()` in try/catch with exception unwrapping

**File:** `src/lib/controllers/add_line_controller.dart`

Add `import 'package:sqlite3/common.dart';` at the top.

Wrap the entire body of `_persistMoves()` in try/catch. Use a helper to unwrap exceptions:

```dart
SqliteException? _extractSqliteException(Object error) {
  if (error is SqliteException) return error;
  // Drift wraps SqliteException in some code paths.
  if (error case DriftWrappedException(:final Object cause)) {
    if (cause is SqliteException) return cause;
  }
  return null;
}
```

- If `_extractSqliteException` returns non-null with `extendedResultCode == 2067` (SQLITE_CONSTRAINT_UNIQUE), return `ConfirmError(userMessage: 'This line already exists in the repertoire.', error: e)`.
- Otherwise, return `ConfirmError(userMessage: 'Could not save the line. Please try again.', error: e)`.
- In both catch branches, call `await loadData()` to restore consistent state.

### 6. Handle `ConfirmError` in `_onConfirmLine()`

**File:** `src/lib/screens/add_line_screen.dart`

Add a case in the `switch` statement:

```dart
case ConfirmError(:final userMessage):
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(userMessage),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
```

### 7. Handle `ConfirmError` in `_onFlipAndConfirm()`

**File:** `src/lib/screens/add_line_screen.dart`

Update to handle `ConfirmError` in addition to `ConfirmSuccess`:

```dart
Future<void> _onFlipAndConfirm() async {
  setState(() => _parityWarning = null);
  final result = await _controller.flipAndConfirm();
  if (!mounted) return;
  if (result is ConfirmSuccess) {
    _handleConfirmSuccess(result);
  } else if (result is ConfirmError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.userMessage),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
```

### 8. Add controller unit tests

**File:** `src/test/controllers/add_line_controller_test.dart`

Add a `'Confirm error handling'` test group:

1. **Duplicate move triggers ConfirmError:** Seed a tree, then directly insert a conflicting move into the DB before calling `confirmAndPersist()`. Verify the result is `ConfirmError` with the duplicate-specific message.
2. **State remains consistent after error:** After a `ConfirmError`, verify `controller.hasNewMoves` is `false` and `state.isLoading` is `false`.
3. **saveBranch atomicity:** Verify that after a constraint error during branching, no partial moves remain in the DB.

### 9. Add widget tests for error SnackBar display

**File:** `src/test/screens/add_line_screen_test.dart`

1. **`_onConfirmLine` shows error SnackBar:** Trigger a constraint violation, tap Confirm, verify SnackBar text.
2. **`_onFlipAndConfirm` shows error SnackBar:** Trigger parity mismatch + constraint violation, verify SnackBar text.

## Risks / Open Questions

1. **Drift exception wrapping:** Step 5 explicitly handles both direct `SqliteException` and `DriftWrappedException(cause: SqliteException)`. If the current Drift version does not export `DriftWrappedException` from `package:drift/drift.dart`, check `package:drift/src/runtime/api/exceptions.dart`.

2. **`saveBranch` crosses review/repertoire boundary:** The new method creates a review card, which is conceptually a `ReviewRepository` concern. This is acceptable because `extendLine()` already follows the same pattern. A future refactoring could introduce a composite persistence service.

3. **Review issue 2 (constructor change) is now moot:** Since the transaction is inside `saveBranch` in the repository, the controller constructor does not change. No call-site updates needed.

4. **Testing constraint violations:** The `LineEntryEngine` normally prevents duplicate moves by following existing branches. Tests must directly insert conflicting rows into the DB between engine preparation and persistence.
