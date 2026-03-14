# CT-53: Context

## Relevant Files

| File | Role |
|------|------|
| `design/ui-guidelines.md` | Cross-cutting design spec; contains the "Pills & Chips" section that needs a new uniform-gap rule. |
| `features/add-line.md` | Feature spec for the Add Line screen; the "Move Pills > Display" subsection needs compact-height and gap-consistency notes. |
| `src/lib/widgets/move_pills_widget.dart` | The `MovePillsWidget` and `_MovePill` widgets. Defines pill layout constants (`_kPillWidth`, `_kPillMinTapTarget`, `_kLabelSlotHeight`), the outer `Wrap` with its spacing/runSpacing, and each pill's internal `Column` (pill body + label slot). This is the primary file to change for pill height and inter-row gaps. |
| `src/lib/screens/add_line_screen.dart` | The Add Line screen. In `_buildContent`, the `MovePillsWidget` is placed inside an `Expanded > SingleChildScrollView > Column`, directly after the board's `ConstrainedBox`. The gap between the board bottom and the first pill row is controlled by the `MovePillsWidget`'s own outer `Padding` (vertical: 4). |
| `src/lib/theme/pill_theme.dart` | `PillTheme` extension -- colour tokens for pills. Not directly changed but relevant context for the pill styling system. |
| `src/lib/theme/spacing.dart` | App-wide spacing constants (`kBannerGap`, `kBoardFrameTopGap`, `kMaxBoardSize`). May be extended with a new constant for the board-to-pill gap. |
| `src/test/widgets/move_pills_widget_test.dart` | Unit tests for `MovePillsWidget`. Contains assertions on pill height (expects 50 dp = 36 + 14), row non-overlap, and tap-target minimum (36 dp). These must be updated to match any height changes. |
| `src/test/screens/add_line_screen_test.dart` | Integration tests for the Add Line screen. May contain layout assertions affected by spacing changes. |
| `src/test/layout/board_layout_test.dart` | Cross-screen board-size consistency test. Not directly affected but useful context -- confirms the board size is fixed at `kMaxBoardSize` (300 dp). |

## Architecture

### Pill layout subsystem

The pill area on the Add Line screen is a vertical slice between the chessboard and the bottom action bar. Its structure, top to bottom:

1. **Board** -- rendered via `ConstrainedBox(maxHeight: 300) > AspectRatio(1) > ChessboardWidget`.
2. **Pill area** -- fills remaining space via `Expanded > SingleChildScrollView > Column`.
   - First child: `MovePillsWidget`, which renders a `Wrap` widget with `spacing: 4` (horizontal gap between pills) and `runSpacing: 4` (vertical gap between wrapped rows).
   - The `MovePillsWidget` applies its own outer `Padding(horizontal: 8, vertical: 4)`. This 4 dp vertical padding is the gap above the first pill row (board-to-pills gap) and below the last pill row.
3. **Bottom action bar** -- fixed at the bottom via `Scaffold.bottomNavigationBar`.

Each pill is a `Column` containing:
- `pillBody`: a `SizedBox(width: 66, height: 36)` wrapping a decorated `Container` with `padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4)`.
- `labelSlot`: a `SizedBox(width: 66, height: 14)` -- always present, empty or showing label text.

Total per-pill height: 36 (tap target) + 14 (label slot) = **50 dp**.

### Key constraints

- The pill body's `_kPillMinTapTarget = 36` determines the visible pill rectangle height. The inner `Container` has `vertical: 4` padding, so the text sits inside a box roughly 28 dp tall. The outer `SizedBox` enforces the full 36 dp.
- The `Wrap.runSpacing = 4` controls the gap between consecutive wrapped rows. The `MovePillsWidget` outer `Padding.vertical = 4` controls the gap between the board/bottom-edge and the pill rows.
- Currently, the board-to-first-pill-row gap = 4 dp (outer padding top), while the inter-row gap = 4 dp (`runSpacing`). These are numerically equal already, but the visual appearance may differ because the `Padding` top is measured from the pill area container edge (which is flush with the board bottom in the `Column` layout), while `runSpacing` is measured from one pill `Column` bottom (including the 14 dp label slot) to the next pill `Column` top. So the board-to-pills visual gap is 4 dp, but the inter-row visual gap is 4 dp of `runSpacing` which appears after the 14 dp label slot -- making the gap between the pill body of row N+1 and the pill body of row N appear as 14 + 4 = 18 dp. The gap between the board and the first pill body is only 4 dp. This is the root cause of the inconsistency.
- Tests in `move_pills_widget_test.dart` assert pill height is exactly 50 dp and tap target >= 36 dp. Any height reduction must update these assertions.
