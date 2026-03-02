# 1-context.md

## Relevant Files

### Specs
- `features/add-line.md` -- Primary spec for the Add Line screen. Defines move pills as the line-building interaction, their display rules, navigation (tap), and layout below the chessboard.

### Source -- Widgets
- `src/lib/widgets/move_pills_widget.dart` -- **Primary target file.** Contains `MovePillData` (the pill data model with `san`, `isSaved`, `label`), `MovePillsWidget` (the stateless parent that renders a `Wrap` of pills), and `_MovePill` (the individual pill widget with `GestureDetector`, `Container`, and optional label `Stack`). Currently has zero `Semantics` usage.
- `src/lib/theme/pill_theme.dart` -- `PillTheme` extension providing saved/unsaved/focused colour tokens. Read-only reference for understanding pill visual states.

### Source -- Controller & State
- `src/lib/controllers/add_line_controller.dart` -- `AddLineController` and `AddLineState`. Builds the `List<MovePillData>` from the engine's `existingPath`, `followedMoves`, and `bufferedMoves`. The pill list index directly corresponds to the 1-based ply count (index 0 = ply 1, index 1 = ply 2, etc.). This is the source of truth for converting pill index to move number.
- `src/lib/screens/add_line_screen.dart` -- Consumer of `MovePillsWidget`. Passes `state.pills`, `state.focusedPillIndex`, and `_onPillTapped` callback. Shows how the widget is integrated into the screen layout.

### Source -- Domain Models
- `src/lib/models/repertoire.dart` -- `RepertoireTreeCache.getMoveNotation()` contains the canonical ply-to-move-number conversion: `moveNumber = (plyCount + 1) ~/ 2`, with black moves at even ply counts. This is the pattern to reuse.

### Source -- Tests
- `src/test/widgets/move_pills_widget_test.dart` -- Existing unit tests for `MovePillsWidget`. Covers pill count, tap callbacks, styling (saved/unsaved/focused), label rendering, wrapping, fixed width, and fallback without `PillTheme`. New accessibility tests will be added here.

### Source -- Other Widgets (Accessibility Reference)
- `src/lib/screens/add_line_screen.dart` -- Uses `tooltip` on `IconButton` for "Flip board". This is the closest existing accessibility pattern in the codebase.
- `src/lib/widgets/browser_board_panel.dart` -- Uses `tooltip` on navigation `IconButton`s ("Back", "Flip board", "Forward").
- `src/lib/widgets/browser_action_bar.dart` -- Uses `tooltip` on action `IconButton`s ("Add Line", "Import", "Label", "Stats", delete).

## Architecture

The move pills subsystem is a pure presentation layer. `MovePillsWidget` is a stateless widget that receives a flat list of `MovePillData` objects and a focused index from its parent (`AddLineScreen`). Each `MovePillData` carries three fields: `san` (the SAN notation string like "Nf3"), `isSaved` (whether the move is persisted in the database), and an optional `label` (a user-assigned name like "Sicilian").

The widget iterates the pill list and renders one `_MovePill` per entry. Each `_MovePill` is a `GestureDetector` wrapping a styled `Container` with the SAN text. When the pill has a label, it is wrapped in a `Stack` with the label text positioned below.

The pill list index maps directly to ply count: index 0 is ply 1 (White's first move), index 1 is ply 2 (Black's first move), etc. The move number formula used elsewhere in the codebase is `moveNumber = (plyCount + 1) ~/ 2`, where `plyCount = index + 1`. Black moves have even ply counts.

Key constraint: `MovePillData` intentionally decouples the widget from domain models (`RepertoireMove`, `BufferedMove`) so it can be tested in isolation. Any data needed for semantic labels must either be computable from existing `MovePillData` fields plus the pill's list index, or the data model must be extended.

Currently the codebase has zero usage of Flutter's `Semantics` widget. The only accessibility pattern in use is `tooltip` on `IconButton`s.
