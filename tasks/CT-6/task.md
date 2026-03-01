---
id: CT-6
title: Theming & Polish
depends: []
specs:
  - architecture/state-management.md
files:
  - src/lib/main.dart
  - src/lib/widgets/chessboard_widget.dart
  - src/lib/screens/home_screen.dart
  - src/lib/screens/drill_screen.dart
  - src/lib/screens/repertoire_browser_screen.dart
---
# CT-6: Theming & Polish

**Epic:** none
**Depends on:** none

## Description

Visual refinement and responsive layout polish. Add board theme options (colors, piece sets), implement responsive layout for phone vs desktop, ensure consistent Material 3 styling, and add loading states and error handling throughout the app.

## Acceptance Criteria

- [ ] Board theme options (board colors, piece sets — lichess-style)
- [ ] Responsive layout: phone portrait vs desktop/tablet landscape
- [ ] Consistent Material 3 styling across all screens
- [ ] Loading states and error handling for all async operations

## Notes

The `chessground` package supports custom board colors and piece sets. Consult lichess-org's theming approach for reference. This task can be worked on incrementally alongside other tasks since it touches all screens.
