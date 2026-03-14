# CT-58: Implementation Notes

## Files modified

- **`src/lib/controllers/add_line_controller.dart`** -- Added `showHintArrows` field to `AddLineState`, `toggleHintArrows()` method, `getHintArrows()` method, and passed `showHintArrows` through all 10 state construction sites. Added imports for `dart:ui`, `chessground`, `fast_immutable_collections`, and `chess_utils`.
- **`src/lib/screens/add_line_screen.dart`** -- Added hint arrows toggle `IconButton` to app bar `actions` (hidden during loading). Passed `shapes: _controller.getHintArrows()` to `ChessboardWidget` in both narrow and wide layouts.
- **`features/add-line.md`** -- Added "Hint Arrows" section documenting the toggle, arrow display rules, colour distinction, deduplication, and behaviour.

## Files created

- **`tasks/CT-58/4-impl-notes.md`** -- This file.

## Deviations from plan

None. The implementation follows the plan exactly as specified in Steps 1-5 and Step 8. Steps 6 and 7 (tests) were already written per `3.5-test-notes.md`.

## Follow-up work

None identified. The implementation is self-contained and matches the test expectations documented in `3.5-test-notes.md`.
