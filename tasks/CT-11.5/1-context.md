# CT-11.5: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/widgets/move_pills_widget.dart` | Primary file to modify. Contains `MovePillData`, `MovePillsWidget`, and `_MovePill`. The label is currently rendered with `Transform.rotate(angle: -0.15)` inside a `Column` within each `_MovePill`. |
| `src/lib/theme/pill_theme.dart` | Defines `PillTheme` extension with pill color tokens (`savedColor`, `unsavedColor`, `focusedBorderColor`). No label-specific tokens exist yet. |
| `src/lib/screens/add_line_screen.dart` | Consumer of `MovePillsWidget`. Passes `state.pills` (a `List<MovePillData>`) and handles tap callbacks. Does not interact with label rendering directly. |
| `src/test/widgets/move_pills_widget_test.dart` | Tests for `MovePillsWidget`. Includes a test that labels are displayed beneath pills and a test that verifies no label appears when `label` is null. Currently asserts the presence of `Transform.rotate` for labels. |
| `features/add-line.md` | Feature spec. States labels should be shown as "flat text (not angled/slanted)" and "may overflow underneath neighboring pills." |
| `design/ui-guidelines.md` | Design spec. Under "Labels on pills": label text displayed flat beneath the pill, may overflow underneath neighbors. |
| `features/line-management.md` | Broader line management spec. Describes labeling mechanics. Not directly relevant to rendering, but provides context on label semantics. |

## Architecture

The pill rendering subsystem is a simple, self-contained widget tree:

1. **`MovePillData`** is a plain data class carrying `san`, `isSaved`, and an optional `label` string. It decouples the widget from domain models.

2. **`MovePillsWidget`** is a stateless widget that takes a list of `MovePillData`, an optional `focusedIndex`, and an `onPillTapped` callback. It renders the pills inside a `Wrap` widget (horizontal flow with wrapping) with `spacing: 4` and `runSpacing: 4`.

3. **`_MovePill`** is the internal stateless widget for a single pill. It uses a `Column(mainAxisSize: MainAxisSize.min)` containing:
   - A `GestureDetector` > `Container` (the pill body with colored background, border, and SAN text).
   - Conditionally, a `Transform.rotate(angle: -0.15)` > `Text` for the label.

4. Because each pill is a child of `Wrap`, the `Column` that contains the pill body + label participates in `Wrap`'s layout. The `Column`'s intrinsic height includes the label text height, which means a label currently **increases the pill's layout height** and can push subsequent wrap-rows downward. This is a key constraint for this task: the label must not affect the pill row layout.

5. **`PillTheme`** provides saved/unsaved/focused colors. The label currently uses `colorScheme.primary` for its color and font size 10 -- these are not theme-tokenized.

### Key Constraints

- The `Wrap` widget lays out children based on their intrinsic size. If a label is part of the child's `Column`, it increases the child's height, affecting `runSpacing` and row height. To allow labels to "overflow underneath neighboring pills" without affecting layout, the label must be painted outside the normal layout flow (e.g., using `Stack` + `Positioned`, or `OverflowBox`, or setting `clipBehavior: Clip.none`).
- The `Wrap` widget itself has `clipBehavior: Clip.hardEdge` by default, which could clip overflowing children. This may need to be set to `Clip.none`.
- The label must not cause `Wrap` to allocate additional vertical space for pills that have labels vs. those that don't.
