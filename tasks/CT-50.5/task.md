---
id: CT-50.5
title: "Scope Add Line undo feedback to route lifetime"
epic: CT-50
depends: []
specs:
  - features/add-line.md
  - architecture/state-management.md
files:
  - src/lib/screens/add_line_screen.dart
  - src/lib/controllers/add_line_controller.dart
---
# CT-50.5: Scope Add Line undo feedback to route lifetime

**Epic:** CT-50
**Depends on:** none

## Description

Investigate Add Line undo feedback behavior and implement route-scoped undo messaging so it does not linger across navigation and uses a shorter, intentional visibility window.

## Acceptance Criteria

- [ ] Undo feedback is dismissed when leaving Add Line
- [ ] Undo message duration is reduced to a short window suitable for immediate action
- [ ] Undo behavior still works while user remains on Add Line
- [ ] No cross-screen snackbars from Add Line actions

## Notes

Focus on transient UI state ownership and lifecycle, not on changing add-line save semantics.
