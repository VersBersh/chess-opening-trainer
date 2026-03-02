# CT-2.8 Implementation Notes

## Files Modified

- **`src/pubspec.yaml`** — Moved `sqlite3: ^3.1.6` from `dev_dependencies` to `dependencies` so `SqliteException` can be imported in production code.
- **`src/lib/repositories/repertoire_repository.dart`** — Added `saveBranch()` method signature to the abstract `RepertoireRepository` interface (accepts only `parentMoveId` + `newMoves`, creates review card internally).
- **`src/lib/repositories/local/local_repertoire_repository.dart`** — Implemented `saveBranch()` using `_db.transaction()` to atomically insert moves and create a review card (mirrors `extendLine()` pattern). Added `assert(newMoves.isNotEmpty)`.
- **`src/lib/controllers/add_line_controller.dart`** — Added `import 'package:sqlite3/common.dart'`; added `ConfirmError` sealed subclass; added static `_extractSqliteException` helper (unwraps both direct and `DriftWrappedException`-wrapped errors); rewrote `_persistMoves()` with try/catch and replaced Path B manual loop with `saveBranch()`.
- **`src/lib/screens/add_line_screen.dart`** — Added `ConfirmError` case in `_onConfirmLine()` switch; updated `_onFlipAndConfirm()` to handle `ConfirmError` with a SnackBar.
- **`src/test/controllers/add_line_controller_test.dart`** — Added `'Confirm error handling'` test group with 3 tests: duplicate SAN triggers `ConfirmError`, state remains consistent after error, and `saveBranch` atomicity (no partial moves on constraint failure).
- **`src/test/screens/add_line_screen_test.dart`** — Added 2 widget tests: error SnackBar on confirm, and error SnackBar on flip-and-confirm.
- **`src/test/screens/drill_filter_test.dart`** — Added `saveBranch` stub to `FakeRepertoireRepository`.
- **`src/test/screens/drill_screen_test.dart`** — Added `saveBranch` stub to `FakeRepertoireRepository`.
- **`src/test/screens/home_screen_test.dart`** — Added `saveBranch` stub to `FakeRepertoireRepository`.

## Deviations from Plan

- `saveBranch` was initially designed to accept `ReviewCardsCompanion`. Code review identified this as an Interface Segregation violation (leaking review types into the repertoire interface) and a hidden coupling via the sentinel `leafMoveId: 0`. Revised to accept only `parentMoveId` + `newMoves` and create the review card internally, matching the `extendLine()` pattern.

## Follow-up Work

- None discovered. The file-size concern in `add_line_controller.dart` (~640 lines) is pre-existing and not exacerbated by this task.
