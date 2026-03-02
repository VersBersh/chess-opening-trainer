# CT-2.5 Implementation Plan

## Goal

Add an undo snackbar to the line extension flow so that after confirming an extension, the user has ~8 seconds to revert: deleting the new moves and restoring the old review card with its original SR state.

## Steps

### Step 1: Change `extendLine` return type to provide inserted move IDs

Files: `src/lib/repositories/repertoire_repository.dart`, `src/lib/repositories/local/local_repertoire_repository.dart`

- Change abstract method signature from `Future<void> extendLine(...)` to `Future<List<int>> extendLine(...)` where the returned list contains IDs of all newly inserted `RepertoireMove` rows, in insertion order.
- In `LocalRepertoireRepository.extendLine()`, collect each `lastInsertedId` into a list and return it at the end of the transaction.
- Update fake/stub implementations in test files (`src/test/screens/drill_screen_test.dart`, `src/test/screens/home_screen_test.dart`) to return `[]` from `extendLine`.

### Step 2: Add `undoExtendLine` method to repository layer

Files: `src/lib/repositories/repertoire_repository.dart`, `src/lib/repositories/local/local_repertoire_repository.dart`

- Add abstract method: `Future<void> undoExtendLine(int oldLeafMoveId, List<int> insertedMoveIds, ReviewCard oldCard)`
- Implement in `LocalRepertoireRepository`: run in a transaction that:
  1. **Guard invalid input:** If `insertedMoveIds` is empty, return immediately (no-op). This handles the degenerate case where extendLine was called with an empty move list.
  2. **Assert consistency:** Verify `oldCard.leafMoveId == oldLeafMoveId`. If not, throw a `StateError` indicating a contract violation. This catches programming errors where the caller passes mismatched arguments.
  3. Deletes the first move in `insertedMoveIds` (cascade will remove all descendants and the new review card).
  4. Re-inserts the old review card using `oldCard.toCompanion(false)` but with `id: Value.absent()` so it gets a fresh auto-increment ID. Explicitly set `leafMoveId: Value(oldLeafMoveId)` from the parameter rather than relying on the companion's value, ensuring the restored card points to the correct move even if the in-memory object were somehow stale.

### Step 3: Capture old card state before extension in `_onConfirmLine`

File: `src/lib/screens/repertoire_browser_screen.dart`

- Before calling `repRepo.extendLine(...)` in the extension path, call `reviewRepo.getCardForLeaf(confirmData.parentMoveId!)` to fetch the old `ReviewCard`. Store in a local variable.
- After `extendLine` returns, capture the returned list of inserted move IDs.

### Step 4: Add undo snackbar after successful extension

File: `src/lib/screens/repertoire_browser_screen.dart`

- After extension is persisted and tree cache reloaded, **check `if (!mounted) return;`** before accessing `ScaffoldMessenger` or showing the snackbar. This prevents a crash if the widget is disposed during the async gap between `_loadData()` and snackbar display.
- Show a `SnackBar`:
  - Duration: `Duration(seconds: 8)`
  - Content: `"Line extended"`
  - Action label: `"Undo"`
  - On action pressed: call undo handler (step 5)
  - `behavior: SnackBarBehavior.floating`
- Show via `ScaffoldMessenger.of(context).showSnackBar(...)`.

### Step 5: Implement undo handler with mounted guards

File: `src/lib/screens/repertoire_browser_screen.dart`

- Closure capturing `oldCard`, `insertedMoveIds`, and `confirmData.parentMoveId`:
  1. Call `repRepo.undoExtendLine(oldLeafMoveId, insertedMoveIds, oldCard)`. (DB operations are safe even if widget is disposed; they run to completion.)
  2. Guard UI updates with `if (!mounted) return;` before calling `_loadData()`.
  3. Do NOT call a separate `setState()` after `_loadData()` -- `_loadData()` already contains its own internal `mounted` check wrapping `setState()`, so an additional call is redundant.

