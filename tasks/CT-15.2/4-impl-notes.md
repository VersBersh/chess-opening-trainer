# CT-15.2: Implementation Notes

## Files Modified

- **`src/lib/screens/add_line_screen.dart`** -- Added `@visibleForTesting controllerOverride` parameter to `AddLineScreen` constructor. Added `_ownsController` flag to `_AddLineScreenState` to conditionally dispose the controller only when the screen created it. Added `import 'package:flutter/foundation.dart' show visibleForTesting;`.

- **`src/test/screens/add_line_screen_test.dart`** -- Added imports for `AddLineController`, `LocalReviewRepository`, and `ChessboardController`. Added `sanToNormalMove` helper (copied from controller test file). Updated `buildTestApp` to accept optional `AddLineController` parameter. Added `pumpWithExtendingMove` helper that seeds DB, pumps widget, plays extending move after settle, flips board for parity, and returns controller/testBoard/repId record. Added three new widget tests:
  1. `extension undo snackbar appears after confirming extension`
  2. `undo action on extension snackbar rolls back the extension`
  3. `extension persists after snackbar dismissed without undo`

## Deviations from Plan

- Removed unnecessary `import 'package:flutter/foundation.dart'` (already re-exported by `package:flutter/material.dart`).
- Renamed timeout test to "extension persists after snackbar dismissed without undo" because the SnackBar auto-dismiss Timer is created in the root zone (due to Drift async I/O resolving outside the FakeAsync zone), making timer-based dismissal untestable via `pump()`. The test instead verifies the duration property (8 seconds) and manually dismisses.
- Moved controller/board disposal into `pumpWithExtendingMove` helper (via `addTearDown`) to eliminate temporal coupling noted in code review.

## Follow-up Work

- The `sanToNormalMove` helper is now duplicated between `add_line_controller_test.dart` and `add_line_screen_test.dart`. A future task could extract it to a shared test utility file (e.g., `src/test/helpers/chess_test_utils.dart`).
- Similarly, `seedRepertoire`, `getMoveIdBySan`, and `createTestDatabase` helpers are duplicated between the two test files. These could also be extracted to a shared location.
