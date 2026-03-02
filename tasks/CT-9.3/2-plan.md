# CT-9.3 Plan

## Goal

Add a multi-line impact confirmation dialog to the label editing flow on the Add Line screen, shown when a label change would affect more than one line (the focused node has multiple descendant leaves in the tree).

## Steps

**Step 1: Add `countDescendantLeaves()` to `RepertoireTreeCache`**

File: `src/lib/models/repertoire.dart`

Add a new method to the `RepertoireTreeCache` class:

```dart
/// Counts the number of leaf nodes in the subtree rooted at [moveId].
/// A leaf is a node with no children. Returns 0 if [moveId] is not found.
int countDescendantLeaves(int moveId) {
  final subtree = getSubtree(moveId);
  return subtree.where((m) => isLeaf(m.id)).length;
}
```

This reuses existing `getSubtree()` and `isLeaf()` methods. The implementation traverses the subtree in memory (no DB call).

**Step 2: Add unit tests for `countDescendantLeaves()`**

File: `src/test/models/repertoire_tree_cache_test.dart`

Add a new test group with cases:
- A leaf node returns 1 (itself).
- A node with one child that is a leaf returns 1.
- A node with two children that are both leaves returns 2.
- A deep tree with branches: verify correct count (e.g., a tree with 3 leaf descendants returns 3).
- A root node of a multi-branch tree returns the total number of leaves.

Use the existing `buildLine()` helper to construct test trees with branches.

**Step 3: Add the multi-line confirmation dialog to `_onEditLabel()`**

File: `src/lib/screens/add_line_screen.dart`

Modify the `_onEditLabel()` method. After the label dialog returns a non-null, changed result, but before calling `_controller.updateLabel()`, insert a descendant leaf count check:

```dart
// After dialog returns and label is changed:
final leafCount = cache.countDescendantLeaves(move.id);
if (leafCount > 1) {
  final confirmed = await _showMultiLineWarningDialog(leafCount);
  if (confirmed != true) return;
}
await _controller.updateLabel(focusedIndex, labelToSave);
```

**Step 4: Add `_showMultiLineWarningDialog()` method**

File: `src/lib/screens/add_line_screen.dart`

Add a new private method in the `_AddLineScreenState` class, in the Dialogs section (after `_showLabelDialog`):

```dart
Future<bool?> _showMultiLineWarningDialog(int lineCount) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Label affects multiple lines'),
      content: Text('This label applies to $lineCount lines. Continue?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}
```

This follows the identical dialog pattern used elsewhere in the codebase.

**Step 5: Add widget tests for the multi-line confirmation dialog**

File: `src/test/screens/add_line_screen_test.dart`

Add test cases:
- Seed a tree where a node has 2+ descendant leaves. Navigate to that node, focus the pill. Tap Label, enter a label, press Save. Verify the confirmation dialog appears with the correct count. Confirm and verify the label was persisted.
- Same setup but cancel the confirmation dialog. Verify the label was NOT persisted.
- Seed a tree where a node is a leaf (1 descendant leaf). Focus the pill. Tap Label, enter text, save. Verify NO confirmation dialog appears and the label is persisted directly.

## Risks / Open Questions

1. **Task description mismatch**: The task says "The Label button on the Add Line screen is currently always disabled," but the code already enables it conditionally (`isSavedPillFocused && !hasNewMoves`). The label editing flow (dialog, controller method, DB persistence) is already fully implemented. The only missing piece is the multi-line confirmation dialog. The plan proceeds based on what is actually needed.

2. **Leaf count includes the node itself**: `getSubtree()` includes the root node. If the focused move is itself a leaf, `countDescendantLeaves()` will return 1 (the leaf itself), so the dialog will not be shown (since 1 is not > 1). This is correct behavior.

3. **Repertoire Browser parity**: The browser screen has a nearly identical label editing flow but no multi-line check. After this task, there will be an inconsistency. Consider tracking a follow-up task (CT-9.5 or a new task).

4. **Duplicate `_showLabelDialog`**: The label dialog code is duplicated between `add_line_screen.dart` and `repertoire_browser_screen.dart`. Pre-existing tech debt, out of scope.
