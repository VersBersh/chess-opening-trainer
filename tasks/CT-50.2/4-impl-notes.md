# CT-50.2: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/screens/drill_screen.dart` | Added `_fieldKey` GlobalKey, `_computeDropdownLayout` helper method, and updated `optionsViewBuilder` to use dynamic direction and height instead of hardcoded `Alignment.topLeft` / `BoxConstraints(maxHeight: 200)`. |

## Changes Made

### `_DrillFilterAutocompleteState` in `drill_screen.dart`

1. Added `final _fieldKey = GlobalKey()` field to the state class.
2. Added two private constants: `_maxDesiredHeight = 200` and `_minUsefulHeight = 80`.
3. Added `_computeDropdownLayout(BuildContext optionsContext)` helper that:
   - Reads `MediaQuery` from the options context to get `size.height`, `viewInsets.bottom`, and `padding.bottom`.
   - Computes `usableHeight` by subtracting keyboard insets and safe-area bottom padding.
   - Looks up the render box via `_fieldKey.currentContext?.findRenderObject()` and calls `localToGlobal(Offset.zero)` to get screen-relative field position.
   - Falls back to downward/200px if the render box is unavailable.
   - Computes `spaceBelow` and `spaceAbove` relative to the field position.
   - Prefers downward when `spaceBelow >= 80`; otherwise opens upward, capping both sides to `_maxDesiredHeight`.
   - Returns a named-record `({bool openUpward, double dropdownHeight})`.
4. Added `key: _fieldKey` to the `TextField` inside `fieldViewBuilder` so the render box can be measured.
5. In `optionsViewBuilder`, called `_computeDropdownLayout(context)` once per options-open event, then:
   - Set `Align.alignment` to `Alignment.bottomLeft` when `openUpward` is true, `Alignment.topLeft` otherwise.
   - Replaced `const BoxConstraints(maxHeight: 200)` with `BoxConstraints(maxHeight: layout.dropdownHeight)`.

## Deviations from Plan

None. All steps followed as described. The `RawAutocomplete` plumbing (`optionsBuilder`, `onSelected`, controller, focus node) was left entirely unchanged.

## New Tasks / Follow-up Work

- Manual verification (plan Step 5) is required across: phone portrait with keyboard open, tablet/wide layout, active drill states, and pass-complete state.
- The `clamp(0.0, _maxDesiredHeight)` guard on the returned `dropdownHeight` is a safety measure for edge cases (e.g., field positioned above the status bar), but could be reviewed if negative space values need a different fallback.
