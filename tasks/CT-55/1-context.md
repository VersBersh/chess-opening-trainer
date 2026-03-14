# CT-55: Context

## Relevant Files

| File | Role |
|------|------|
| `features/free-practice.md` | Feature spec for Free Practice. Contains the Inline Filter section that needs a new mobile keyboard handling subsection. |
| `src/lib/screens/drill_screen.dart` | **Primary change target.** Contains `_buildDrillScaffold` (the narrow-layout Column with board + filter), `_buildFilterBox`, and `_DrillFilterAutocomplete` (the stateful autocomplete widget with the `TextField`). |
| `src/lib/controllers/drill_controller.dart` | Drill controller with `DrillConfig`, `DrillScreenState` sealed hierarchy, and filter logic (`applyFilter`, `selectedLabels`, `availableLabels`). No changes expected. |
| `src/lib/theme/spacing.dart` | Layout constants: `kMaxBoardSize = 300`, `kLineLabelHeight = 32`, `kBoardFrameTopGap = 8`. The board's `ConstrainedBox(maxHeight: kMaxBoardSize)` is the widget that should collapse/hide when the keyboard is open. |
| `src/lib/widgets/chessboard_widget.dart` | Reusable chessboard widget wrapped in `LayoutBuilder`. Not modified, but consumed by `_buildDrillScaffold`. |
| `src/test/screens/drill_filter_test.dart` | Widget tests for the filter box: visibility, label selection, autocomplete text field. New tests for keyboard-triggered layout changes go here. |
| `src/test/screens/drill_screen_test.dart` | Widget tests for the drill screen layout and interaction. May need a test verifying the board is still present when the filter is unfocused. |
| `src/test/layout/board_layout_test.dart` | Cross-screen board size consistency test. Must still pass — when the keyboard is not open, the board must render at the same size as other screens. |
| `design/ui-guidelines.md` | Global UI conventions. No changes needed, but the "no layout shifting" and "banner gap" rules inform the animation approach. |

## Architecture

### Current Narrow-Layout Structure (mobile)

`_buildDrillScaffold` returns a `Scaffold` whose body (for `screenWidth < 600`) is:

```
Scaffold
  appBar: AppBar('Free Practice — N/M')
  body: Padding(top: 8)
    Column
      ConstrainedBox(maxHeight: 300)       ← board
        AspectRatio(1:1)
          ChessboardWidget
      SizedBox(height: 32)                 ← line label area
      Padding(16)                          ← status text ("Your turn", etc.)
      Container                            ← filter box (free practice only)
        Column
          Wrap of InputChips              ← selected label chips
          _DrillFilterAutocomplete        ← TextField + RawAutocomplete overlay
```

The filter box sits at the bottom of the Column. On a typical phone (844px height), the board (300px) + app bar (~56px) + label area (32px) + status text (~48px) leaves roughly 400px for the filter. When the soft keyboard opens (~300px), the remaining visible area above the keyboard is only ~100px, which is consumed by the app bar and board. The filter input and dropdown are pushed below the keyboard fold.

### `_DrillFilterAutocomplete` Dropdown Logic

The `_computeDropdownLayout` method already reads `MediaQuery.viewInsets.bottom` to compute usable screen height and decides whether to open the dropdown upward or downward. This means the dropdown already accounts for the keyboard's presence when computing available space, but the **input field itself** is still occluded because the board is not collapsed.

### Key Constraint

The board-layout-consistency test (`board_layout_test.dart`) asserts that all screens render the chessboard at identical pixel dimensions. When the keyboard is **not** open (the normal state), the Free Practice screen must still render the board at the same `kMaxBoardSize`-constrained size. The keyboard-triggered collapse is a transient layout change that only applies while `viewInsets.bottom > 0`.
