# CT-2.5: Line Extension

**Epic:** CT-2
**Depends on:** CT-2.2

## Description

Allow users to extend existing lines from edit mode. Navigate to a leaf, play additional moves (buffered), and on confirm: delete the old card, insert new moves, and create a new card with default SR values. Provide an undo snackbar to revert the extension within a time window.

## Acceptance Criteria

- [ ] Navigate to leaf in edit mode, play additional moves (buffered)
- [ ] On confirm: delete old card, insert new moves, create new card with default SR values
- [ ] Undo snackbar (~8 seconds): revert extension, restore old card with original SR state
- [ ] Snackbar expiry → extension is final

## Context

**Specs:**
- `features/line-management.md` — line extension flow, undo behavior, card lifecycle
- `architecture/models.md` — ReviewCard default values
- `architecture/spaced-repetition.md` — default SR values for new cards

**Source files (tentative):**
- `src/lib/screens/repertoire_browser_screen.dart` — edit mode UI (from CT-2.2)
- `src/lib/repositories/repertoire_repository.dart` — insertMove method
- `src/lib/repositories/review_repository.dart` — card deletion and creation
- `src/lib/models/review_card.dart` — ReviewCard model

## Notes

The undo mechanism requires temporarily holding the old card's SR state in memory. If the snackbar expires or is dismissed, the old state is discarded. This is purely in-memory — no database transactions need to be held open.
