---
id: CT-39
title: "Don't block the board after an incorrect move in drill/free training"
depends: []
files:
  - src/lib/screens/drill_screen.dart
  - src/lib/controllers/drill_controller.dart
  - src/lib/services/drill_engine.dart
  - src/lib/widgets/chessboard_controller.dart
  - src/lib/widgets/chessboard_widget.dart
---
# CT-39: Don't block the board after an incorrect move in drill/free training

**Epic:** none
**Depends on:** none

## Description

In drill mode and free training, after making an incorrect move the board is locked for 1-2 seconds while showing the correct move arrow. This feels too long, especially for ambiguous moves where the player can immediately see the arrow and wants to play the correct move right away.

Remove the board lock — let the player make another move instantly while the arrow is still displayed.

## Acceptance Criteria

- [ ] After an incorrect move, the board is not locked/blocked from input
- [ ] The correct move arrow is still shown after an incorrect move
- [ ] The player can immediately make another move while the arrow is displayed
- [ ] This applies to both drill mode and free training mode
- [ ] The arrow disappears naturally when the player makes their next move

## Notes

The board lock/delay is likely controlled in `drill_controller.dart` or `drill_screen.dart` via the `chessboard_controller.dart`. Look for timers, delays, or state flags that disable board interaction after an incorrect move.
