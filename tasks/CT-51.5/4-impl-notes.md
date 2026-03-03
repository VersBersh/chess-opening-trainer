# CT-51.5: Implementation Notes

## Files Modified

- `src/lib/screens/add_line_screen.dart` — Added `_dismissSnackBarOnNextMove` (one-shot flag) and `_prevHasNewMoves` (transition tracker) fields. Extended `_onControllerChanged` to check for the false→true `hasNewMoves` transition and call `clearSnackBars()` when the flag is armed. Armed the flag in `_handleConfirmSuccess` after showing each snackbar type.
- `src/test/screens/add_line_screen_test.dart` — Added two new `testWidgets` cases: "Line saved" and "Line extended" snackbar dismissal on first move of new line.

## Deviations from Plan

Plan Step 3 said to check the flag in `_onBoardMove`. Changed to `_onControllerChanged` instead, so the dismiss fires regardless of whether the move is driven via the widget UI or directly via `controller.onBoardMove` (as tests do). This makes the implementation testable with the existing test patterns.

## New Tasks / Follow-up

None discovered.
