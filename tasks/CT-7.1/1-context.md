# CT-7.1 Context

## Relevant Files

### Specs

- `features/add-line.md` -- Primary spec for the Add Line screen. Defines the Move Pills section (display, navigation via tap, deleting last pill, label display beneath pills, visual distinction between saved/unsaved pills), the overall screen layout (header, board, move pills, action buttons), and entry flow (in-memory buffer, confirm-to-save).
- `features/line-management.md` -- Defines the underlying line entry mechanics: in-memory buffer, take-back, confirm flow, branching, labeling (local segments, aggregate display name from root-to-leaf labels joined by " -- "), card creation rules. The move pills widget serves as the visual representation of the line being built.

### Source files (existing)

- `src/lib/widgets/move_tree_widget.dart` -- The existing tree-view widget. A `StatelessWidget` that receives `RepertoireTreeCache`, expanded node IDs, selected move ID, and callbacks. Renders nodes as a scrollable vertical list. The move pills widget follows the same pattern: stateless, controlled by the parent, receiving data and callbacks. The `VisibleNode` model and `buildVisibleNodes` function demonstrate the codebase's approach to separating data transformation from widget rendering.
- `src/lib/widgets/chessboard_widget.dart` -- Reusable board widget. A `StatefulWidget` that wraps `chessground`/`dartchess`. Demonstrates the codebase's widget pattern: accepts a controller, configuration props, and callbacks. Uses `LayoutBuilder` for responsive sizing. The move pills widget will be placed below this in the Add Line screen layout.
- `src/lib/widgets/chessboard_controller.dart` -- `ChangeNotifier` owning chess `Position` state. Demonstrates the controller pattern used in this codebase: parent widgets own controllers and pass them down. The move pills widget does not need a controller -- it is purely presentational and receives all data as constructor parameters.
- `src/lib/models/repertoire.dart` -- Contains `RepertoireTreeCache` with `getLine(moveId)`, `getChildren(moveId)`, `getRootMoves()`, `isLeaf(moveId)`, `getAggregateDisplayName(moveId)`, `getMoveNotation(moveId, {plyCount})`. The `getMoveNotation` method formats SAN with move numbers (e.g., "1. e4", "1...e5"). The move pills widget displays plain SAN (e.g., "e4", "e5") without move numbers, so it will NOT use `getMoveNotation`.
- `src/lib/services/line_entry_engine.dart` -- Pure business-logic service for line entry. Owns the `existingPath` (moves from root to starting node), `followedMoves` (existing tree moves the user followed), and `bufferedMoves` (new moves not yet in DB). Each `BufferedMove` has `{san, fen}`. Each `RepertoireMove` has `{id, san, fen, label, ...}`. The move pills widget needs to display a unified list of all moves in order, distinguishing which are saved (from `existingPath` + `followedMoves`) and which are unsaved (from `bufferedMoves`).
- `src/lib/repositories/local/database.dart` -- Drift schema. `RepertoireMoves` table has `san` (text), `fen` (text), `label` (text, nullable). The `label` field is what the move pills widget displays beneath a pill when present. Only moves that exist in the database (`RepertoireMove` objects) can have labels; buffered moves cannot.
- `src/lib/screens/repertoire_browser_screen.dart` -- The current repertoire browser screen. Shows the existing layout pattern: `Column` with display name header, `ChessboardWidget`, navigation controls, action bar, and `MoveTreeWidget`. The move pills widget will follow a similar placement pattern (between the board and action buttons in the Add Line screen). The screen also demonstrates the codebase's state management pattern: immutable state class with `copyWith`, `StatefulWidget` + `setState`, and `LineEntryEngine` usage during edit mode.
- `src/lib/main.dart` -- App entry point. Theme uses `ColorScheme.fromSeed(seedColor: Colors.indigo)` with Material 3. Widgets throughout the codebase use `Theme.of(context).colorScheme` for colors (e.g., `primaryContainer` for selection, `onSurface` for text, `primary` for accents). The move pills widget must follow the same theming approach.

### Test files (reference for patterns)

