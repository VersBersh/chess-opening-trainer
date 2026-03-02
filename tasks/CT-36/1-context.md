# CT-36: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/widgets/move_pills_widget.dart` | Widget that renders move pills as a `Wrap` of tappable containers; owns the vertical padding (`EdgeInsets.symmetric(vertical: 6)`) on each pill's `Container`. |
| `src/lib/theme/pill_theme.dart` | `ThemeExtension<PillTheme>` defining colour tokens for saved/unsaved/focused pills; does **not** currently contain any sizing or padding tokens. |
| `src/lib/screens/add_line_screen.dart` | The only screen that instantiates `MovePillsWidget`; places it directly below the chessboard inside a `Column`. |
| `src/lib/main.dart` | Registers `PillTheme.light()` / `PillTheme.dark()` in the app's `ThemeData.extensions`. |
| `src/test/widgets/move_pills_widget_test.dart` | Unit/widget tests for `MovePillsWidget`, including layout assertions (fixed width = 66 dp, label height invariance, wrapping). |

## Architecture

The move pills subsystem is a small, self-contained presentation layer:

1. **`MovePillsWidget`** is a stateless widget that receives a flat list of `MovePillData` values (SAN text, saved/unsaved flag, optional label) plus a focused-index and a tap callback. It renders them inside a `Wrap(spacing: 4, runSpacing: 4)` wrapped in `Padding(horizontal: 8, vertical: 4)`.

2. **`_MovePill`** (private to the same file) builds an individual pill. Each pill is a fixed-width (`66 dp`) `Container` with:
   - `padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)` -- this is the primary control for vertical size.
   - `BoxDecoration` with a 6-dp border radius and a 1-or-2 px border.
   - An optional `Stack` overlay for labels positioned *below* the pill bounds (offset = -14 dp, `Clip.none`).

3. **`PillTheme`** supplies colour tokens only (saved, unsaved, focused-border, text-on-saved). It has no spacing or sizing fields today.

4. The pill is consumed exclusively by `AddLineScreen`, which places `MovePillsWidget` in a vertical `Column` between the chessboard and the action bar.

### Key Constraints

- Tap target must remain at least 44 dp (Material minimum) or ideally 48 dp.
- Labels paint outside the pill's layout bounds via `Clip.none` and a negative `Positioned.bottom`; changing pill height does not affect label positioning as long as the label offset constant is reviewed.
- Existing tests assert on the fixed 66-dp width but do not assert on pill height, so reducing vertical padding should not break them directly, though the `label does not affect pill layout height` test compares sizes and may need verification.
