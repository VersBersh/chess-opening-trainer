---
id: CT-7.2
title: Add Line Screen
epic: CT-7
depends: ['CT-7.1', 'CT-2.2', 'CT-2.3']
specs:
  - features/add-line.md
  - features/line-management.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/controllers/add_line_controller.dart
---
# CT-7.2: Add Line Screen

**Epic:** CT-7
**Depends on:** CT-7.1, CT-2.2, CT-2.3

## Description

Build the dedicated Add Line screen — a chessboard with move pills below it for building new repertoire lines. This screen replaces the edit mode in the current repertoire browser. It uses the move pills widget (CT-7.1) and the existing line entry mechanics from CT-2.2.

## Acceptance Criteria

- [ ] Screen displays "Add Line" header above the board
- [ ] Chessboard is interactive — user plays moves to build a line
- [ ] Move pills widget (CT-7.1) displays below the board, updating as moves are played
- [ ] Tapping a pill navigates the board to that position without removing later pills
- [ ] Aggregate display name shown in header area, updating as user moves through the line
- [ ] Confirm button saves buffered moves and creates a review card for the new leaf
- [ ] Take-back / delete-last-pill removes the last buffered move
- [ ] Flip board toggle for color selection
- [ ] Line parity validation on confirm (warns if mismatch)
- [ ] Navigating away without confirming discards the buffer
- [ ] Inline label editing: tapping a focused pill allows adding/editing the label for that position
- [ ] Branching: from a focused pill (with saved moves after it), user can play an alternative move to start a new branch
- [ ] Branching is disabled/warned when unsaved moves exist after the focused pill
- [ ] No Tree Explorer on this screen
- [ ] No Edit mode toggle — screen is always in entry mode

## Notes

This screen replaces the edit mode that was previously part of the repertoire browser. The line entry buffer logic, confirm flow, and card creation rules from CT-2.2 are reused. The main new elements are the move pills integration and the separate screen routing.
