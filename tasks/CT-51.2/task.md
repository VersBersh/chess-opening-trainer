---
id: CT-51.2
title: Castling not executable by hand in Repertoire Manager
epic: CT-51
depends: []
specs:
  - features/repertoire-browser.md
files: []
---
# CT-51.2: Castling not executable by hand in Repertoire Manager

**Epic:** CT-51
**Depends on:** none

## Description

In the Repertoire Manager, when a position has a castling move in the repertoire, the arrow hint for that move is shown but the user cannot execute castling by dragging or tapping on the board. Navigation via the forward button still works. This is a board-interaction bug: the move recognition does not handle castling gestures correctly.

## Acceptance Criteria

- [ ] The user can castle by hand (drag king two squares, or tap king then target square) in the Repertoire Manager when castling is a valid repertoire move from the current position.
- [ ] The castle move navigates the tree to the correct child node, the same as pressing the forward button.
- [ ] No regression in other board-interaction move types (normal moves, promotions, en passant).

## Notes

Root cause is likely that the board widget's move-detection does not normalise castling gestures into the correct move representation before looking up the child node in the tree cache. See updated spec in features/repertoire-browser.md.
