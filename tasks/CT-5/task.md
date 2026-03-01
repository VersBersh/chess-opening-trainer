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

## Context

**Specs:**
- `features/drill-mode.md` — drill session data available for summary
- `architecture/spaced-repetition.md` — quality categories (perfect/hesitation/struggled/failed)

**Source files (tentative):**
- `src/lib/screens/drill_screen.dart` — navigates to summary on session end
- `src/lib/models/review_card.dart` — DrillSession, DrillCardState models (session data source)
- `src/lib/services/sm2_scheduler.dart` — quality rating definitions

## Notes

The session summary screen is purely presentational — it receives session results and displays them. No database writes needed beyond what the drill screen already does during the session.
