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

## Context

**Specs:**
- `architecture/state-management.md` — state management patterns for loading/error states

**Source files (tentative):**
- `src/lib/main.dart` — theme configuration
- `src/lib/widgets/chessboard_widget.dart` — board theme integration
- `src/lib/screens/home_screen.dart` — responsive layout
- `src/lib/screens/drill_screen.dart` — responsive layout
- `src/lib/screens/repertoire_browser_screen.dart` — responsive layout

## Notes

The `chessground` package supports custom board colors and piece sets. Consult lichess-org's theming approach for reference. This task can be worked on incrementally alongside other tasks since it touches all screens.
