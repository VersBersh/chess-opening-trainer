# CT-50.1: Plan

## Goal

Make board frame position consistent across Drill/Free Practice, Repertoire Manager, and Add Line by adopting one shared spacing contract.

## Steps

1. Inspect each target screen for board container padding and top-gap values.
2. Choose a single implementation point:
   - shared constants in `spacing.dart`, or
   - shared board-frame wrapper widget.
3. Update each screen/panel to use the shared board-frame contract.
4. Verify visual consistency manually on narrow and typical phone widths.
5. Ensure no behavior changes outside layout positioning.

## Non-Goals

- No gameplay logic changes.
- No new features or screen restructuring.
- No compile/test execution as part of this planning task set.

## Risks

- Existing per-screen special cases may regress if not mapped to the shared contract.
- Browser landscape/portrait behavior might need targeted guardrails.
