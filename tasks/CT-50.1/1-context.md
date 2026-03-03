# CT-50.1: Context

## Problem Statement

Board-based screens currently use different outer padding/top spacing, causing the chessboard to appear at inconsistent positions. This weakens spatial continuity when switching between modes.

## Relevant Specs

- `architecture/board-layout-consistency.md`
- `features/drill-mode.md`
- `features/repertoire-browser.md`
- `features/add-line.md`

## Relevant Files

| File | Why it matters |
|------|----------------|
| `src/lib/screens/drill_screen.dart` | Drill and Free Practice board layout baseline. |
| `src/lib/screens/repertoire_browser_screen.dart` | Repertoire manager board container and spacing. |
| `src/lib/screens/add_line_screen.dart` | Add Line board placement and surrounding spacing. |
| `src/lib/widgets/browser_board_panel.dart` | Shared board panel abstraction used by repertoire browser layouts. |
| `src/lib/theme/spacing.dart` | Existing spacing tokens that may host shared board-frame constants. |

## Constraints

- Preserve current feature logic and interactions.
- Avoid one-off per-screen magic numbers after the fix.
- Keep visual compatibility for small mobile widths.
