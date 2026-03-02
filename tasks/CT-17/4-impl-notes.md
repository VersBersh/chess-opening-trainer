# CT-17: Implementation Notes

## Files Modified

- **`src/lib/repositories/repertoire_repository.dart`** -- Added `renameRepertoire(int id, String newName)` to the abstract interface.
- **`src/lib/repositories/local/local_repertoire_repository.dart`** -- Implemented `renameRepertoire` using Drift's `update...write` pattern (matching `updateMoveLabel`).
- **`src/lib/screens/home_screen.dart`** -- Major changes:
  - Removed `openRepertoire()` from `HomeController`.
  - Added `createRepertoire(name)`, `renameRepertoire(id, newName)`, and `deleteRepertoire(id)` to `HomeController`.
  - Added `_showCreateRepertoireDialog()`, `_showRenameRepertoireDialog(currentName)`, and `_showDeleteRepertoireDialog(repertoireName)` to `_HomeScreenState`.
  - Added `PopupMenuButton` context menu to each repertoire card header with Rename and Delete options.
  - Added `FloatingActionButton` to the Scaffold when repertoires exist.
  - Replaced `_onCreateFirstRepertoire` to use the Create dialog instead of auto-creating "My Repertoire"; navigates to browser after creation.
  - Removed `TODO(CT-next)` comment from `_buildEmptyState`.
- **`src/test/screens/home_screen_test.dart`** -- Updated `FakeRepertoireRepository`:
  - `deleteRepertoire` now actually removes from internal list.
  - Added `renameRepertoire` that updates name in internal list.
  - Added 14 widget tests in `HomeScreen -- repertoire CRUD` group covering empty-state create, FAB create, rename, and delete flows.
- **`src/test/screens/drill_filter_test.dart`** -- Added no-op `renameRepertoire` stub to `FakeRepertoireRepository`.
- **`src/test/screens/drill_screen_test.dart`** -- Added no-op `renameRepertoire` stub to `FakeRepertoireRepository`.
- **`src/test/repositories/local_repertoire_repository_test.dart`** -- Added `renameRepertoire` test group with 3 tests (rename, persistence, isolation).

## Deviations from Plan

None. All 11 steps were implemented as specified.

## Follow-up Work

- The "Empty-state create navigates to browser" test uses a real in-memory DB (matching the existing pattern for navigation tests in this file). If this becomes slow, consider mocking navigation instead.
- The delete confirmation dialog's "Delete" button uses `colorScheme.error` for the text color, which provides a destructive visual cue. The background color is not changed (standard TextButton).
- The `maxLength: 100` on TextFields causes Flutter to show a character counter by default. This is acceptable UX but could be hidden with `InputDecoration(counterText: '')` if desired.
