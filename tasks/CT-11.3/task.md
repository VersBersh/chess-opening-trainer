---
id: CT-11.3
title: Fix Take Back button and allow taking back first move
epic: CT-11
depends: []
specs:
  - features/add-line.md
  - features/line-management.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/controllers/add_line_controller.dart
  - src/lib/widgets/chessboard_widget.dart
---
# CT-11.3: Fix Take Back button and allow taking back first move

**Epic:** CT-11
**Depends on:** none

## Description

Two issues with the Take Back button on the Add Line screen:

1. **Take Back doesn't work or its effect is unclear.** The button appears to do nothing when pressed. Investigate and fix the underlying issue.
2. **Can't take back the first move.** Taking back the very first move (e.g., undoing 1. e4 to return to the empty starting position) doesn't work. It should.

## Acceptance Criteria

- [ ] Take Back removes the last move from the buffer and reverts the board to the previous position
- [ ] The visual effect of Take Back is immediate and obvious (the board updates, the last pill disappears)
- [ ] Take Back works for the very first move (e.g., undoing 1. e4 returns to empty board)
- [ ] Take Back can be pressed repeatedly to undo multiple moves
- [ ] Take Back is disabled only when there are no moves to undo (at the starting position or at a branch point boundary)
- [ ] Take Back at a branch point boundary (existing saved moves) is correctly disabled

## Notes

The take-back issue may be in the ChessboardController's undo logic (CT-2.6 added undo support) or in how the Add Line screen handles the take-back action. Debug both paths.
