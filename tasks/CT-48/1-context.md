# CT-48: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/widgets/move_pills_widget.dart` | The sole file to modify. Contains `MovePillsWidget`, the `_MovePill` private widget, the `MovePillData` data class, and the three layout constants (`_kLabelBottomOffset`, `_kPillWidth`, `_kPillMinTapTarget`). |
| `src/lib/theme/pill_theme.dart` | Defines `PillTheme` extension with pill color tokens. Not modified, but referenced by `_MovePill.build()` for pill background/border/text colors. |
| `src/lib/screens/add_line_screen.dart` | Consumer of `MovePillsWidget` — embeds it in a `Column` inside `SingleChildScrollView`. No changes needed, but useful for understanding how pills sit in the overall layout. |
| `src/lib/controllers/add_line_controller.dart` | Produces `AddLineState.pills` (a `List<MovePillData>`) consumed by the widget. Not modified. |
| `src/test/widgets/move_pills_widget_test.dart` | Unit tests for `MovePillsWidget`. Contains a test asserting each pill tap target is `>= 44` dp tall, which must be updated when `_kPillMinTapTarget` changes. |
| `src/test/screens/add_line_screen_test.dart` | Integration-level tests for the Add Line screen. May reference pill sizing indirectly; should be re-run to verify no regressions. |

## Architecture

`MovePillsWidget` is a stateless widget that renders chess moves as a wrapping row of tappable pills. It receives a flat `List<MovePillData>` and a focused-index from its parent (`AddLineScreen`) and owns no state.

**Layout structure (outside-in):**
1. `Padding(horizontal: 8, vertical: 4)` wraps a `Wrap` widget.
2. `Wrap` uses `spacing: 4` (horizontal gap) and `runSpacing: 4` (vertical gap between rows).
3. Each child is a `_MovePill` which produces either:
   - A bare `GestureDetector > SizedBox(h: _kPillMinTapTarget) > Center > Container(decorated)` for pills without labels, or
   - A `Stack(clipBehavior: Clip.none)` containing the above plus a `Positioned(bottom: _kLabelBottomOffset)` label text below the pill.

**Key constants:**
- `_kPillMinTapTarget = 44` sets the SizedBox height wrapping the decorated pill container. The visible pill decoration (with `vertical: 4` padding) is shorter; the remaining space is transparent hit area.
- `_kLabelBottomOffset = -4` positions the 10-sp label text below the Stack's bottom edge. Because it is negative, it paints outside the Stack bounds (enabled by `Clip.none`). But at `-4` the label partially overlaps the pill's bottom border.
- `_kPillWidth = 66` sets a fixed width for all pills.

**Label overlap problem:** The Stack's height equals `_kPillMinTapTarget` (44 dp). The visible decorated container is centered vertically within that 44 dp box, so there is roughly 10 dp of transparent padding between the bottom of the visible decoration and the bottom of the Stack. A `Positioned(bottom: -4)` places the label only 4 dp below the Stack bottom, which is still within the visual padding zone and overlaps the decoration's border. Increasing the negative offset (e.g., to `-8`) pushes the label further below, clearing the decoration.

**Wrap runSpacing consideration:** With `runSpacing: 4` and labels painting outside pill bounds, labels from one row can collide with the top of pills in the next row. When the pill height shrinks (lower `_kPillMinTapTarget`) and/or label offset increases (more negative `_kLabelBottomOffset`), `runSpacing` may need to increase to prevent collision.

**Test constraint:** The test `'each pill tap target is at least 44 dp tall'` hard-codes the `44` dp expectation. This must be updated to match the new `_kPillMinTapTarget` value.
