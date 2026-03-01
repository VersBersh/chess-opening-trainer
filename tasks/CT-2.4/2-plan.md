# CT-2.4 Plan

## Goal

Wire the Delete button and "Delete branch" action to the repository layer, with confirmation dialogs, orphan prompts ("Keep shorter line" / "Remove move"), and tree cache rebuild after mutations.

## Steps

### 1. Implement parent-lookup-then-delete as a private helper in the browser screen

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Rather than adding a `deleteSubtree` method to the `RepertoireRepository` interface, implement the parent lookup inline in the browser screen's delete handlers. The existing `deleteMove(int id)` already cascades via the FK constraint to remove all descendants and their review cards, so a separate `deleteSubtree` method on the abstract interface would be a thin wrapper that adds API surface without meaningful functional gain.

Add a private helper method in `_RepertoireBrowserScreenState`:

```dart
/// Deletes a move (and all descendants via CASCADE) and returns the parent ID.
Future<int?> _deleteMoveAndGetParent(int moveId) async {
  final repRepo = LocalRepertoireRepository(widget.db);
  final move = await repRepo.getMove(moveId);
  if (move == null) return null;
  final parentId = move.parentMoveId;
  await repRepo.deleteMove(moveId); // CASCADE handles descendants + cards
  return parentId;
}
```

This keeps the repository interface stable and avoids interface churn for a one-liner.

**Depends on:** Nothing.

### 2. Add `_onDeleteLeaf` handler to the browser screen

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Implement the core leaf deletion flow as a method `_onDeleteLeaf()`:

1. Get the selected move from the tree cache.
2. Show a confirmation dialog: "Delete this move and its review card?"
3. On confirm:
   a. Call `_deleteMoveAndGetParent(selectedMoveId)` which returns the `parentId`.
   b. If `parentId != null`, check if the parent is now childless via `repRepo.getChildMoves(parentId)`.
   c. If childless, run the orphan handling loop (Step 4).
   d. If `parentId == null` (deleted a root move), no orphan handling needed.
4. Add `if (!mounted) return;` guard after each `await` point (confirmation dialog, delete call, orphan handling) before calling `setState` or showing further dialogs. This matches the existing pattern used in `_onConfirmLine` and `_loadData`.
5. Call `_loadData()` to rebuild the tree cache.
6. Clear the selection (`selectedMoveId = null`).

```dart
Future<void> _onDeleteLeaf() async {
  final selectedId = _state.selectedMoveId;
  if (selectedId == null) return;

  final confirmed = await _showDeleteConfirmationDialog();
  if (!mounted || confirmed != true) return;

  final parentId = await _deleteMoveAndGetParent(selectedId);
  if (!mounted) return;

  if (parentId != null) {
    await _handleOrphans(parentId);
    if (!mounted) return;
  }

  await _loadData();
  if (!mounted) return;

  setState(() {
    _state = _state.copyWith(selectedMoveId: () => null);
  });
}
```

**Depends on:** Step 1.

### 3. Add `_onDeleteBranch` handler to the browser screen

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Implement subtree deletion as a method `_onDeleteBranch()`:

1. Get the selected move from the tree cache.
2. Query counts for the confirmation dialog:
   - `repRepo.countLeavesInSubtree(selectedMoveId)` for the number of lines.
   - `reviewRepo.getCardsForSubtree(selectedMoveId)` for the number of cards.
3. Show a confirmation dialog: "This will delete N lines and N review cards. Continue?"
4. On confirm:
   a. Call `_deleteMoveAndGetParent(selectedMoveId)` which returns the `parentId`.
   b. If `parentId != null`, check if the parent is now childless via `repRepo.getChildMoves(parentId)`.
   c. If childless, run the orphan handling loop (Step 4).
5. Add `if (!mounted) return;` guards after every `await` point before any `setState` or dialog calls.
6. Call `_loadData()` to rebuild the tree cache.
7. Clear the selection.

```dart
Future<void> _onDeleteBranch() async {
  final selectedId = _state.selectedMoveId;
  if (selectedId == null) return;

  final repRepo = LocalRepertoireRepository(widget.db);
  final reviewRepo = LocalReviewRepository(widget.db);

  final lineCount = await repRepo.countLeavesInSubtree(selectedId);
  final cards = await reviewRepo.getCardsForSubtree(selectedId);
  if (!mounted) return;

  final confirmed = await _showBranchDeleteConfirmationDialog(
    lineCount: lineCount,
    cardCount: cards.length,
  );
  if (!mounted || confirmed != true) return;

  final parentId = await _deleteMoveAndGetParent(selectedId);
  if (!mounted) return;

  if (parentId != null) {
    await _handleOrphans(parentId);
    if (!mounted) return;
  }

  await _loadData();
  if (!mounted) return;

  setState(() {
    _state = _state.copyWith(selectedMoveId: () => null);
  });
}
```

