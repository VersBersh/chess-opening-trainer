# CT-9.1: Context

## Relevant Files

### Specs

- `design/ui-guidelines.md` — Cross-cutting visual conventions. Defines the "Banner gap" rule (visible vertical spacing between banner and first content element) and the "Action button grouping" rule (related action buttons grouped tightly, centered, not spread with `spaceBetween`/`spaceEvenly`).
- `features/add-line.md` — Add Line screen feature spec. States the banner gap requirement (section "Layout") and the action button grouping requirement (buttons "grouped tightly together, not spread across the full width").

### Source files (to be modified)

- `src/lib/screens/add_line_screen.dart` — The Add Line screen widget. Contains the `_buildContent` method that arranges the display name banner, chessboard, move pills, and action bar in a `Column` with no gap between the banner and board. Contains the `_buildActionBar` method that uses `MainAxisAlignment.spaceEvenly` to spread Flip, Take Back, Confirm, and Label buttons across the full width.

### Source files (reference only)

- `src/lib/screens/repertoire_browser_screen.dart` — Repertoire browser screen. Uses the same display name banner pattern (Container with `surfaceContainerHighest` background). Its `_buildBoardControls` method uses `MainAxisAlignment.center` for a tightly grouped row of icon buttons -- this is the pattern to follow for button grouping. Also has the same banner-to-board gap issue.
- `src/lib/screens/drill_screen.dart` — Drill screen. Shows the line label banner above the board. Same pattern of no gap between banner and board.
- `src/lib/controllers/add_line_controller.dart` — Add Line controller. Not modified by this task. Manages `AddLineState` which includes `aggregateDisplayName` used for the banner.
- `src/lib/widgets/move_pills_widget.dart` — Move pills widget. Not modified by this task. Rendered between the board and the action bar.

### Test files

- `src/test/screens/add_line_screen_test.dart` — Existing widget tests for the Add Line screen.

## Architecture

### Subsystem overview

The Add Line screen (`AddLineScreen`) is a `StatefulWidget` that manages chess line entry. Its layout is built in `_buildContent` as a `Column` with four children in vertical order:

1. **Display name banner** — A `Container` with full-width `surfaceContainerHighest` background showing the aggregate display name. Conditionally rendered only when the name is non-empty.
2. **Chessboard** — A `ConstrainedBox` + `AspectRatio(1)` wrapping a `ChessboardWidget`. Maximum height 300dp.
3. **Move pills** — A `MovePillsWidget` showing the current line as tappable pills.
4. **Action bar** — A `Row` of action buttons (Flip, Take Back, Confirm, Label).

The business logic lives in `AddLineController` (a `ChangeNotifier`), which the screen listens to for state changes.

### Key constraints

- **Banner may be absent.** The display name banner is only shown when `displayName.isNotEmpty`. The gap should only appear when the banner is present.
- **Board height cap.** The chessboard is capped at `maxHeight: 300` via `ConstrainedBox`.
- **Action bar contains four buttons.** Currently: Flip (IconButton), Take Back (TextButton.icon), Confirm (TextButton.icon), Label (TextButton.icon). All four are currently spread via `spaceEvenly`.
