---
id: CT-5
title: Session Summary
depends: ['CT-1.3']
specs:
  - features/drill-mode.md
  - architecture/spaced-repetition.md
files:
  - src/lib/screens/drill_screen.dart
  - src/lib/models/review_card.dart
  - src/lib/services/sm2_scheduler.dart
---
# CT-5: Session Summary

**Epic:** none
**Depends on:** CT-1.3

## Description

Build a post-drill results screen shown after completing a drill session. Display statistics about the session including cards completed, mistake breakdown, duration, and next due date preview.

## Acceptance Criteria

- [ ] Cards completed count
- [ ] Mistake breakdown (perfect / hesitation / struggled / failed)
- [ ] Session duration
- [ ] Next due date preview

## Notes

The session summary screen is purely presentational — it receives session results and displays them. No database writes needed beyond what the drill screen already does during the session.
