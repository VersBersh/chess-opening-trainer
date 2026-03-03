---
id: CT-50.1
title: "Standardize board frame spacing across board screens"
epic: CT-50
depends: []
specs:
  - architecture/board-layout-consistency.md
  - features/drill-mode.md
  - features/repertoire-browser.md
  - features/add-line.md
files:
  - src/lib/screens/drill_screen.dart
  - src/lib/screens/repertoire_browser_screen.dart
  - src/lib/screens/add_line_screen.dart
  - src/lib/widgets/browser_board_panel.dart
  - src/lib/theme/spacing.dart
---
# CT-50.1: Standardize board frame spacing across board screens

**Epic:** CT-50
**Depends on:** none

## Description

Investigate board placement differences across Drill/Free Practice, Repertoire Manager, and Add Line, then define and implement a shared board-frame spacing approach so boards align consistently across screens.

## Acceptance Criteria

- [ ] Shared spacing constants or a shared board wrapper are identified as the implementation target
- [ ] Board horizontal inset and top-gap behavior are consistent across the three board screens
- [ ] Spec references in this task remain aligned with implemented approach
- [ ] No feature behavior is changed besides layout consistency

## Notes

This task should implement only the board-frame consistency fix. Do not bundle unrelated visual refactors.
