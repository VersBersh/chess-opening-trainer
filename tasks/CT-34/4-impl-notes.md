# CT-34: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/controllers/add_line_controller.dart` | Rewrote `updateLabel()` to preserve navigation state (focusedPillIndex, currentFen, preMoveFen, boardOrientation) instead of calling `loadData()`. Added `hasNewMoves` early-return guard. Added `canEditLabel` getter. |
| `src/lib/screens/add_line_screen.dart` | Added board sync (`setPosition`/`resetToInitial`) after `_controller.updateLabel()` in the `onSave` callback, matching the pattern used by `_handleConfirmSuccess()`. Updated stale comment in `_buildActionBar`. |
| `src/test/controllers/add_line_controller_test.dart` | Added 4 unit tests to the `Label update` group: (a) preserves focusedPillIndex and currentFen, (b) does not break subsequent branching, (c) preserves pills when starting from root, (d) is a no-op when hasNewMoves is true. |
| `src/test/screens/add_line_screen_test.dart` | Added screen test "board FEN and pills preserved after label save" verifying pills, board FEN, button states, DB persistence, and post-save board functionality. |

## Files Created

| File | Summary |
|------|---------|
| `tasks/CT-34/4-impl-notes.md` | This file. |

## Deviations from Plan

1. **Added `canEditLabel` getter to controller**: The plan did not call for this, but the screen already computed `canEditLabel` locally in `_buildActionBar`. I added a matching getter on the controller so the guard logic is colocated with `updateLabel()`. The screen still uses its own local computation (unchanged behavior), so this is a non-breaking addition for potential future consolidation.

2. **Updated stale comment in `_buildActionBar`**: The comment referenced "updateLabel() calls loadData() which would drop buffered moves" which is no longer accurate after the fix. Updated to remove the stale reference.

3. **Screen test uses `chessboard.fen` instead of `chessboard.data.fen`**: The plan referenced `tester.widget<Chessboard>(find.byType(Chessboard)).fen`. The chessground `Chessboard` widget exposes `fen` as a direct field (not via a `data` accessor), matching existing test patterns (e.g., line 431 of the screen test file).

## Follow-up Work

None identified. The implementation covers all four plan steps. The `canEditLabel` getter on the controller is unused by the screen currently (which computes it locally) but could be used in a future cleanup to consolidate the logic.
