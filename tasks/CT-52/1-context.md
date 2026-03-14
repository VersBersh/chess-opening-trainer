# CT-52 Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/theme/spacing.dart` | Shared layout constants: `kMaxBoardSize` (300), `kBoardFrameTopGap` (8), `kBoardFrameTopInsets`, `kLineLabelHeight` (32), `kLineLabelLeftInset` (16). The `kMaxBoardSize` constant is the primary control for board dimensions on narrow layouts. |
| `src/lib/screens/add_line_screen.dart` | Add Line screen. Uses `ConstrainedBox(maxHeight: kMaxBoardSize)` + `AspectRatio(1)` to size the board (line ~420). No explicit horizontal padding on the board itself. |
| `src/lib/screens/drill_screen.dart` | Drill and Free Practice screens. Narrow layout uses `ConstrainedBox(maxHeight: kMaxBoardSize)` + `AspectRatio(1)` (line ~275). Wide layout uses `LayoutBuilder` and sizes the board to 60% of available width. Wrapped in `Padding(kBoardFrameTopInsets)`. |
| `src/lib/widgets/browser_content.dart` | Repertoire Manager content widget. Narrow layout uses `ConstrainedBox(maxHeight: screenHeight * 0.4, clamped to kMaxBoardSize)` + `AspectRatio(1)` (line ~123). Wide layout uses `LayoutBuilder` with 50% width. Wrapped in `Padding(kBoardFrameTopInsets)`. |
| `src/lib/widgets/browser_board_panel.dart` | Extracted widgets: `BrowserChessboard` (thin board wrapper), `BrowserDisplayNameHeader` (line label below board), `BrowserBoardControls` (flip/nav buttons). No sizing logic here -- sizing is handled by parent layout. |
| `src/lib/widgets/chessboard_widget.dart` | The actual chessboard rendering widget. Receives its size from parent constraints; does not contain sizing logic. |
| `src/test/layout/board_layout_test.dart` | Widget test asserting all four board screens render the board at the same pixel dimensions, using a fixed `_phoneSize = Size(390, 844)`. Will need updating to match new responsive sizing. |
| `architecture/board-layout-consistency.md` | Spec: shared layout contract for board-based screens. Needs updating per task requirements. |
| `design/ui-guidelines.md` | Spec: global UI conventions. Needs a new board-padding guideline in the Spacing section. |
| `features/add-line.md` | Feature spec for Add Line. References board-layout-consistency contract. |
| `features/drill-mode.md` | Feature spec for Drill. References board-layout-consistency contract for horizontal padding and spacing. |
| `features/repertoire-browser.md` | Feature spec for Repertoire Manager. References board-layout-consistency contract implicitly. |

## Architecture

### Board sizing mechanism

All board-based screens (Add Line, Drill, Free Practice, Repertoire Manager) size the chessboard using the same pattern:

1. A `ConstrainedBox` with `maxHeight: kMaxBoardSize` (currently 300dp) limits the board's height.
2. An `AspectRatio(1)` widget inside makes the board square.
3. Flutter's layout engine resolves this: the board tries to fill the available width, but the `AspectRatio(1)` + `maxHeight: 300` means the board will be at most 300x300, even if the screen is wider.

On a typical phone (390dp wide), the board renders at 300x300 and is centered in the Column (default `crossAxisAlignment: center`), leaving ~45dp of unused horizontal space per side. This is the "too much padding" the task describes -- it is not explicit padding, but wasted space caused by the hard-coded size cap.

### Why the board is small

The `kMaxBoardSize = 300` constant was chosen as a safe universal cap. But on a 390dp phone, the board could safely be ~382dp (390 minus a 4dp margin on each side), gaining 27% more board area.

### Narrow vs wide layouts

- **Narrow** (width < 600dp): All screens use the `ConstrainedBox + AspectRatio` pattern. This is the layout that needs the responsive sizing fix.
- **Wide** (width >= 600dp): Drill and Browser use `LayoutBuilder` and size the board as a fraction of available width (60% and 50% respectively). These already scale with window size and are less affected, though a max-width cap may be needed to prevent absurdly large boards on ultrawide monitors.

### Consistency contract

The `board-layout-consistency.md` spec requires all board screens to render at identical dimensions. The existing test in `board_layout_test.dart` enforces this by pumping all four screens at 390x844 and comparing board sizes. Any change to board sizing must keep all screens consistent and update the test expectations accordingly.

### Key constraints

- Board must be square (AspectRatio 1:1).
- Board size must be identical across all four screens at the same viewport size.
- No dynamic content above the board (per feature specs).
- The line-label area below the board always reserves `kLineLabelHeight` (32dp).
- `kBoardFrameTopGap` (8dp) separates the app bar from the board.
