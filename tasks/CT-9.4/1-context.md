# CT-9.4 Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/repertoire_browser_screen.dart` | Main screen file. Contains `RepertoireBrowserState`, `RepertoireBrowserScreen`, and all build methods. This is the only production file that needs to change. |
| `src/test/screens/repertoire_browser_screen_test.dart` | Widget tests for the browser screen. Already contains assertions that Edit and Focus buttons are absent (lines 461-488). May need a new test for the banner gap. |
| `design/ui-guidelines.md` | Cross-cutting design spec. Mandates a visible vertical gap between the top app bar and the first content element on every screen. |
| `features/repertoire-browser.md` | Feature spec for the Repertoire Manager. Documents the banner gap requirement and states that Edit/Focus buttons are removed. |
| `src/lib/screens/add_line_screen.dart` | Sibling screen. Useful as a reference for how the banner gap should look (CT-9.1 targets the same issue there, but has not been implemented yet either). |

## Architecture

The Repertoire Browser is a single `StatefulWidget` (`RepertoireBrowserScreen`) that manages its own state via a `RepertoireBrowserState` immutable value class and `setState`. It does not yet use Riverpod for state management (aside from the board theme provider).

### Layout structure

The `build` method creates a `Scaffold` with an `AppBar`. The body delegates to `_buildContent`, which branches into two layout paths:

- **Narrow layout** (`_buildNarrowContent`, width < 600): A single `Column` containing, in order: display-name header, chessboard, board controls, action bar, move tree.
- **Wide layout** (`_buildWideContent`, width >= 600): A `Row` with the board on the left and a `Column` (display-name header, controls, action bar, move tree) on the right.

### Banner gap issue

In the narrow layout, the `Column` starts with `_buildDisplayNameHeader` (which may be `SizedBox.shrink()` when no node is selected), followed directly by the chessboard. There is no vertical spacing between the `AppBar` bottom edge and the first visible content element. The same issue exists in the wide layout path.

### Dead-end buttons status

The Edit and Focus buttons were already removed from the screen code in commit `13c4372` (CT-7.3: "Repertoire Manager Rework -- remove edit mode, add Stats & Add Line"). The action bar currently contains only: Add Line, Import, Label, Stats, Delete. The test file already asserts that Edit and Focus buttons do not exist (two dedicated `testWidgets` at lines 461-488). No dead code related to Edit/Focus mode remains in the screen file.

### Key constraints

- The banner gap must appear in both narrow and wide layout paths.
- The gap must be visible even when `_buildDisplayNameHeader` collapses to `SizedBox.shrink()` (no node selected).
- The remaining action buttons (Add Line, Import, Label, Stats, Delete) must continue to work without regression.
