# CT-9.2 Implementation Notes

## Files Created

- **`src/lib/theme/pill_theme.dart`** -- New `ThemeExtension<PillTheme>` class with `savedColor`, `unsavedColor`, and `focusedBorderColor` tokens. Includes `copyWith` and `lerp` implementations.

## Files Modified

- **`src/lib/main.dart`** -- Added `import 'theme/pill_theme.dart'` and registered a `PillTheme` instance in `ThemeData.extensions` with blue color values (`savedColor: 0xFF5B8FDB`, `unsavedColor: 0xFFB0CBF0`, `focusedBorderColor: 0xFF1A56A8`).

- **`src/lib/widgets/move_pills_widget.dart`** -- Three changes:
  1. Color logic in `_MovePill.build` now reads from `PillTheme` extension with a full fallback to the original `colorScheme`-based colours when the extension is absent.
  2. Border radius changed from `BorderRadius.circular(16)` to `BorderRadius.circular(6)`.
  3. `MovePillsWidget.build` layout changed from `SizedBox(height: 56) > SingleChildScrollView > Row` with per-pill `Padding` to `Padding > Wrap(spacing: 4, runSpacing: 4)`. Empty state height changed from 56 to 48.

- **`src/lib/screens/add_line_screen.dart`** -- Wrapped the `Column` in `_buildContent` with a `SingleChildScrollView` to handle dynamic pill height from wrapping.

- **`src/test/widgets/move_pills_widget_test.dart`** -- Updated `buildTestApp` to include `PillTheme` in `ThemeData.extensions` (with `includePillTheme` flag for fallback testing). Updated color assertions in three existing tests to use `PillTheme` tokens instead of `colorScheme` tokens. Changed empty-state assertion from `SingleChildScrollView` to `Wrap`. Added three new tests:
  - `'pills wrap onto multiple lines'` -- Verifies `Wrap` is present and last pill is vertically below first pill in a narrow container.
  - `'border radius is reduced'` -- Asserts `BorderRadius.circular(6)` on pill `BoxDecoration`.
  - `'renders without PillTheme extension (fallback)'` -- Builds widget without the extension and verifies it renders correctly using `colorScheme` fallback colours.

## Deviations from Plan

- None. All seven steps were implemented as specified.

## Follow-up Work

- **Visual tuning of blue shades.** The hex values for `savedColor`, `unsavedColor`, and `focusedBorderColor` are estimates from the plan. They should be verified on a real device/emulator for contrast and aesthetics. Adjustments only require changing the three values in `main.dart`.
- **WCAG contrast check.** White text on `0xFF5B8FDB` (saved pill) should be checked for WCAG AA compliance (4.5:1 contrast ratio). If the blue is too light, either darken the blue or use a darker text colour.
- **`add_line_screen_test.dart` does not include `PillTheme`.** The test helper builds a `MaterialApp` without a custom `ThemeData`, so `MovePillsWidget` uses the fallback path. This is intentional and exercised by the new fallback test, but if future tests in that file assert pill colours, the helper would need updating.
- **CT-9.1 interaction.** If CT-9.1 also wraps the Add Line screen body in a `SingleChildScrollView`, the two changes will need to be reconciled (only one scroll wrapper is needed).
