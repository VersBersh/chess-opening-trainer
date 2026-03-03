# CT-50.2: Plan

## Goal

Deliver stable, anchored filter suggestions for Free Practice that keep the input visible and choose overlay direction based on available space.

## Steps

1. Review current filter widget/overlay composition in `drill_screen.dart`.
2. Measure available viewport space above and below the input anchor.
3. Implement direction strategy:
   - open upward when lower space is insufficient,
   - open downward when lower space is sufficient.
4. Ensure suggestion overlay is anchored without covering entered text.
5. Manually verify behavior with short and long suggestion lists.

## Non-Goals

- No changes to filter matching logic.
- No redesign of drill/free-practice screen structure.
- No compile/test execution as part of this planning task set.

## Risks

- Keyboard insets and bottom controls may compete for vertical space.
- Overlay clipping can vary across platforms if anchor math is brittle.
