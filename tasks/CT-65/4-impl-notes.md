# CT-65: Implementation Notes

## Files modified

- `src/lib/widgets/move_tree_widget.dart` -- Added `import 'dart:math';`, three private indentation constants (`_kTreeRowPaddingLeft`, `_kIndentPerLevel`, `_kMaxIndentDepth`), a public `computeTreeIndent()` top-level function, and replaced the hardcoded padding formula with a call to `computeTreeIndent(node.depth)`.
- `src/test/widgets/move_tree_widget_test.dart` -- Added `computeTreeIndent` unit tests (5 cases) and a widget test verifying indentation cap on a depth-7 tree using rendered positions.

## Deviations from plan

- Constants made private (prefixed with `_`) instead of public, per code review feedback. Tests use hardcoded expected values instead of referencing the constants.
- Widget test uses `tester.getTopLeft()` on specific row texts to verify rendered position equality (depths 5/6/7 share the same x-offset), rather than scanning Padding widgets. This is more robust against internal widget refactoring.

## Follow-up work

None discovered during implementation.