**Depends on:** Step 1.

### 4. Implement `_handleOrphans` loop

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Create a method `_handleOrphans(int parentMoveId)` that handles the recursive orphan case using a loop (not actual recursion, to avoid deep dialog stacking):

```dart
Future<void> _handleOrphans(int? parentMoveId) async {
  final repRepo = LocalRepertoireRepository(widget.db);
  int? currentId = parentMoveId;

  while (currentId != null) {
    final children = await repRepo.getChildMoves(currentId);
    if (children.isNotEmpty) break; // not an orphan

    if (!mounted) return;

    final choice = await _showOrphanPrompt(currentId);
    if (!mounted) return;

    if (choice == OrphanChoice.keepShorterLine) {
      final move = await repRepo.getMove(currentId);
      if (move == null) break;
      final reviewRepo = LocalReviewRepository(widget.db);
      await reviewRepo.saveReview(ReviewCardsCompanion.insert(
        repertoireId: move.repertoireId,
        leafMoveId: currentId,
        nextReviewDate: DateTime.now(),
      ));
      break;
    } else {
      // Remove move -- delete and check its parent
      final move = await repRepo.getMove(currentId);
      final nextParent = move?.parentMoveId;
      await repRepo.deleteMove(currentId);
      currentId = nextParent;
    }
  }
}
```

The orphan prompt dialog shows the move's SAN in context, e.g., "Move 3. d4 has no remaining children." and offers two choices:

- **"Keep shorter line"** -- Creates a new `ReviewCard` for the orphan move (now the new leaf). The card uses `ReviewCardsCompanion.insert(...)` with only the required fields (`repertoireId`, `leafMoveId`, `nextReviewDate: DateTime.now()`). The DB schema supplies the SR defaults: `easeFactor` defaults to `2.5`, `intervalDays` defaults to `1`, `repetitions` defaults to `0`. Note: the `line-management.md` spec says "interval 0" for new cards, but the actual DB schema default for `interval_days` is `1`. The plan follows the DB schema as-is; if the spec intent is `interval_days = 0`, that should be addressed as a separate migration task.
- **"Remove move"** -- Calls `repRepo.deleteMove(orphanMoveId)`, which cascades. The loop then checks the grandparent.

**Depends on:** Steps 2, 3.

### 5. Update the browse-mode action bar to support both leaf deletion and branch deletion

**File:** `src/lib/screens/repertoire_browser_screen.dart`

Modify the `_buildBrowseModeActionBar` method. The current stub has a single "Delete" button enabled only for leaves. Change it to:

- **When a leaf is selected:** The "Delete" button calls `_onDeleteLeaf`.
- **When a non-leaf node is selected:** The "Delete" button calls `_onDeleteBranch` (subtree deletion). Change the button to be enabled whenever a node is selected (not just for leaves). Update the label to "Delete" for leaves and "Delete Branch" for non-leaf nodes.

The simplest approach: keep one "Delete" button, enabled whenever any node is selected. When tapped, if the node is a leaf, run the leaf deletion flow; if it has children, run the branch deletion flow (which shows the subtree count in the confirmation dialog).

```dart
TextButton.icon(
  onPressed: selectedId != null
      ? () {
          if (isLeaf) {
            _onDeleteLeaf();
          } else {
            _onDeleteBranch();
          }
        }
      : null,
  icon: const Icon(Icons.delete, size: 18),
  label: Text(isLeaf ? 'Delete' : 'Delete Branch'),
),
```

**Depends on:** Steps 2, 3.

### 6. Update existing action-bar tests to reflect new Delete button behavior

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

The existing test `'action buttons enabled/disabled state'` (line ~312) explicitly asserts that the Delete button is disabled when a non-leaf node is selected (`expect(deleteButton.onPressed, isNull)`). With the new behavior, Delete is enabled for all selected nodes (with a different label for non-leaf nodes).

Update the assertions in this test:

