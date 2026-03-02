---
id: CT-34
title: "Add Line: label save breaks pills and causes ghost pieces"
depends: []
files:
  - src/lib/controllers/add_line_controller.dart
  - src/lib/screens/add_line_screen.dart
  - src/lib/widgets/chessboard_controller.dart
---
# CT-34: Add Line: label save breaks pills and causes ghost pieces

**Epic:** none
**Depends on:** none

## Description

After adding a label to a move in Add Line mode, two things break:

### Bug 1: Action pills become disabled after label save

After saving a label, the Take Back, Confirm, and Label buttons all go disabled (greyed out). The user cannot interact with any of them.

**Root cause (likely):** `updateLabel()` calls `loadData()` which rebuilds the entire state from scratch. Inside `loadData()` (add_line_controller.dart:169), `focusedPillIndex` is set to `pills.length - 1`. However, the rebuilt `LineEntryEngine` starts fresh with no buffered moves and no followed moves — only `existingPath`. If the user was mid-way through a line (e.g. they navigated to a specific pill), the fresh engine may not reconstruct the same followed-moves trail. This means:
- `hasNewMoves` → false (no buffered moves) → Confirm disabled
- `canTakeBack` → false (no buffered moves) → Take Back disabled
- `canEditLabel` requires `isSavedPillFocused && !hasNewMoves`, which should be true, but the focused pill may be in a bad state or the `_isLabelEditorVisible` flag interaction may be suppressing re-display

Investigate whether `loadData()` correctly reconstructs the followed-move trail when a label is saved mid-line, and whether the screen's `_isLabelEditorVisible` state and the controller state properly sync after the async `updateLabel` completes.

### Bug 2: Overlapping/ghost pieces on next move after label save

After saving a label, making a move on the board causes two pieces to appear overlapping on the destination square. Clicking a second time resolves the glitch.

**Root cause (likely):** `loadData()` resets `currentFen` to `startingFen` (the position at the engine's starting point, not the position the user was viewing). But the `_boardController` (ChessboardController) is never re-synced after `loadData()`. Compare with `_initAsync()` (add_line_screen.dart:69-77) which does call `_boardController.setPosition(fen)` — but this only runs at init, not after label updates.

So after label save: the `_boardController` still shows the old position (where the user was), but the controller's `preMoveFen`/`currentFen` has reset to the starting FEN. When the user makes a move, the chessground library renders the move from the board's actual position, but the controller computes the SAN/FEN from `preMoveFen` which points to a different position entirely. This mismatch causes the visual glitch.

## Reproduction Steps

1. Open Add Line mode for any repertoire
2. Play several moves to build up a line
3. Tap a saved pill to focus it
4. Tap the same pill again (or tap Label) to open the inline label editor
5. Type a label and confirm (press Enter or tap away)
6. Observe: all action buttons are now greyed out
7. Make a move on the board
8. Observe: two pieces appear overlapping on the destination square
9. Click again to resolve the visual glitch

## Acceptance Criteria

- [ ] After saving a label, action pills remain functional (Take Back, Confirm, Label are enabled/disabled correctly based on state)
- [ ] After saving a label, the board position remains synced with the controller state
- [ ] Making a move after saving a label does not produce overlapping/ghost pieces
- [ ] The focused pill index is preserved (or correctly restored) after label save
- [ ] Board controller FEN stays in sync with controller's currentFen after any loadData() call

## Notes

The core issue is that `loadData()` is a full state reset designed for initial load, but is reused after label save without re-syncing the board controller or preserving the user's navigation position. A targeted fix might:
1. Have `loadData()` (or a variant) accept the current focused position to restore after rebuild
2. Sync `_boardController.setPosition()` after any `loadData()` call in the screen
3. Or avoid calling `loadData()` for label-only changes and instead update the label in-place in the existing state
