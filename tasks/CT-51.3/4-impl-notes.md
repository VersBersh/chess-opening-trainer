# CT-51.3 Implementation Notes

## Files Modified

- `src/lib/screens/home_screen.dart` — Added `import 'add_line_screen.dart';`, added `_onAddLine(int repertoireId)` navigation handler after `_onRepertoireTap`, and inserted an `OutlinedButton.icon` "Add Line" button between Free Practice and Manage Repertoire in `_buildActionButtons`.
- `src/test/screens/home_screen_test.dart` — Added `import 'package:chess_trainer/screens/add_line_screen.dart';`, renamed button-presence test to include "Add Line", added `expect(find.text('Add Line'), findsOneWidget)` to the button-presence test, added `expect(find.text('Add Line'), findsNothing)` to the empty-state absence test, and added a new `'Add Line navigates to AddLineScreen'` navigation test inside the `'HomeScreen - three-button layout'` group.

## Deviations from Plan

None. All six steps were implemented exactly as specified.

## New Tasks / Follow-up Work

None discovered during implementation.