- `src/test/widgets/move_tree_widget_test.dart` -- Widget tests for the tree view. Contains the `buildLine` helper (builds a list of `RepertoireMove` objects from SAN sequences with correct FENs, parent linkage, and optional labels) and the `buildBranch` helper. Test structure: `buildTestApp` wraps the widget in `MaterialApp` + `Scaffold`, tests use `tester.pumpWidget`, `find.text`, `find.byType`, `find.byIcon`, and `tester.tap`. The move pills widget tests will follow the same pattern.
- `src/test/services/line_entry_engine_test.dart` -- Unit tests for LineEntryEngine. Uses the same `buildLine` helper. Tests demonstrate how to construct `RepertoireTreeCache.build(allMoves)` and exercise the engine's `acceptMove`, `takeBack`, etc.

### Source files (to be created)

- `src/lib/widgets/move_pills_widget.dart` -- The new move pills widget. A stateless widget displaying a horizontal scrollable row of tappable pills representing moves in a line.
- `src/test/widgets/move_pills_widget_test.dart` -- Widget tests for the move pills widget.

## Architecture

The move pills widget is a purely presentational Flutter widget that displays the current line as a horizontal row of tappable "pill" chips. It sits within the Add Line screen's layout hierarchy between the chessboard and the action buttons. The widget is stateless and controlled -- all state management lives in the parent screen.

### Data model

The widget needs to render a unified, ordered list of moves from two different sources:

1. **Saved moves** (`RepertoireMove` objects) -- moves that exist in the database. These come from the `LineEntryEngine`'s `existingPath` and `followedMoves` lists. Each has an `id`, `san`, `fen`, and optionally a `label`.
2. **Unsaved/buffered moves** (`BufferedMove` objects) -- moves the user has played but not yet confirmed. These come from the `LineEntryEngine`'s `bufferedMoves` list. Each has `san` and `fen` only (no `id`, no `label`).

To avoid coupling the widget to `RepertoireMove` and `BufferedMove` directly, the parent screen should transform these into a single list of a uniform "pill data" type that the widget consumes. This pill data type contains the SAN, whether the move is saved, and an optional label string.

### Widget contract

The widget receives:
- A list of pill data items (one per ply in the line)
- The index of the currently focused pill (nullable; no pill focused initially)
- A callback for when a pill is tapped (provides the tapped index)
- A callback for when the delete action is triggered on the last pill

The widget does NOT own any state, perform any data fetching, or execute delete/save logic. It is a visual display with callbacks.

### Visual structure

```
[ e4 ] [ e5 ] [ Nf3 ] [ Nc6 ] [ Bb5 ]
         ^                        ^
     saved pill             unsaved pill
   (solid style)         (dashed/dimmed)

   "Sicilian"            (no label)
 (angled label
  beneath pill)
```

- Horizontal `SingleChildScrollView` (or `ListView` with `scrollDirection: Axis.horizontal`) containing pill widgets.
- Each pill is a tappable container showing the SAN text.
- The focused pill has a distinct visual treatment (accent border/background using `colorScheme.primary` or `primaryContainer`).
- Saved pills have one visual style; unsaved pills have a different style (e.g., dashed border, reduced opacity, or different background).
- If a pill's move has a label, the label text is shown beneath the pill, angled/slanted for compact fit.
- Auto-scrolling: when a new pill is added (or focus changes), the scroll position should animate to keep the focused pill visible.

### Key constraints

- **Stateless/controlled:** The parent screen owns the list of moves, the focused index, and handles all callbacks. The widget is a pure function of its inputs.
- **Delete on last pill only:** The delete action (e.g., a small "x" icon or long-press) is only available on the last pill in the row. The widget fires a callback; the parent decides whether to call `LineEntryEngine.takeBack()` or other logic.
- **No dependency on LineEntryEngine:** The widget has no import of `line_entry_engine.dart` or `repertoire.dart`. It receives pre-processed pill data. This makes it reusable and testable in isolation.
- **Material 3 theming:** Uses `Theme.of(context).colorScheme` for all colors, following the codebase convention. No hard-coded colors.
