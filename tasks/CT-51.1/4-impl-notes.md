# CT-51.1: Implementation Notes

## Files Modified

- `src/lib/main.dart` — Updated both `lightTheme` and `darkTheme` `AppBarTheme` blocks: changed `backgroundColor` from `colorScheme.inversePrimary` to `colorScheme.surface`, and added `titleTextStyle` using `Typography.material2021()` to get `titleMedium` with the appropriate on-surface colour.
- `src/lib/screens/add_line_screen.dart` — Removed the local `backgroundColor: Theme.of(context).colorScheme.inversePrimary` override from the `AppBar` widget.

## Deviations from Plan

None. Implementation follows the plan exactly.

## New Tasks / Follow-up Work

None discovered.