1. When a non-leaf node is selected, the button should now be **enabled** (not disabled).
2. The button label should be `'Delete Branch'` when a non-leaf node is selected and `'Delete'` when a leaf is selected.
3. Keep the existing assertion that `Focus` is enabled for labeled nodes and disabled for unlabeled nodes (this behavior is unchanged).

```dart
// Select e4 (labeled, has children so NOT a leaf).
await tester.tap(find.textContaining('1. e4'));
await tester.pump();

// Delete Branch button should be enabled (non-leaf node)
final deleteBranchButton = tester.widget<TextButton>(
  find.widgetWithText(TextButton, 'Delete Branch'),
);
expect(deleteBranchButton.onPressed, isNotNull);

// ... later, after selecting leaf Nf3 ...

// Delete should be enabled (leaf) with label "Delete"
final deleteButton2 = tester.widget<TextButton>(
  find.widgetWithText(TextButton, 'Delete'),
);
expect(deleteButton2.onPressed, isNotNull);
```

**Depends on:** Step 5.

### 7. Add a `createCards` parameter to `seedRepertoire` in test helpers

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

The existing `seedRepertoire` helper creates moves but does not create review cards for leaves. For deletion tests, cards must exist to verify they are properly removed. Extend the `seedRepertoire` helper to optionally create review cards for leaf moves.

Add a `createCards: true` parameter (defaulting to `false` to avoid breaking existing tests). When `true`, after inserting all moves, identify the leaves (moves that are not the parent of any other move in the inserted set) and insert a `ReviewCardsCompanion` for each with required fields only (`repertoireId`, `leafMoveId`, `nextReviewDate: DateTime.now()`), letting the DB schema supply default SR values.

```dart
Future<int> seedRepertoire(
  AppDatabase db, {
  String name = 'Test Repertoire',
  List<List<String>> lines = const [],
  Map<String, String> labelsOnSan = const {},
  bool createCards = false,
}) async {
  // ... existing move insertion logic ...

  if (createCards) {
    // Identify leaves: moves that are not the parent of any other inserted move.
    final allParentIds = insertedMoves.values.toSet();
    final allInsertedIds = insertedMoves.values.toSet();
    final parentOfSomeone = <int>{};
    for (final key in insertedMoves.keys) {
      final parts = key.split(':');
      if (parts[0] != 'root') {
        parentOfSomeone.add(int.parse(parts[0]));
      }
    }
    final leafIds = allInsertedIds.difference(parentOfSomeone);
    for (final leafId in leafIds) {
      await db.into(db.reviewCards).insert(
        ReviewCardsCompanion.insert(
          repertoireId: repId,
          leafMoveId: leafId,
          nextReviewDate: DateTime.now(),
        ),
      );
    }
  }

  return repId;
}
```

**Depends on:** Nothing (test infrastructure). Must be completed before Steps 8 and 9.

### 8. Write widget tests for leaf deletion

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

Add a test group `'Deletion'` with test cases:

1. **Delete a leaf node -- card is removed, tree updates.**
   - Seed a repertoire with `createCards: true` and line `['e4', 'e5', 'Nf3']`.
   - Select `Nf3`, tap Delete, confirm.
   - Verify the tree no longer shows `Nf3`.
   - Verify the card for `Nf3` is gone from the database.

2. **Delete a leaf -- orphan prompt appears when parent becomes childless.**
   - Seed a repertoire with `createCards: true` and a single line `['e4', 'e5']`.
   - Select `e5`, tap Delete, confirm.
   - Verify the orphan prompt dialog appears with "Keep shorter line" and "Remove move" options.

3. **Orphan prompt -- "Keep shorter line" creates a new card for the parent.**
   - Continue from (2), tap "Keep shorter line."
   - Verify a new card exists for `e4` in the database.
   - Verify `e4` is now shown as a leaf in the tree.

4. **Orphan prompt -- "Remove move" deletes the parent, recurses if needed.**
   - Seed with `createCards: true`, line `['e4', 'e5']`.
   - Delete `e5`, orphan prompt for `e4`, choose "Remove move."
   - Verify `e4` is also deleted.
   - Verify the tree is empty.

5. **Deletion with sibling -- no orphan prompt.**
   - Seed with `createCards: true`, lines `['e4', 'e5']` and `['e4', 'c5']`.
   - Delete `e5`. `e4` still has child `c5`, so no orphan prompt.
   - Verify tree still shows `e4` and `c5`.

**Depends on:** Steps 2, 4, 5, 7.

