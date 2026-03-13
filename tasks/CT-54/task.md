---
id: CT-54
title: Persist pills and board position after Add Line confirm
depends: []
specs:
  - features/add-line.md
files: []
---
# CT-54: Persist pills and board position after Add Line confirm

**Epic:** none
**Depends on:** none

## Description

Currently, after pressing Confirm on the Add Line screen, the line disappears and the board resets to the starting position. This is frustrating when adding many variations of a single line, because the user must replay the shared prefix each time.

**New behavior:** After Confirm, the pills and board position should remain as they are. The user can then:
1. See an indicator that the current line is already saved in the repertoire.
2. Click on a previous pill to navigate back to an earlier position.
3. Play a different move from that position to start a new variation (branching).
4. Confirm the new variation without having to replay the shared prefix.

This makes adding multiple variations from the same opening much faster.

### Spec updates required

**`features/add-line.md`** — The Entry Flow section currently implies the builder resets after confirm. Update to specify:
- After confirm, the pills and board position remain unchanged.
- An indicator (e.g., a visual marker on the pills, a status label, or a subtle change in pill styling) shows that the current line is already saved.
- The user can tap any previous pill to navigate to that position, then play a different move to start a new variation.
- The Confirm button returns to its disabled/"Existing line" state since all visible moves are now saved.
- The board only resets to the starting position if the user explicitly navigates away or uses a "New Line" / reset action.

Also update the Undo Feedback Lifetime section — the undo snackbar should coexist with the persistent pills (not clear them).

## Acceptance Criteria

- [ ] Update `features/add-line.md` Entry Flow to specify that pills and board persist after confirm
- [ ] Update `features/add-line.md` to specify the "already saved" indicator behavior
- [ ] Update `features/add-line.md` to specify that tapping a previous pill + playing a different move starts a new variation
- [ ] After confirm, pills remain visible and board stays at the current position
- [ ] A visual indicator shows that the displayed line is already in the repertoire
- [ ] Confirm button is disabled (shows "Existing line") since all moves are saved
- [ ] User can tap a previous pill, play a different move, and confirm the new branch
- [ ] Undo feedback does not clear the persistent pill state

## Notes

- The "already saved" indicator should be subtle — not intrusive. Options include: a different pill border/background for saved moves, a small status label below the pills, or a checkmark icon near the confirm button area.
- This change interacts with the branching behavior already specified in add-line.md. The difference is that currently branching requires the user to manually navigate; now it flows naturally from the persistent state after confirm.
- Consider whether the `_resetBuilder()` call after confirm should be removed entirely or replaced with a state transition that marks all pills as "saved" without clearing them.
