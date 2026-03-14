# CT-54: Discovered Tasks

## 1. Label edits on saved pills without new moves have no persist path

**Suggested ID:** CT-55
**Title:** Allow persisting label-only edits on saved pills without requiring new moves
**Description:** When a user edits a label on a saved pill and there are no new (buffered) moves, the `confirmAndPersist()` method returns `ConfirmNoNewMoves` early, so pending label edits are silently lost. This is a pre-existing issue (it applies whenever a user follows an existing line and edits a label), but CT-54 makes it much more visible because users are now regularly in the "all saved pills, no new moves" state after confirm.
**Why discovered:** The consistency review flagged that post-confirm label edits on saved pills are a dead end. Investigation confirmed this is a pre-existing limitation of the deferred-label persistence model, not a regression from CT-54.

## 2. Add a "New Line" / reset button to the Add Line screen

**Suggested ID:** CT-56
**Title:** Add a "New Line" reset button to the Add Line screen
**Description:** After CT-54, if the user wants to start a completely fresh line (not branching from the current one), they must navigate away from the screen and come back. A "New Line" button that resets the builder to the starting position would be a UX improvement.
**Why discovered:** The CT-54 spec update notes that the board only resets on navigation-away or undo. A reset button was identified as a natural follow-up.
