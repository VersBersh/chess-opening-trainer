# CT-9.3 Implementation Notes

## Files Modified

- **`src/lib/models/repertoire.dart`** — Added `countDescendantLeaves(int moveId)` method to `RepertoireTreeCache`. Reuses existing `getSubtree()` and `isLeaf()` methods to count leaf nodes in a subtree without any DB call.

- **`src/lib/screens/add_line_screen.dart`** — Two changes:
  1. Modified `_onEditLabel()` to insert a descendant leaf count check after the label dialog returns a changed result but before calling `updateLabel()`. Shows confirmation dialog when `leafCount > 1`.
  2. Added `_showMultiLineWarningDialog(int lineCount)` private method in the Dialogs section, following the identical `AlertDialog` pattern used by `_showParityWarningDialog()` and `_showDiscardDialog()`.

- **`src/test/models/repertoire_tree_cache_test.dart`** — Added `countDescendantLeaves` test group with 6 test cases: leaf node returns 1, single child leaf returns 1, two leaf children returns 2, deep branching tree returns correct count, root of multi-branch tree returns total leaves, and unknown moveId returns 0.

- **`src/test/screens/add_line_screen_test.dart`** — Added 3 widget tests:
  1. Multi-line node (2 descendant leaves): confirmation dialog appears, confirming persists the label.
  2. Multi-line node: cancelling confirmation dialog does NOT persist the label.
  3. Leaf node (1 descendant leaf): no confirmation dialog appears, label persists directly.

## Deviations from Plan

- Applied the same multi-line confirmation dialog to `repertoire_browser_screen.dart` (not in original plan) to address design review feedback about inconsistent label-edit policy across screens.

## Follow-up Work

- **Duplicate `_showLabelDialog`**: The label dialog code is duplicated between `add_line_screen.dart` and `repertoire_browser_screen.dart`. The `_showMultiLineWarningDialog` is now also duplicated. Pre-existing tech debt — consider extracting shared label-edit dialog/confirmation into a common widget.
