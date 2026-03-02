# CT-16: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/drill_screen.dart` | Source screen with wide/narrow layout branching at line 771 (`isWide = screenWidth >= 600`). Wide path: `LayoutBuilder` → `Row` (board + side panel). Narrow path: `Column` (label, board, status, filter). |
| `src/lib/screens/repertoire_browser_screen.dart` | Source screen with wide/narrow branching at line 509 (`isWide = screenWidth >= 600`). Wide: `_buildWideContent` (Row with compact action bar using `IconButton`). Narrow: `_buildNarrowContent` (Column with `TextButton.icon` labels). |
| `src/test/screens/drill_screen_test.dart` | Existing tests (~1570 lines). Uses `buildTestApp` helper with no `MediaQuery` override. Default Flutter test surface is 800×600, so tests currently exercise wide layout by accident. Narrow path is untested. |
| `src/test/screens/repertoire_browser_screen_test.dart` | Existing tests (~1440 lines). Uses `buildTestApp` helper that wraps with `MediaQuery(data: MediaQueryData(size: Size(400, 800)))`. Only narrow path tested. Wide path entirely untested. |
| `design/ui-guidelines.md` | UI design guidelines. No responsive layout rules, but documents pill wrapping and action-button grouping. |

## Architecture

Both screens use a 600px width breakpoint to switch between wide and narrow layouts:

**Drill Screen**: `_buildDrillScaffold` checks `MediaQuery.of(context).size.width >= 600`. Wide path uses `LayoutBuilder` → `Row` (board clamped to 60% width + side panel with label, status, filter). Narrow path uses `Column` (label, expanded board, status, filter). Session summary/pass-complete screens don't branch.

**Repertoire Browser**: `_buildContent` checks the same breakpoint. Wide path calls `_buildWideContent` (board left, controls right with `compact: true` action bar — `IconButton` widgets with tooltips). Narrow path calls `_buildNarrowContent` (board top, controls below with `compact: false` — `TextButton.icon` with text labels).

**Test infrastructure**: Drill tests use `FakeRepertoireRepository`/`FakeReviewRepository` via Riverpod overrides. Repertoire browser tests use real in-memory Drift database with `seedRepertoire` helper. Neither test file parameterizes viewport size.
