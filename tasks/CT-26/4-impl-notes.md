# CT-26 Implementation Notes

## Files Created

- **`src/lib/services/format_utils.dart`** -- New utility file with `formatDuration()` and `formatNextDue()` top-level functions extracted from `DrillScreen`.
- **`src/test/services/format_utils_test.dart`** -- Unit tests for both functions covering edge cases (zero duration, boundary at 30/31 days, past dates, cross-day edge case).

## Files Modified

- **`src/lib/screens/drill_screen.dart`** -- Added `import '../services/format_utils.dart';`, replaced `_formatDuration` and `_formatNextDue` call sites with public equivalents, deleted the two private method definitions. `_buildBreakdownRow` left in place.

## Deviations from Plan

None. All steps were followed as specified.

## Follow-up Work

None identified.
