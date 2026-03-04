# CT-51.8: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/add_line_screen.dart` | **Primary change target.** Contains `_buildContent` (SingleChildScrollView body) and `_buildActionBar` (action row currently in the scrollable Column, shifting with pill count). |
| `src/lib/widgets/move_pills_widget.dart` | Renders the Wrap-based pill grid. Height grows unboundedly as pill rows wrap — root cause of the shifting action bar. |
| `src/lib/controllers/add_line_controller.dart` | Business logic; provides `canTakeBack`, `hasNewMoves`, `canEditLabel` used by the action bar. No changes needed. |
| `src/lib/theme/spacing.dart` | Spacing constants: `kBoardFrameTopGap = 8`, `kLineLabelHeight = 32`, `kLineLabelLeftInset = 16`. |
| `src/test/screens/add_line_screen_test.dart` | Widget tests; existing tests find buttons by text so they still pass after the layout move. |
| `features/add-line.md` | Feature spec mandating fixed-position action buttons, scrollable pill area, and board stability. |

## Architecture

### Current Layout (broken)

`_buildContent` returns `SingleChildScrollView > Column`. Children in order:

```
SingleChildScrollView
  Column
    [aggregate display name Container -- variable height]
    SizedBox(8dp) -- kBoardFrameTopGap
    ConstrainedBox > AspectRatio > ChessboardWidget
    MovePillsWidget (Wrap, grows unboundedly)
    [InlineLabelEditor if visible]
    [ParityWarning if active]
    [ExistingLineInfo if applicable]
    _buildActionBar()  ← SHIFTS DOWN as pills grow
```

Because `_buildActionBar` is the last child of the `Column`, its Y-position is the sum of all preceding widget heights. Each new pill row in `MovePillsWidget` pushes it further down. With 20+ moves, it scrolls off screen.

### Target Layout (fixed)

Flutter `Scaffold.bottomNavigationBar` renders any widget at a fixed bottom position, independent of the scrollable body. The body becomes a bounded `Column` with:

```
Scaffold
  appBar: AppBar('Add Line')
  bottomNavigationBar: SafeArea > _buildActionBar()  ← pinned, never scrolls
  body: Column
    [aggregate display name -- CT-51.7 will move this below board]
    SizedBox(8dp)
    ConstrainedBox > AspectRatio > ChessboardWidget  ← fixed position
    Expanded > SingleChildScrollView               ← bounded by remaining space
      Column
        MovePillsWidget
        [InlineLabelEditor]
        [ParityWarning]
        [ExistingLineInfo]
```

Key constraints from the spec:
- Board must not move regardless of pill count (board is direct child of non-scrolling Column).
- Pill area must be overflow-safe — wrapped in `Expanded > SingleChildScrollView`, bounded between board and the fixed-bottom action bar.
- Action buttons grouped tightly (centered Row, `MainAxisAlignment.center`) — already the case in `_buildActionBar`.
- `SafeArea` needed around action bar to respect iOS home indicator.
