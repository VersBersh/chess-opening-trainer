# CT-47: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/repositories/local/local_repertoire_repository.dart` | Added `ORDER BY id ASC` to `getAllRepertoires()` for deterministic ordering. |
| `src/lib/screens/home_screen.dart` | Replaced multi-repertoire card list + FAB with three-button layout (Start Drill, Free Practice, Manage Repertoire). Removed `_showRenameRepertoireDialog`, `_showDeleteRepertoireDialog`, `_onAddLineTap`, `_buildRepertoireList`. Removed imports for `repertoire_card.dart` and `add_line_screen.dart`. Added `_buildActionButtons` method using first repertoire's `summary.dueCount` for the headline. |
| `src/test/screens/home_screen_test.dart` | Removed all tests for deleted UI: FAB create flow (3 tests), Context menu / Rename (3 tests), Delete (4 tests), multi-repertoire card layout (7 tests including Add Line navigation and repertoire name tap). Removed `add_line_screen.dart` import. Added new tests: three buttons visible, no Card/FAB, Manage Repertoire navigation, Start Drill navigation with due cards, Start Drill snackbar with no due cards, due count uses per-repertoire count. Reorganized remaining tests into clearer groups. |

## Deviations from Plan

1. **Steps 2-4 applied together.** The plan describes steps 2, 3, and 4 as separate edits to the same file. These were applied in a single pass to avoid intermediate broken states. The end result matches the plan exactly.

2. **Empty-state test assertions updated.** The old empty-state test asserted `find.text('Add Line')` as `findsNothing`. The new test asserts `find.text('Manage Repertoire')` as `findsNothing` instead, matching the new button set.

3. **Test for "tapping repertoire name navigates to RepertoireBrowserScreen" removed.** This test relied on the old UI where tapping a repertoire name navigated to the browser. The equivalent behavior is now covered by the "Manage Repertoire navigates to RepertoireBrowserScreen" test.

## Follow-up Work

- `src/lib/widgets/repertoire_card.dart` is now unused by the home screen. It could be deleted if no other screen references it. A quick check for other usages is recommended before removal.
- The `renameRepertoire` and `deleteRepertoire` methods on `HomeController` are preserved but now have no UI trigger from the home screen. They remain for future multi-repertoire support.
