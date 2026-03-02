# CT-23 Plan

## Goal

Add a widget test that verifies dismissing the orphan prompt (null dialog result) preserves the orphaned move, testing the Critical null-result bug fix from CT-2.4.

## Steps

### 1. Add the dismiss test to the Deletion group

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

Add a new `testWidgets` inside the existing `group('Deletion', ...)` block (after the existing orphan tests, before the closing `});` of the Deletion group at line 1374). The test name should follow the existing pattern:

```
'orphan prompt -- dismiss preserves the orphaned move'
```

**Test logic:**

1. **Seed:** Create a repertoire with a single line `['e4', 'e5']` and `createCards: true`. This means `e5` is a leaf with a review card, and deleting it will make `e4` childless, triggering the orphan prompt.

2. **Pump and settle:** `buildTestApp(db, repId)`, then `pumpAndSettle()`.

3. **Select and delete e5:**
   - Tap `'1...e5'` to select the leaf.
   - Tap the `'Delete'` button.
   - `pumpAndSettle()` to show the confirmation dialog.
   - Confirm by tapping the second `'Delete'` button (the one in the dialog).
   - `pumpAndSettle()`.

4. **Verify orphan prompt appears:** Assert `find.text('Keep shorter line')` finds one widget and `find.text('Remove move')` finds one widget.

5. **Dismiss the dialog without selecting either button:** Use `tester.tap(find.byType(ModalBarrier).last)` to tap the barrier widget directly. This is deterministic regardless of dialog layout. Follow with `pumpAndSettle()`. This requires importing `package:flutter/material.dart` (already imported in the test file).

   ```dart
   // Tap the barrier to dismiss the dialog (returns null).
   await tester.tap(find.byType(ModalBarrier).last);
   await tester.pumpAndSettle();
   ```

   If `find.byType(ModalBarrier).last` does not find a tappable barrier (unlikely, but possible if Flutter stacks barriers differently), fall back to `tester.tapAt(const Offset(0, 0))` which taps the top-left corner outside the centered dialog. As a last resort, use `Navigator.of(tester.element(find.text('Keep shorter line'))).pop()` to programmatically dismiss.

6. **Verify the orphaned move is preserved:**
   - Assert `find.text('1. e4')` finds one widget (e4 is still visible in the tree).
   - Assert `find.text('1...e5')` finds nothing (e5 was deleted as intended).

7. **Verify DB state:**
   - Query moves via `LocalRepertoireRepository(db).getMovesForRepertoire(repId)`.
   - Assert moves has length 1 and the remaining move has `san == 'e4'`.
   - Query review cards via `LocalReviewRepository(db).getAllCardsForRepertoire(repId)`.
   - Assert no card exists for e4 (since "Keep shorter line" was NOT chosen, no card should have been created). The original e5 card was cascade-deleted when e5 was deleted, and no new card was created for e4.

### 2. Verify the test passes

Run the test file from the `src/` directory (since `pubspec.yaml` lives in `src/`, not the repository root):

```
cd src && flutter test test/screens/repertoire_browser_screen_test.dart
```

## Risks / Open Questions

1. **Barrier tap approach:** The primary approach uses `find.byType(ModalBarrier).last` which is deterministic and layout-independent. The original plan used `tester.tapAt(const Offset(0, 0))` which is plausible but can be brittle if hit-testing or layout edge cases cause the tap to miss the barrier. The `ModalBarrier` finder is preferred because it targets the widget directly. No existing tests in this file use either pattern (dialogs are always dismissed via button taps), so we should verify the chosen approach works and fall back as described in Step 5 if needed.

2. **No existing test for null choice at the controller level either.** The controller unit test file (`repertoire_browser_controller_test.dart`) also lacks a test for `handleOrphans` with a null prompt callback result. The task description only requires a widget test, but a companion controller-level unit test would be a low-cost addition. This is out of scope per the task spec but worth noting.

3. **Empty tree vs. single-node tree after dismiss.** After dismissing the orphan dialog, the tree should show e4 as a standalone move with no children. The tree will reload via `_controller.loadData()` (called in `_onDeleteLeaf` after `handleOrphans` returns). The e4 node should appear as a leaf in the tree UI. The "No moves yet" empty state should NOT appear.
