---
id: CT-2.2
title: Line Entry (Edit Mode)
epic: CT-2
depends: ['CT-2.1', 'CT-1.1']
specs:
  - features/line-management.md
  - architecture/models.md
  - architecture/repository.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
  - src/lib/widgets/chessboard_widget.dart
  - src/lib/repositories/repertoire_repository.dart
  - src/lib/repositories/review_repository.dart
  - src/lib/models/repertoire.dart
---
# CT-2.2: Line Entry (Edit Mode)

**Epic:** CT-2
**Depends on:** CT-2.1, CT-1.1

## Description

Implement board-based line building, toggled from the repertoire browser. Users play moves sequentially on the board to create new lines. The system follows existing tree branches automatically and buffers only new moves. On confirm, buffered moves are saved and a review card is created for the new leaf.

## Acceptance Criteria

- [ ] Board at initial position (or navigated-to position for branching)
- [ ] User plays moves sequentially, appended to in-memory buffer
- [ ] Follow existing tree branches automatically; buffer only new moves
- [ ] Take-back button: undo last buffered move, disabled at start/branch boundary
- [ ] Flip-board toggle sets line color
- [ ] "Confirm line" button: save buffered moves, create card for new leaf
- [ ] Line parity validation on confirm (warn if orientation doesn't match leaf depth)
- [ ] Discard buffer on exit without confirm

## Notes

Edit mode may be a separate screen or a mode toggle within the repertoire browser — the implementing agent should decide based on the UI patterns established in CT-2.1.
