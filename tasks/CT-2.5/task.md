---
id: CT-2.5
title: Line Extension
epic: CT-2
depends: ['CT-2.2']
specs:
  - features/line-management.md
  - architecture/models.md
  - architecture/spaced-repetition.md
files:
  - src/lib/screens/repertoire_browser_screen.dart
  - src/lib/repositories/repertoire_repository.dart
  - src/lib/repositories/review_repository.dart
  - src/lib/models/review_card.dart
---
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

## Notes

The undo mechanism requires temporarily holding the old card's SR state in memory. If the snackbar expires or is dismissed, the old state is discarded. This is purely in-memory — no database transactions need to be held open.
