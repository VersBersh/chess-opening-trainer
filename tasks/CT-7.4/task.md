---
id: CT-7.4
title: Free Practice Mode
epic: CT-7
depends: ['CT-1.3', 'CT-2.3']
specs:
  - features/free-practice.md
  - features/drill-mode.md
  - architecture/models.md
files:
  - src/lib/screens/drill_screen.dart
  - src/lib/services/drill_engine.dart
  - src/lib/screens/free_practice_setup_screen.dart
  - src/lib/repositories/review_repository.dart
---
# CT-7.4: Free Practice Mode

**Epic:** CT-7
**Depends on:** CT-1.3, CT-2.3

## Description

Implement Free Practice — an SR-exempt drill session that lets the user practice their repertoire on demand. The user can drill all cards or filter by label using an autocomplete search. This replaces the former Focus Mode (CT-4, now cancelled).

## Acceptance Criteria

- [ ] Free Practice setup screen with label autocomplete search box
- [ ] Autocomplete searches over existing position labels in the repertoire
- [ ] Multiple labels can be selected to combine variations
- [ ] "Start" with no label selection drills all cards in the repertoire
- [ ] Drill session uses `is_extra_practice = true` — no SM-2 updates
- [ ] Drill mechanics are identical to normal drill mode (intro moves, mistake handling, etc.)
- [ ] Session summary screen indicates "Free Practice" and that no SR progress was recorded
- [ ] Card filtering uses `getCardsForSubtree` for label-scoped sessions

## Notes

Free Practice reuses the drill engine and drill screen from CT-1. The key additions are: (1) the setup screen with label autocomplete, (2) the `is_extra_practice` flag to suppress SR updates, and (3) the free practice indicator on the session summary. The drill engine should accept a parameter to skip SR writes.
