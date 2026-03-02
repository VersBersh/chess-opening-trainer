# CT-9.2 Context

## Relevant Files

### Specs

- `design/ui-guidelines.md` -- Cross-cutting visual conventions. Defines pill styling: blue fill by default, modest border radius (not stadium/capsule), wrapping pill rows (never clip or scroll off-screen). Pill color must be a named theme token (e.g., `pillColor`) for global adjustment.
- `features/add-line.md` -- Add Line screen spec. Section "Move Pills > Display" specifies: pills use blue fill, modest border radius, and wrapping layout. Saved vs. unsaved pills are visually distinct. Focused pill is visually highlighted.

### Source files (to be modified)

- `src/lib/widgets/move_pills_widget.dart` -- The move pills widget. Contains `MovePillData` (pill data model), `MovePillsWidget` (stateless, renders pills in a horizontal `SingleChildScrollView` > `Row`), and `_MovePill` (individual pill with `Container` + `BoxDecoration`). Currently uses `BorderRadius.circular(16)` (near-stadium shape), and colors are drawn from `Theme.of(context).colorScheme` with a 4-way matrix of saved/unsaved x focused/unfocused states using `primaryContainer`, `surfaceContainerHighest`, `tertiaryContainer`, and their corresponding text/border colors. The outer widget has a fixed `SizedBox(height: 56)` and horizontal scrolling.
- `src/lib/main.dart` -- App entry point. Defines the global `ThemeData` with `ColorScheme.fromSeed(seedColor: Colors.indigo)` and `useMaterial3: true`. Currently has no `ThemeExtension` or custom theme tokens. This is where the pill color theme token would be registered.
- `src/lib/screens/add_line_screen.dart` -- The Add Line screen. Uses `MovePillsWidget` inside a `Column` (no scrolling wrapper on the outer Column). The pills sit between the chessboard and the action bar. After switching pills to a wrapping layout, the outer Column may need to become scrollable if pills + action buttons exceed the viewport height.

### Source files (reference only)

- `src/lib/theme/board_theme.dart` -- Board theme provider (chessground board colors and piece sets). Uses `enum` + Riverpod `Notifier` pattern. Reference for how the codebase handles theme-adjacent configuration; however, this is specific to the chessboard library and does not use Flutter's `ThemeExtension` mechanism.
- `src/lib/screens/repertoire_browser_screen.dart` -- Repertoire browser. Does not use `MovePillsWidget` (uses `MoveTreeWidget` instead). Included for awareness: any pill styling changes are isolated to the move pills widget and the add-line screen.

### Test files (to be modified)

- `src/test/widgets/move_pills_widget_test.dart` -- Widget tests for `MovePillsWidget`. Tests pill rendering, tap callbacks, delete icon visibility, and visual styling assertions (checks `BoxDecoration.color` against specific `ColorScheme` tokens like `primaryContainer` and `tertiaryContainer`, and checks `Border` colors against `outline`/`outlineVariant`). These assertions will break when pill colors change from the current scheme-derived values to the new blue-based colors. Also tests for `SingleChildScrollView` absence on empty state -- this finder will break when the scroll view is removed in favor of `Wrap`. The test harness uses `buildTestApp` with `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo))`.
- `src/test/screens/add_line_screen_test.dart` -- Integration tests for the Add Line screen. Does not directly assert pill colors or layout, but does verify `MovePillsWidget` is rendered. Should continue to pass without modification, but worth verifying after the wrapping/scrollability change.

## Architecture

### Subsystem overview

The move pills widget is a presentation-only component that renders a row of tappable move pills below the chessboard on the Add Line screen. It is stateless: all data (pill list, focused index) and callbacks (tap, delete) are passed in from the parent screen's controller.

### Component relationships

```
AddLineScreen (StatefulWidget)
  |-- AddLineController (ChangeNotifier, owns state)
  |     |-- state.pills: List<MovePillData>
  |     |-- state.focusedPillIndex: int?
  |
  |-- build() -> Column
        |-- [display name banner]
        |-- ChessboardWidget
        |-- MovePillsWidget(pills, focusedIndex, onPillTapped, onDeleteLast)
        |-- [action bar]
```

The `MovePillsWidget` receives `List<MovePillData>` and renders each as a `_MovePill`. Each pill is a `Container` with `BoxDecoration` (color, border radius, border) wrapping a `Row` of `GestureDetector`s (SAN text tap target + optional delete icon). Labels are rendered below the pill as rotated `Text`.

### Current styling logic

The `_MovePill.build` method determines colors via a 4-way matrix:

| State                    | Background                      | Border                    |
|--------------------------|---------------------------------|---------------------------|
| Saved + Focused          | `colorScheme.primaryContainer`  | `colorScheme.primary`     |
| Saved + Unfocused        | `colorScheme.surfaceContainerHighest` | `colorScheme.outline` |
| Unsaved + Focused        | `colorScheme.tertiaryContainer` | `colorScheme.tertiary`    |
| Unsaved + Unfocused      | `colorScheme.surfaceContainerHighest` | `colorScheme.outlineVariant` |

Border radius is `BorderRadius.circular(16)` (near-stadium for small pills).

### Current layout

The pill row is a `SizedBox(height: 56)` containing `SingleChildScrollView(scrollDirection: Axis.horizontal)` > `Row`. This gives a single fixed-height scrollable row. The outer `AddLineScreen._buildContent` returns a `Column` (no scroll wrapper), which means if the pills section grows vertically (after switching to `Wrap`), the screen content may overflow.

### Key constraints

- **Theme token pattern:** The codebase currently uses `ColorScheme.fromSeed(seedColor: Colors.indigo)` with no custom `ThemeExtension`. Introducing a pill color theme token requires either: (a) adding a `ThemeExtension` subclass and registering it in `ThemeData.extensions`, or (b) adding a top-level constant/static that is referenced by both the widget and tests. Option (a) is the idiomatic Flutter approach and allows per-theme overrides.
- **Saved vs. unsaved distinction must remain.** The task requires that saved and unsaved pills remain visually distinguishable even after switching to a blue base color. This means unsaved pills need a different shade, opacity, or border treatment.
- **Focused pill must remain distinct.** The focused pill needs a highlight that is visible on top of the blue base. A thicker/brighter border or a lighter/darker shade of blue are both viable.
- **Wrapping affects vertical space.** Switching from a fixed-height horizontal scroll to a `Wrap` means the pills section has dynamic height. The Add Line screen's outer `Column` must handle this gracefully, likely by wrapping the entire body in a `SingleChildScrollView` or making the pills section part of an `Expanded` + scroll combination.
- **Test assertions on colors will break.** Several tests in `move_pills_widget_test.dart` assert specific `ColorScheme` token values (e.g., `colorScheme.primaryContainer`). These need to be updated to match the new blue-based color scheme. The test for `SingleChildScrollView` absence on empty state also needs updating.
