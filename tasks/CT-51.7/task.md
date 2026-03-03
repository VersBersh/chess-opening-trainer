---
id: CT-51.7
title: Line name banner above board displaces board (Add Line)
epic: CT-51
depends: []
specs:
  - features/add-line.md
  - architecture/board-layout-consistency.md
files: []
---
# CT-51.7: Line name banner above board displaces board (Add Line)

**Epic:** CT-51
**Depends on:** none

## Description

In the Add Line screen, a banner showing the current line name appears above the board and causes the board to shift downward as the name changes. This violates the board-layout-consistency contract, which requires the board to have a stable position.

## Acceptance Criteria

- [ ] No dynamic or variable-height content appears between the app bar and the board in the Add Line screen.
- [ ] The aggregate line name (if displayed) is shown **below** the board only, in a reserved-height slot.
- [ ] The board position is stable regardless of whether a line name is present or absent.
- [ ] Any existing banner above the board is removed or replaced with fixed-height content.

## Notes

See updated Layout section in features/add-line.md and the new constraint in architecture/board-layout-consistency.md.
