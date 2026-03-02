# CT-11.3: Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/controllers/add_line_controller.dart` | In `onTakeBack()`, replaced unconditional `boardController.setPosition(result.fen)` with three-branch logic: prefer `boardController.undo()` when `canUndo` is true (with FEN correctness guard fallback), fall back to `resetToInitial()` for initial FEN, or `setPosition()` otherwise. |
| `src/test/controllers/add_line_controller_test.dart` | Added 3 tests in the "Take-back" group: first-move take-back on empty tree, multiple take-backs with `lastMove` highlight assertions, and take-back after pill navigation (setPosition fallback path). |
| `src/test/screens/add_line_screen_test.dart` | Added 1 widget test: take-back removes last pill and restores empty state, using `Chessboard.game!.onMove` to play through the full widget pipeline. |

## Files Verified (No Changes)

| File | Summary |
|------|---------|
| `src/lib/services/line_entry_engine.dart` | Confirmed `canTakeBack()` correctly returns true for the first-move case on an empty tree. `takeBack()` returns `TakeBackResult(fen: kInitialFEN)` when all lists are empty. No code change needed. |

## Deviations from Plan

None. All six steps were implemented exactly as specified in `2-plan.md`.

## Follow-up Work

None discovered during implementation.