### 9. Write widget tests for subtree (branch) deletion

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

Add test cases:

1. **Delete branch -- confirmation shows correct counts.**
   - Seed with `createCards: true`, lines `['e4', 'e5', 'Nf3']` and `['e4', 'e5', 'Bc4']`.
   - Select `e5`, tap "Delete Branch."
   - Verify the confirmation dialog shows "2 lines" and "2 review cards."

2. **Delete branch -- all descendants removed.**
   - Continue from (1), confirm.
   - Verify `e5`, `Nf3`, and `Bc4` are all gone from the tree.
   - Verify their cards are gone from the database.

3. **Delete branch -- orphan handling on parent.**
   - Seed with `createCards: true`, line `['e4', 'e5', 'Nf3']`.
   - Select `e5` (which is a non-leaf since it has child `Nf3`), tap "Delete Branch", confirm.
   - `e4` becomes childless. Verify orphan prompt appears.

4. **Delete a root node (branch) -- no orphan prompt.**
   - Seed with `createCards: true`, lines `['e4', 'e5']` and `['d4', 'd5']`.
   - Select `e4` (root), tap "Delete Branch", confirm.
   - Verify `e4` and `e5` are gone, but `d4` and `d5` remain.
   - No orphan prompt since `e4` was a root (no parent).

**Depends on:** Steps 3, 4, 5, 7.

## Risks / Open Questions

1. **Orphan prompt UX for recursive case.** When "Remove move" causes the grandparent to also become childless, should the prompt appear again for each level, or should one "Remove move" choice apply recursively up the chain? The spec says "the same choice is applied up the chain," implying automatic recursive deletion. The plan implements a loop that re-prompts at each level, which is safer (gives the user a chance to stop at any point). This could be simplified to auto-recurse if the UX feels tedious.

2. **Delete button for non-leaf nodes.** The current stub only enables Delete for leaves. The spec requires "Delete branch on any node," which means the button must also work for interior nodes. The plan changes the button to be enabled for all selected nodes, with different behavior (leaf delete vs. branch delete). This changes the existing button's enable condition, which may surprise users if they expect the button to only appear for leaves. An alternative is a separate "Delete Branch" button or a context menu. The plan uses a single button with a dynamic label.

3. **Confirmation dialog for single leaf deletion.** The spec for "Delete a Leaf" in `repertoire-browser.md` says "Requires confirmation before deletion." The spec for "Delete branch" adds the count display. For a single leaf, showing "This will delete 1 line and 1 review card" may be verbose. Consider a simpler confirmation for single leaves: "Delete this move and its review card?" vs. the full count dialog for branches. The plan uses a simple confirmation for leaves and a count-based confirmation for branches.

4. **Tree cache staleness during orphan loop.** The orphan handling loop in Step 4 queries the database (`getChildMoves`) rather than the tree cache, because the cache is stale after the initial deletion. The cache is only rebuilt once at the end (via `_loadData`). This is correct but means the orphan loop makes DB queries. This is fine for the small number of iterations expected (typically 1-3 levels).

5. **Root move deletion.** Deleting the last root move leaves the tree completely empty. The `_loadData` method already handles this (the tree widget shows "No moves yet" for an empty tree). No special handling is needed, but it should be tested.

6. **Selection state after deletion.** After deleting the selected node, the selection should be cleared (no node selected). The board could optionally navigate to the parent node, but clearing is simpler and avoids issues with deleted nodes. The plan clears the selection and rebuilds the cache.

7. **`deleteSubtree` API surface (review issue #4).** The review suggested the thin `deleteSubtree` wrapper on the repository interface is unjustified. After investigation, the wrapper would be a two-line method (look up parent, call `deleteMove`) that adds a method to both the abstract interface and the implementation for no real gain -- `deleteMove` already cascades. The plan inlines the parent lookup in a private screen helper (`_deleteMoveAndGetParent`) instead. If a broader domain need emerges later (e.g., multiple screens performing subtree deletion), this can be promoted to the repository interface at that time.

8. **SR defaults discrepancy (review issue #5).** The `line-management.md` spec says new cards have "interval 0," but the actual DB schema (`database.dart` line 36) defines `intervalDays` with `withDefault(const Constant(1))`. The plan uses `ReviewCardsCompanion.insert(...)` with only the required fields, so the DB default of `intervalDays = 1` will apply. If the spec intends `intervalDays = 0`, a separate schema migration task should be created. The plan does not change the schema.
