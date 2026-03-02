# CT-20.2 Implementation Notes

## Files Modified

- **`src/lib/screens/drill_screen.dart`** (lines 1150-1153) — Split the `difference <= 1` branch into `difference <= 0` returning "Today" and `difference == 1` returning "Tomorrow". This fixes the boundary bug where same-day and overdue dates were incorrectly labeled "Tomorrow".
- **`src/test/screens/drill_screen_test.dart`** (line 811) — Removed the `= "Tomorrow"` part from the comment since the exact label depends on wall-clock time and the assertion only checks for `'Next review:'`.

## Deviations from Plan

None. All three steps were followed exactly as described.

## Follow-up Work

None discovered. The plan already notes that full branch coverage of `_formatNextDue` requires clock injection (CT-27) or method extraction (CT-26).
