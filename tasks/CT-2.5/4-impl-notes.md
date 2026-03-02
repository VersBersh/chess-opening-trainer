# CT-2.5 Implementation Notes

## Files Modified

- **`src/lib/repositories/repertoire_repository.dart`** — Changed `extendLine` return type from `Future<void>` to `Future<List<int>>`. Added `undoExtendLine` abstract method.
- **`src/lib/repositories/local/local_repertoire_repository.dart`** — Updated `extendLine` to collect and return inserted move IDs. Implemented `undoExtendLine` with empty-list guard, leafMoveId consistency assertion, cascade delete of first inserted move, and re-insertion of old review card with fresh auto-increment ID.
- **`src/lib/screens/repertoire_browser_screen.dart`** — Added `_undoGeneration` counter field. Modified `_onConfirmLine` to: invalidate prior snackbars, capture old card before extension, persist and collect inserted IDs, show undo snackbar after reload. Added `_showExtensionUndoSnackbar` method with generation-guarded undo closure and mounted checks.
- **`src/test/screens/drill_screen_test.dart`** — Updated `FakeRepertoireRepository.extendLine` to return `Future<List<int>>` (returns `[]`). Added `undoExtendLine` stub.
- **`src/test/screens/home_screen_test.dart`** — Updated `FakeRepertoireRepository.extendLine` to return `Future<List<int>>` (returns `[]`). Added `undoExtendLine` stub.

## Files Created

- **`src/test/repositories/local_repertoire_repository_test.dart`** — Unit tests for `undoExtendLine`: verifies cascade delete of extension moves, restoration of old review card with original SR values, no-op on empty insertedMoveIds, and StateError on mismatched leafMoveId.
- **`src/test/screens/repertoire_browser_screen_test.dart`** (appended) — Widget tests for extension undo snackbar: snackbar appears after extension, undo reverts extension and restores card, snackbar expiry does not revert, and new extension dismisses prior snackbar with only latest undo actionable.

## Deviations from Plan

- **Path B (branching) also gets mounted guard:** The plan focused the `mounted` guard on the extension path, but I also added `if (!mounted) return;` to the branching path (Path B) for consistency, replacing the previous pattern where both paths shared a single post-persist block.
- **No separate `setState` after `_loadData` in undo handler:** As specified in Step 5, the undo handler does not call `setState` after `_loadData` since `_loadData` has its own internal `mounted` check wrapping `setState`.

## Follow-up Work

- None discovered during implementation. The cascade-delete approach is sound given the schema constraints and `PRAGMA foreign_keys = ON`.
