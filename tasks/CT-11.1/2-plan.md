# 2-plan.md — CT-11.1

## Goal

Verify and codify that the Label button on the Add Line screen is enabled regardless of board orientation when a saved pill is focused and there are no unsaved moves, by adding explicit tests and a clarifying code comment.

## Steps

1. **Add a clarifying comment in `_buildActionBar()`**
   - File: `src/lib/screens/add_line_screen.dart`
   - In `_buildActionBar()`, add or update the comment above `canEditLabel` to explicitly note the orientation independence:
     ```dart
     // Label editing is enabled when a saved pill is focused and no unsaved
     // moves exist. Board orientation is intentionally NOT a factor — labels
     // are organizational metadata independent of line color (see add-line.md).
     final canEditLabel = isSavedPillFocused && !_controller.hasNewMoves;
     ```
   - No logic change needed — the existing expression is already correct.

2. **Add a widget test — Label button remains enabled after flipping the board**
   - File: `src/test/screens/add_line_screen_test.dart`
   - Add a new test case that verifies the Label button stays enabled when the board is flipped.
   - **Preconditions**: Seed a repertoire with saved moves, navigate to a saved pill so it is focused, and ensure there are NO unsaved/buffered moves (all moves are persisted).
   - Verify Label button is enabled, flip the board, verify Label is still enabled, flip back, verify again.
   - Addresses acceptance criteria 1 and 2.

3. **Add a widget test — Full label editing flow works with board flipped to black**
   - File: `src/test/screens/add_line_screen_test.dart`
   - Add a test that completes the full label editing flow with the board flipped to black orientation: flip board, tap Label, enter text, save. Verify persistence.
   - **Preconditions**: Same as Step 2 — saved pill focused, no unsaved moves.
   - Addresses acceptance criteria 3 and 4.

## Risks / Open Questions

1. **Bug may not currently exist**: After thorough code analysis, the current `canEditLabel` logic (`isSavedPillFocused && !_controller.hasNewMoves`) does not reference board orientation in any way. The `flipBoard()` method only changes `boardOrientation` and preserves all other state. The "fix" is essentially verification that behavior is already correct, plus tests to prevent future regression and a comment to make intent explicit.

2. **Root cause ambiguity**: The task says "The root cause is likely a condition that gates label editing on the board orientation." No such condition exists in the current code. The bug may have been filed based on user testing where the label button was disabled for a different reason (e.g., `hasNewMoves` was true) and was attributed to the board flip.

3. **The `hasNewMoves` restriction is valid but may confuse users**: When a user has buffered (unsaved) moves and taps back to a saved pill, the Label button is disabled even though the focused pill is saved. This is a legitimate safeguard (because `updateLabel()` calls `loadData()` which would silently discard buffered moves), not related to orientation, but could be perceived as a bug. Out of scope for CT-11.1.

4. **Dropped controller-level test (Step 3 from original plan)**: Per review feedback, the controller-level `updateLabel` test after flip was dropped because the widget test (Step 3 here) already validates the full end-to-end flow including persistence. The controller's `flipBoard()` only modifies `boardOrientation` and does not affect pill state or move resolution, so a separate controller test adds maintenance cost without meaningful extra coverage.
