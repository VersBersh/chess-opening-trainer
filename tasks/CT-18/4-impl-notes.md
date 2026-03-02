# CT-18: Implementation Notes

## Files Created

- **`src/lib/controllers/home_controller.dart`** -- New file containing `RepertoireSummary`, `HomeState`, `homeControllerProvider`, and `HomeController`, extracted verbatim from `home_screen.dart`.

- **`src/lib/widgets/repertoire_card.dart`** -- New `StatelessWidget` encapsulating the per-repertoire card layout (header row with name/badge/popup menu, action row with Start Drill/Free Practice/Add Line). All controller interactions are mediated through `VoidCallback` parameters. Snackbar for "no cards due" stays inside the widget.

- **`src/lib/widgets/home_empty_state.dart`** -- New `StatelessWidget` encapsulating the empty-state onboarding view (icon, descriptive text, "Create your first repertoire" button). Pure presentation with a single `VoidCallback`.

## Files Modified

- **`src/lib/screens/home_screen.dart`** -- Removed `RepertoireSummary`, `HomeState`, `homeControllerProvider`, `HomeController`, `_buildRepertoireCard`, and `_buildEmptyState`. Added imports for the three new files. Updated `_buildRepertoireList` to use `RepertoireCard(...)` with callback wiring. Updated `_buildData` to use `HomeEmptyState(...)`. Removed unused imports (`../providers.dart`, `../repositories/local/database.dart`). Reduced from ~522 lines to ~307 lines.

- **`src/test/screens/home_screen_test.dart`** -- Added `import 'package:chess_trainer/controllers/home_controller.dart';` so that `homeControllerProvider` (used on lines 367 and 405) resolves after the move.

## Deviations from Plan

- **Removed `../providers.dart` and `../repositories/local/database.dart` imports from `home_screen.dart`.** The plan did not explicitly call out removing these imports, but after extraction, `home_screen.dart` no longer directly references any symbols from either file. `homeControllerProvider` and all database types (`Repertoire`, `RepertoiresCompanion`) are now accessed transitively through `home_controller.dart`. Keeping unused imports would trigger lint warnings.

- **No other deviations.** All callback signatures use `VoidCallback` as specified in the plan. The `onRename` and `onDelete` callbacks in `_buildRepertoireList` are implemented as async closures assigned to `VoidCallback` parameters, which is valid Dart (async closures returning `Future<void>` satisfy `void Function()`).

## Follow-Up Work

- None discovered. The refactoring is purely structural with no behavioral changes.
