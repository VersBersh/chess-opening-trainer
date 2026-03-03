# CT-50.4: Plan

## Goal

Separate tree-row selection from subtree expansion with clear, mobile-usable interaction boundaries.

## Steps

1. Review current tap handler wiring in `move_tree_widget.dart`.
2. Define explicit gesture map:
   - row tap => select node,
   - chevron tap => expand/collapse.
3. Ensure chevron region has sufficient touch target without inflating row height excessively.
4. Validate callback flow through screen/controller and resulting board sync.
5. Confirm branch rows and chain-collapsed rows follow the same interaction contract.

## Non-Goals

- No change to tree data model.
- No changes to branch scoring, cards, or repository access.
- No compile/test execution as part of this planning task set.

## Risks

- Dense row layout may still produce accidental taps if hit regions overlap.
- Chain-collapsed rows may need special handling for chevron alignment.