### Step 6: Invalidate prior undo snackbars before new extensions

File: `src/lib/screens/repertoire_browser_screen.dart`

- Add a generation counter field `_undoGeneration` (type `int`, initialized to `0`) to the widget state.
- At the start of the extension path in `_onConfirmLine` (before any async work), increment `_undoGeneration` and call `ScaffoldMessenger.of(context).hideCurrentSnackBar()` to dismiss any prior undo snackbar.
- When creating the undo closure, capture the current `_undoGeneration` value. Inside the closure, compare the captured value against `_undoGeneration` at execution time. If they differ, another extension has started since this snackbar was shown -- silently return without undoing.
- This two-layer defense (dismiss + generation check) ensures:
  1. The visible snackbar is dismissed so the user cannot tap an outdated "Undo" button.
  2. Even if a race condition allows the old closure to fire (e.g., the dismiss animation overlaps with a tap), the generation check prevents stale undo logic from executing.

### Step 7: Structure the confirm flow for clarity

File: `src/lib/screens/repertoire_browser_screen.dart`

Extract snackbar logic into `_showExtensionUndoSnackbar(oldLeafMoveId, insertedMoveIds, oldCard)`. The extension path in `_onConfirmLine` becomes:
1. Increment `_undoGeneration` and dismiss any current snackbar
2. Fetch old card
3. Persist extension (returns inserted move IDs)
4. Reload data and exit edit mode
5. Guard with `if (!mounted) return;`
6. Show undo snackbar (if old card existed)

### Step 8: Write unit tests for `undoExtendLine`

File: `src/test/repositories/local_repertoire_repository_test.dart` (create or extend)

- Test `undoExtendLine` correctly deletes extension moves, cascade-removes new card, re-inserts old card with original SR values.
- Test old leaf move still exists after undo.
- Test `undoExtendLine` with empty `insertedMoveIds` is a no-op (no crash, no changes).
- Test `undoExtendLine` throws `StateError` when `oldCard.leafMoveId != oldLeafMoveId`.

### Step 9: Write widget tests for the undo snackbar

File: `src/test/screens/repertoire_browser_screen_test.dart`

- Test snackbar appears after confirming line extension.
- Test "Undo" reverts extension (new moves gone, old card restored with original SR values).
- Test snackbar expiry does not revert.
- Test that starting a new extension dismisses the prior undo snackbar and only the latest undo is actionable.

## Risks / Open Questions

1. **`extendLine` return type change is a breaking interface change.** All implementations (including test stubs) must be updated. Low risk -- only 2 stubs (`drill_screen_test.dart`, `home_screen_test.dart`).

2. **Auto-increment ID reuse on card restore.** Re-inserted card gets new `id`, not original. Correct because no code caches `ReviewCard.id` across snackbar window. `leafMoveId` FK is what matters.

3. **Race condition: user navigates away during snackbar.** `mounted` checks protect against `ScaffoldMessenger.of(context)` and `setState` on disposed widget. DB operations in undo handler are safe even if widget is disposed. `_loadData()` has its own internal `mounted` guard at line 159 of the current screen code.

4. **Cascade delete correctness.** Undo relies on SQLite CASCADE: deleting first inserted child cascades all descendants. Sound given schema (`RepertoireMoves.parentMoveId` has `onDelete: KeyAction.cascade`), and `PRAGMA foreign_keys = ON` is set in `migration.beforeOpen`.

5. **Multiple rapid extensions (overlapping undo windows).** Addressed explicitly in Step 6 with a two-layer defense: dismiss prior snackbar + generation counter. The generation counter prevents stale undo payloads from executing even if the dismiss races with a tap.

6. **Empty `insertedMoveIds` / mismatched `oldCard.leafMoveId`.** Addressed in Step 2 with an early-return no-op for empty lists and a `StateError` assertion for mismatched IDs. These are defensive guards against programming errors rather than expected user paths.
