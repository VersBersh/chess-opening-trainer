# CT-11: Add Line UX Fixes

## Goal

Fix usability issues on the Add Line screen: take-back behavior, label editing, pill styling, and confirmation flow. These are bug fixes and UX improvements based on user feedback.

## Background

User testing revealed several issues with the Add Line screen:

1. The Label button doesn't work depending on board orientation.
2. Label editing uses a popup dialog — should be inline.
3. Take Back button doesn't work reliably, and can't undo the first move.
4. Having both X on pills and Take Back is redundant and confusing.
5. The angled label display on pills looks janky.
6. Pills with different widths look untidy.
7. The confirmation popup interrupts the flow — should be an inline warning.

## Specs

- `features/add-line.md` — updated: inline labels, equal-width pills, no X on pills, inline editing, inline confirmation
- `features/line-management.md` — updated: take-back rules, inline warnings
- `design/ui-guidelines.md` — updated: pill conventions, inline editing, inline warnings

## Tasks

- CT-11.1: Fix Label button — works regardless of board orientation
- CT-11.2: Inline label editing — no popup
- CT-11.3: Fix Take Back button and allow taking back first move
- CT-11.4: Remove X on pills
- CT-11.5: Flat label display on pills with overflow
- CT-11.6: Equal-width pills
- CT-11.7: Inline confirmation warning — no popup
