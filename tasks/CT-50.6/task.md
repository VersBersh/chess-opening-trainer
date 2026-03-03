---
id: CT-50.6
title: "Redesign Add Line move-pill label layout to prevent overlap"
epic: CT-50
depends: []
specs:
  - features/add-line.md
files:
  - src/lib/widgets/move_pills_widget.dart
  - src/lib/screens/add_line_screen.dart
---
# CT-50.6: Redesign Add Line move-pill label layout to prevent overlap

**Epic:** CT-50
**Depends on:** none

## Description

Investigate the current move-pill label positioning strategy and replace overlap-prone relative offsets with a deterministic layout that keeps labels readable in wrapped rows.

## Acceptance Criteria

- [ ] Labels under pills do not collide with pills in the same or next wrapped row
- [ ] Label alignment is stable across varying SAN lengths and mixed labeled/unlabeled pills
- [ ] Implementation avoids fragile offset hacks as the primary layout strategy
- [ ] Pill interaction behavior (focus/tap) remains unchanged

## Notes

Prioritize readable layout under dense move sequences on small screens.
