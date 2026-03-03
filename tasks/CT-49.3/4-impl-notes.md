# CT-49.3: Existing-line info text -- Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/controllers/add_line_controller.dart` | Added `isExistingLine` computed getter in the "Computed properties" section, after `hasNewMoves`. Returns `_state.pills.isNotEmpty && !hasNewMoves`. |
| `src/lib/screens/add_line_screen.dart` | Added `_buildExistingLineInfo()` private method returning a left-aligned `Text` widget with `bodySmall` + `onSurfaceVariant` styling. Added conditional rendering in `_buildContent()` between the parity warning and action bar. |
| `src/test/controllers/add_line_controller_test.dart` | Added `group('isExistingLine', ...)` with 5 test cases: false at starting position, true when following existing moves, false when new moves buffered, true from mid-tree startingMoveId, and transition from true to false after playing a new move. |
| `src/test/screens/add_line_screen_test.dart` | Added `group('Existing line info text', ...)` with 3 widget tests: shows text when following existing line, hides text at starting position, hides text after playing a new move. |

## Deviations from Plan

None. The implementation follows the plan exactly:
- Left-aligned text as specified in the task instructions (not centered).
- `bodySmall` + `onSurfaceVariant` styling as specified.
- Horizontal padding of 16, vertical padding of 4, matching the plan.
- All 5 controller tests and 3 widget tests implemented as described.

## Follow-up Work

None identified during implementation.
