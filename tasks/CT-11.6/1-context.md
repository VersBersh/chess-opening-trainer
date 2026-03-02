# CT-11.6: Equal-width pills -- Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/widgets/move_pills_widget.dart` | Primary file. Contains `MovePillsWidget`, `MovePillData`, and the private `_MovePill` widget that renders each individual pill. This is where pill sizing is determined. |
| `src/lib/theme/pill_theme.dart` | `PillTheme` extension holding color tokens for saved/unsaved/focused pills. Currently has no width token. |
| `src/lib/screens/add_line_screen.dart` | Consumer of `MovePillsWidget`. Passes `state.pills` list and handles tap callbacks. No sizing logic here. |
| `src/lib/controllers/add_line_controller.dart` | Produces the `List<MovePillData>` (SAN text, isSaved, label) that feeds into the pills widget. No sizing concern. |
| `src/test/widgets/move_pills_widget_test.dart` | Widget tests for `MovePillsWidget` -- tests pill count, tap handling, styling, labels, wrapping, border radius, and fallback theme. Several tests inspect `Container` decoration and sizes; these will need updating if the Container structure changes. |
| `features/add-line.md` | Spec for the Add Line screen. States: "Equal width: All pills have the same width, regardless of the SAN text length." |
| `design/ui-guidelines.md` | Cross-cutting UI guidelines. States: "All move pills have the same width, regardless of the SAN text length (e.g., 'e4' and 'Nxd4' get the same pill width)." |

## Architecture

The pill subsystem is a straightforward stateless widget tree:

1. **Data flow:** `AddLineController` builds a `List<MovePillData>` (each entry contains a SAN string, a saved flag, and an optional label). This list is passed to `MovePillsWidget`.

2. **Layout:** `MovePillsWidget.build()` creates a `Wrap` widget with `spacing: 4` and `runSpacing: 4`. For each `MovePillData`, it instantiates a `_MovePill`.

3. **Individual pill (`_MovePill`):** Each pill is a `GestureDetector` wrapping a `Container` with `BoxDecoration` (background, border, border radius 6). The container uses **`padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)`** around a `Text` widget showing the SAN string. There is no fixed width -- the pill width is currently determined entirely by the text's intrinsic width plus padding.

4. **Labels:** When a pill has a label, the `GestureDetector`+`Container` is wrapped in a `Stack` with `Clip.none`, and a `Positioned` widget places the label text below with a negative bottom offset (-14 px). The Stack does not affect the pill's layout size in the `Wrap`.

5. **Theme:** Colors come from `PillTheme` (a `ThemeExtension`). There is a fallback path when `PillTheme` is absent that uses `ColorScheme` values. No width or size tokens exist in the theme.

**Key constraint:** The `Wrap` widget distributes children based on each child's intrinsic size. Currently, pills vary in width because the `Text` widget's natural width differs for short SANs ("e4", ~20 px) versus long SANs ("Nxd4+", ~45 px). To make pills equal width, each `_MovePill` needs an explicit fixed width (or `minWidth` constraint) so the `Wrap` allocates the same space for every pill.
