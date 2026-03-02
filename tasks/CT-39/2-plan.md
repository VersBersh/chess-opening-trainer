# CT-39: Implementation Plan

## Goal

Remove the board lock after an incorrect move so the player can immediately retry while the correction arrow is still displayed.

## Steps

1. **Change `DrillMistakeFeedback` rendering to allow interaction** in `src/lib/screens/drill_screen.dart`.
   - In the `DrillMistakeFeedback` case of `_buildForState` (line 141), change `playerSide: PlayerSide.none` to use `drillState.userColor` to derive the correct `PlayerSide` (matching the `DrillUserTurn` pattern at lines 122-124):
     ```dart
     playerSide: drillState.userColor == Side.white
         ? PlayerSide.white
         : PlayerSide.black,
     ```
   - This makes the board interactive during mistake feedback.

2. **Replace the delayed revert with an immediate revert** in `src/lib/controllers/drill_controller.dart`.
   - In the `WrongMove` case (around line 366): replace `await _revertAfterMistake(gen)` with `boardController.setPosition(_preMoveFen)`.
   - In the `SiblingLineCorrection` case (around line 380): replace `await _revertAfterMistake(gen)` with `boardController.setPosition(_preMoveFen)`.
   - **Critical:** Keep `boardController.setPosition(_preMoveFen)` **outside** the `if (expectedMove != null)` block — matching the current placement of `_revertAfterMistake(gen)` which is already outside that `if`. This ensures the board is always reverted even if `sanToMove` fails to parse the expected move.
   - Do NOT emit `DrillUserTurn` after the revert (unlike `_revertAfterMistake` which did). The state stays `DrillMistakeFeedback` so the arrow/shapes remain visible.
   - Remove the `_preMoveFen = boardController.fen` line that was in `_revertAfterMistake` — after `setPosition(_preMoveFen)`, re-reading the FEN is redundant since it was just set to `_preMoveFen`.
   - Depends on: Step 1.

3. **Delete the `_revertAfterMistake` method** in `src/lib/controllers/drill_controller.dart` (lines 386-399).
   - Remove the entire method and the `// ---- Mistake revert timing` comment section since it is no longer called.
   - Depends on: Step 2.

4. **Verify next-move handling during `DrillMistakeFeedback` state** — no code changes needed.
   - `processUserMove` reads `_preMoveFen`, derives SAN, and calls `_engine.submitMove()`. Since the board was reverted to `_preMoveFen` in step 2, and `_engine`'s `currentMoveIndex` was not advanced (wrong moves do not advance the index), the next call works correctly.
   - When the user makes a correct move from `DrillMistakeFeedback`, the state transitions to `DrillUserTurn` (or line complete), which does not supply `shapes` or `annotations` — so the arrow disappears naturally.

5. **Update existing tests** in `src/test/screens/drill_screen_test.dart`.
   - **"shows arrow on wrong move" test (~line 431):** Remove the `await tester.pump(const Duration(milliseconds: 2000))` drain line (the 1500ms timer no longer exists).
   - **"shows X annotation on genuine wrong move" test (~line 466):** Same — remove the drain line.
   - **"arrow only on sibling correction" test (~line 532):** Same — remove the drain line.
   - **"reverts incorrect move after pause" test (~line 539):** Rewrite to test the new behavior: after a wrong move and a single `tester.pump()`, the board should already be reverted to the pre-mistake FEN, and the state should be `DrillMistakeFeedback` (not `DrillUserTurn` — the old behavior was to transition to `DrillUserTurn` after the delay).
   - **"label persists through user turn and mistake feedback states" test (~line 947):** Remove the `// Drain the pending 1500ms revert timer` pump at the end.

6. **Add a new test: player can make another move immediately after mistake** in `src/test/screens/drill_screen_test.dart`.
   - Play a wrong move, pump, verify `DrillMistakeFeedback`.
   - Verify the `ChessboardWidget` has `playerSide` set to the user's color (not `PlayerSide.none`), confirming the board is interactive during mistake feedback. This directly tests the UI gating, not just the controller state.
   - Without any additional delay, play the correct move. Pump and verify the state advances (either to next `DrillUserTurn` or line completion).
   - This addresses the review concern that tests bypassing `ChessboardWidget` interaction gating could miss a locked board.

## Risks / Open Questions

1. **Board flicker on revert.** When the user plays a wrong move, `ChessboardWidget._onUserMove` calls `controller.playMove(move)` which visually moves the piece. Then `processUserMove` immediately calls `boardController.setPosition(_preMoveFen)` to revert. This could cause a brief visual flicker. Likely acceptable since the arrow and X marker provide clear feedback. If jarring, `boardController.undo()` could be used instead for smoother animation.

2. **Rapid incorrect moves.** If the user rapidly makes multiple incorrect moves while in `DrillMistakeFeedback` state, each call re-emits `DrillMistakeFeedback` with the same `expectedMove`. The engine increments `mistakeCount` on each `WrongMove`. No race condition since there are no timers to conflict.

3. **`_preMoveFen` integrity.** After reverting, `_preMoveFen` remains unchanged. `processUserMove` only updates `_preMoveFen` on `CorrectMove`, not on wrong moves. Correct behavior.

4. **Free training vs. drill mode.** Both modes use the same `DrillController` and `DrillScreen` code paths. Changes apply uniformly, satisfying both acceptance criteria.

5. **Review issue: revert placement.** Per plan review, `boardController.setPosition(_preMoveFen)` must remain outside the `if (expectedMove != null)` block to handle the edge case where `sanToMove` returns null. This matches the current code structure where `_revertAfterMistake` is outside the `if`.
