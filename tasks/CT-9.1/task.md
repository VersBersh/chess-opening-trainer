---
id: CT-9.1
title: Add Line — banner gap and action button grouping
epic: CT-9
depends: []
specs:
  - design/ui-guidelines.md
  - features/add-line.md
files:
  - src/lib/screens/add_line_screen.dart
---
# CT-9.1: Add Line — banner gap and action button grouping

**Epic:** CT-9
**Depends on:** none

## Description

Fix two layout issues on the Add Line screen:

1. **Banner gap:** Add vertical spacing between the "Add Line" header banner and the chessboard. The board currently sits flush against the banner.
2. **Action button grouping:** The Flip / Take Back / Confirm buttons are too spread out horizontally. Group them tightly together (centered row with minimal spacing) instead of using `MainAxisAlignment.spaceBetween` or equivalent full-width spread.

## Acceptance Criteria

- [ ] Visible vertical gap between the header banner and the board (at least 8–12dp).
- [ ] Action buttons (Flip, Take Back, Confirm) are grouped tightly in the center, not spread to the edges.
- [ ] No visual regressions on other screen elements.

## Notes

Refer to `design/ui-guidelines.md` for the general spacing and grouping conventions.
