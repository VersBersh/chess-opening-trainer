# CT-40: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/drill_screen.dart` | Main drill screen widget. Contains the `_buildDrillScaffold` method that constructs the `lineLabelWidget` (lines 182-197) and places it in the layout for both narrow (Column) and wide (Row) modes. |
| `src/lib/theme/drill_feedback_theme.dart` | ThemeExtension defining drill feedback colors (arrows, mistakes, session summary dots). Does not currently contain any line-label styling, but is the canonical location for drill-specific theme tokens. |
| `src/test/screens/drill_screen_test.dart` | Tests for the drill screen. Contains test groups "DrillScreen -- line label display" (line 910) and "DrillScreen -- line label in free practice" (line 1702) that verify label presence/absence via `ValueKey('drill-line-label')` and text finders. Also has layout-specific tests (narrow at line 1960, wide at line 2064) that check the label renders in both modes. |

## Architecture

### Drill Screen Layout

`DrillScreen` is a `ConsumerWidget` that watches `drillControllerProvider` and renders different states (loading, error, card-start, user-turn, mistake-feedback, filter-no-results, pass-complete, session-complete). Most active-drill states delegate to `_buildDrillScaffold`, which assembles the layout.

**Narrow layout** (screenWidth < 600): A `Column` containing:
1. `lineLabelWidget` (optional, above the board)
2. `boardWidget` (Expanded)
3. `statusWidget`
4. `filterWidget` (optional, free-practice only)

**Wide layout** (screenWidth >= 600): A `Row` with the board on the left and a side panel `Column` on the right containing `lineLabelWidget`, `statusWidget`, and `filterWidget`.

### Current Line Label Widget

The `lineLabelWidget` (lines 182-197) is a `Container` with:
- `ValueKey('drill-line-label')` for test identification
- Full width (`double.infinity`)
- Padding: 16px horizontal, 8px vertical
- **Colored background**: `colorScheme.surfaceContainerHighest` (a tinted surface color)
- Text style: `titleSmall` (14sp, medium weight by default in Material 3) with `onSurfaceVariant` color
- Single line with ellipsis overflow

The label text comes from the drill controller's `lineLabel` property, which is derived from move labels in the repertoire tree (assembled by `DrillEngine.getLineLabelName()`).

### Key Constraints

- The `lineLabelWidget` is conditionally null (when `lineLabel.isEmpty`), and it is inserted using Dart 3's null-aware spread (`?lineLabelWidget`) in both layouts.
- Tests check for presence/absence using `ValueKey('drill-line-label')` and text matchers, but do **not** assert precise positioning relative to the board widget.
- One test description says "shows label above board" and another says "line label appears above board in narrow layout" -- these test names reference the current position and may need updating.
