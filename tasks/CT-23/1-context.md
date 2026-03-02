# CT-23 Context

## Relevant Files

- `src/lib/controllers/repertoire_browser_controller.dart` -- Contains `handleOrphans()` method with the null-result bug fix at line 304: `if (choice == null) { break; }`. Also contains `OrphanChoice` enum and `deleteMoveAndGetParent()`. This is the code under test.
- `src/lib/screens/repertoire_browser_screen.dart` -- UI layer. Contains `_showOrphanPrompt()` (lines 289-321) which uses `showDialog<OrphanChoice>` to present the orphan dialog. Dismissing the dialog (system back, barrier tap) returns `null`. Also contains `_onDeleteLeaf()` and `_onDeleteBranch()` which call `handleOrphans()`.
- `src/test/screens/repertoire_browser_screen_test.dart` -- Existing widget test file (1545 lines). Contains the `Deletion` test group (starts line 1036) with 9 tests covering leaf deletion, orphan prompt appearance, keep/remove choices, sibling deletion, branch deletion, and root deletion. This is the file to modify. Also contains shared helpers: `createTestDatabase()`, `seedRepertoire()`, and `buildTestApp()`.
- `src/test/controllers/repertoire_browser_controller_test.dart` -- Unit tests for the controller. Has `handleOrphans` group (line 399) with tests for `keepShorterLine` and `removeMove` choices, but no test for null (dismiss) result.
- `src/lib/repositories/repertoire_repository.dart` -- Abstract interface with `deleteMove()`, `getChildMoves()`, `getMove()` used by orphan handling.
- `src/lib/repositories/local/local_repertoire_repository.dart` -- SQLite implementation of `RepertoireRepository`. Used by widget tests via in-memory database.
- `src/lib/repositories/local/local_review_repository.dart` -- SQLite implementation of `ReviewRepository`. Used by widget tests via in-memory database.
- `src/lib/repositories/local/database.dart` -- Drift schema with CASCADE foreign keys. `deleteMove` cascades to descendants and their review cards.
- `tasks/CT-2.4/5-impl-review-design.md` -- Design review that identified the Critical null-result bug: "any dialog result other than `keepShorterLine` is treated as `removeMove`" and recommended handling null explicitly as cancel/abort.
- `tasks/CT-2.4/4-impl-notes.md` -- Documents the post-review fix: "when the orphan dialog is dismissed (returns `null`), the loop now breaks (aborts orphan handling) instead of falling through to the destructive 'Remove move' branch."
- `tasks/CT-2.4/6-discovered-tasks.md` -- Item #3 is the origin of this task: "Test that dismissing orphan dialog does not delete the move."
- `architecture/testing-strategy.md` -- Testing strategy document. Confirms widget tests should focus on interaction behavior, and that orphan handling is a key scenario.

## Architecture

### Orphan dialog dismiss flow

When a user deletes a leaf move whose parent becomes childless, the controller's `handleOrphans()` method is invoked with a `promptUser` callback. The callback (in the screen layer, `_showOrphanPrompt`) shows a Flutter `showDialog<OrphanChoice>` with two buttons:

1. **"Keep shorter line"** -- pops with `OrphanChoice.keepShorterLine`
2. **"Remove move"** -- pops with `OrphanChoice.removeMove`

If the user dismisses the dialog without selecting either button (system back, tapping outside the barrier), `showDialog` returns `null`. The controller handles this at line 304:

```dart
if (choice == null) {
  break; // Dialog dismissed -- abort orphan handling
}
```

This was the Critical bug fix from CT-2.4. Before the fix, `null` fell through to the `else` branch, which executed `deleteMove` -- a destructive, unintended action.

### How the widget test interacts with the dialog

Existing deletion widget tests follow a pattern:
1. Seed a repertoire with `seedRepertoire()` (in-memory DB, with `createCards: true`)
2. Pump the screen with `buildTestApp()`
3. Select a move, tap Delete, confirm the deletion dialog
4. The orphan dialog appears (if the parent is now childless)
5. Tap "Keep shorter line" or "Remove move"
6. Verify the DB state

To test the dismiss case, the test needs to trigger the orphan dialog and then dismiss it without tapping either button. In Flutter widget tests, the standard way to dismiss a dialog is to tap the barrier (the semi-transparent overlay behind the dialog) or simulate a back gesture. The dialog in `_showOrphanPrompt` uses default `showDialog` which is dismissible by default (`barrierDismissible: true`).

### Key constraints

- The orphan dialog is barrier-dismissible by default (no `barrierDismissible: false`), so tapping the barrier area will close it and return null.
- The test must verify that after dismissal, the orphaned move (the parent that became childless) still exists in the database and is visible in the tree.
- The test must also verify that no review card was created for the orphaned move (since neither "Keep shorter line" nor "Remove move" was chosen).
