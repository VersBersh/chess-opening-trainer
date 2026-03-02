# CT-37: Implementation Notes

## Files Modified

- **`src/lib/screens/add_line_screen.dart`** -- Updated `_buildParityWarning()` method:
  - Changed title from `'Line parity mismatch'` to `'Lines for $currentSide should end on a $currentSide move'`
  - Simplified body text to `'Try adding one more move, or flip the board.'`
  - Replaced `colorScheme.errorContainer` with `colorScheme.tertiaryContainer`
  - Replaced all `colorScheme.onErrorContainer` (5 occurrences) with `colorScheme.onTertiaryContainer`
  - Changed icon from `Icons.warning_amber_rounded` to `Icons.info_outline`

- **`src/test/screens/add_line_screen_test.dart`** -- Updated test assertions:
  - Replaced all 13 occurrences of `find.text('Line parity mismatch')` with `find.text('Lines for White should end on a White move')`
  - Updated `triggerParityMismatchWarning` doc comment to remove "parity mismatch" from user-facing description

## Deviations from Plan

None. All steps were implemented as specified.

## Follow-up Work

None identified. The "Flip and confirm as $expectedSide" button text was already in plain language and was left unchanged per the plan.
