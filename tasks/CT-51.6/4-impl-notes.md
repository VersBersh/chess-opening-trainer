# CT-51.6 Implementation Notes

## Files Modified

- `src/test/controllers/add_line_controller_test.dart` — Added 3 new tests:
  - **"Flip board" group**: `'flipBoard does not modify the move buffer'` — plays e4/e5/Nf3, asserts bufferedMoves.length==3 before and after two flips, and SANs are unchanged.
  - **"Parity validation" group**: `'confirmAndPersist after flip returns ConfirmParityMismatch for odd-ply line on black board'` — plays e4 (1-ply), flips to black, confirms, asserts ConfirmParityMismatch with expectedOrientation=white, buffer still has 1 move, DB empty.
  - **"Parity validation" group**: `'buffer is unchanged after confirmAndPersist returns ConfirmParityMismatch'` — plays e4/e5/Nf3, flips to black, confirms, asserts ConfirmParityMismatch, buffer still has all 3 SANs, DB empty.

- `src/test/screens/add_line_screen_test.dart` — Added 2 new integration tests in the parity warning section (after `'pill tap clears the inline warning'`):
  - `'valid white line + flip to black + confirm shows parity warning without saving'` — seeds e4/e5 (e4 labeled 'King Pawn'), follows both, buffers Nf3, flips to black, confirms; asserts "Lines for Black should end on a Black move" visible, no AlertDialog, Nf3 not in DB.
  - `'pills show full original line after dismissing parity warning triggered by flip+confirm'` — same setup; after parity warning appears, dismisses with X button, asserts warning gone, all 3 pills (e4/e5/Nf3) still visible, Nf3 not in DB.

- `src/lib/controllers/add_line_controller.dart` — Added defensive parity re-check inside `flipAndConfirm()` (Step 6): after the orientation flip and `notifyListeners()`, calls `engine.validateParity(_state.boardOrientation)` and returns `ConfirmParityMismatch` if the flip somehow did not resolve the mismatch.

- `src/lib/screens/add_line_screen.dart` — Updated `_onFlipAndConfirm()` (Step 7): added `else if (result is ConfirmParityMismatch)` branch that sets `_parityWarning = result.mismatch`, so the UI displays the inline warning if the defensive guard in `flipAndConfirm()` fires.

## Deviations from the Plan

- **Steps 4 and 5 (screen tests)**: Per the reviewer's note, the tests use `labelsOnSan: {'e4': 'King Pawn'}` with a seeded `e4, e5` line so that `hasLineLabel = true` and the no-name dialog is bypassed. This required using a 3-ply scenario (follow e4, follow e5, buffer Nf3) rather than the plan's described "1-ply" setup. The 3-ply approach still tests the core invariant — odd-ply line + black board = parity mismatch — while avoiding no-name dialog complexity.

- **Parity warning message**: The plan comments contained some uncertainty about the warning text. The actual message comes from `_buildParityWarning` in `add_line_screen.dart` and uses `$currentSide` (the board's current orientation), not `expectedOrientation`. With board flipped to black, the message is `"Lines for Black should end on a Black move"`, which is what the screen tests assert.

## New Tasks / Follow-up Work

- None discovered. The production code (`confirmAndPersist`) was already reading `_state.boardOrientation` correctly after `flipBoard()`, so Steps 2-4 tests should pass without any production fix beyond Steps 6-7.
