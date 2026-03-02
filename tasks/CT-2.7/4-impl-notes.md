# CT-2.7 Implementation Notes

## Files Modified

| File | Summary |
|------|---------|
| `src/lib/repositories/repertoire_repository.dart` | Added `undoNewLine(List<int> insertedMoveIds)` abstract method to `RepertoireRepository` |
| `src/lib/repositories/local/local_repertoire_repository.dart` | Implemented `undoNewLine()` -- deletes first inserted move in a transaction; CASCADE handles descendants and cards |
| `src/lib/controllers/add_line_controller.dart` | Added `undoNewLine(capturedGeneration, insertedMoveIds)` method with generation-counter guard, mirroring `undoExtension()` |
| `src/lib/screens/add_line_screen.dart` | Added `else if` branch in `_handleConfirmSuccess()` for non-extension confirms; added `_showNewLineUndoSnackbar()` method |
| `src/test/screens/drill_screen_test.dart` | Added `undoNewLine` no-op stub to `FakeRepertoireRepository` |
| `src/test/screens/drill_filter_test.dart` | Added `undoNewLine` no-op stub to `FakeRepertoireRepository` |
| `src/test/screens/home_screen_test.dart` | Added `undoNewLine` no-op stub to `FakeRepertoireRepository` |
| `src/test/repositories/local_repertoire_repository_test.dart` | Added 3 tests in new `undoNewLine` group: deletes moves+card, empty list no-op, sibling branches unaffected |
| `src/test/controllers/add_line_controller_test.dart` | Added 2 tests in new `undoNewLine` group: removes moves after confirm, no-op on generation mismatch |
| `src/test/screens/add_line_screen_test.dart` | Added `pumpWithNewLine` helper and 3 widget tests: snackbar appears, undo rolls back, dismiss preserves |

## Deviations from Plan

1. **Repository test structure**: The plan's Step 5 placed the new `undoNewLine` group inside the existing `undoExtendLine` group scope. To maintain correct Dart group nesting, the `undoExtendLine` group was closed before the new `undoNewLine` group, and the remaining `sequential extend` test was moved into a new `undoExtendLine (continued)` group. The test coverage is identical.

2. **Controller test - second line confirm**: The plan suggested confirming a second line to increment the generation counter for the "no-op when generation does not match" test. The implementation uses `d4, d5` as the second line (from root, different from the first `e4, e5` line) and includes necessary board orientation flips between confirms, since `loadData()` resets the engine state.

## Follow-up Work

None identified. The implementation is complete and covers all scenarios described in the plan.
