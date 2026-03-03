# CT-50.6: Plan

## Goal

Replace overlap-prone label placement under move pills with a robust, row-aware layout.

## Steps

1. Analyze current `move_pills_widget.dart` geometry (pill box, label box, wrap spacing).
2. Select a deterministic layout approach, such as:
   - per-pill vertical stack with reserved label slot, or
   - row item with known height budget for label/no-label variants.
3. Rework wrap spacing and child sizing so label rows do not collide.
4. Verify readability with long sequences and multiple labels on adjacent pills.
5. Confirm no regressions in pill tap targets and focus highlight behavior.

## Non-Goals

- No changes to label editing business logic.
- No changes to add-line confirmation flow.
- No compile/test execution as part of this planning task set.

## Risks

- Increasing row height to prevent overlap may reduce visible move density.
- Mixed rows (some labels, some no labels) can produce alignment drift if item heights differ.
