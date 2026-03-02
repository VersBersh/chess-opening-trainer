# CT-39: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/screens/drill_screen.dart` | Changed `DrillMistakeFeedback` case to set `playerSide` based on `drillState.userColor` instead of `PlayerSide.none`, making the board interactive during mistake feedback. |
| `src/lib/controllers/drill_controller.dart` | Replaced `await _revertAfterMistake(gen)` with synchronous `boardController.setPosition(_preMoveFen)` in both `WrongMove` and `SiblingLineCorrection` cases. Deleted the `_revertAfterMistake` method and its section comment entirely. |
| `src/test/screens/drill_screen_test.dart` | Added `chessground` import for `PlayerSide`. Removed 1500ms drain pump lines from 4 tests ("shows arrow on wrong move", "shows X annotation on genuine wrong move", "arrow only on sibling correction", "label persists through user turn and mistake feedback states"). Rewrote "reverts incorrect move after pause" test to verify immediate revert and `DrillMistakeFeedback` state (renamed to "reverts incorrect move immediately"). Added new test "board is interactive during mistake feedback and accepts retry" verifying `playerSide` is `PlayerSide.white` during feedback and the player can immediately play the correct move. |

## Deviations from Plan

None. All steps were implemented exactly as specified.

## Follow-up Work

None discovered during implementation. The plan's risk notes about potential board flicker on revert (risk #1) may warrant a future UX evaluation, but no code changes are needed.
