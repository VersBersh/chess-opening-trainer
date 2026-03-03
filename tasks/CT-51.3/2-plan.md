# CT-51.3 Plan

## Goal

Add a fourth "Add Line" button to the home screen's action-button layout that navigates directly to `AddLineScreen` for the active repertoire.

## Steps

1. **`src/lib/screens/home_screen.dart` — Add import for `AddLineScreen`**

   Add `import 'add_line_screen.dart';` alphabetically with the other screen imports (after `drill_screen.dart`, before `repertoire_browser_screen.dart`).

2. **`src/lib/screens/home_screen.dart` — Add `_onAddLine` navigation handler**

   Add a private method `_onAddLine(int repertoireId)` on `_HomeScreenState`, modelled exactly on the other navigation handlers. Push a `MaterialPageRoute` for `AddLineScreen(repertoireId: repertoireId)` (no `startingMoveId` — start from root), then call `ref.read(homeControllerProvider.notifier).refresh()` when it returns.

3. **`src/lib/screens/home_screen.dart` — Insert "Add Line" button in `_buildActionButtons`**

   In `_buildActionButtons`, insert a new button for "Add Line" between "Free Practice" and "Manage Repertoire" (spec order: Start Drill, Free Practice, Add Line, Manage Repertoire). Match the style of the existing buttons (same `OutlinedButton.icon` or `ElevatedButton.icon` pattern with `minimumSize: const Size(double.infinity, 48)`).

   The button is always enabled when a repertoire exists (the entire `_buildActionButtons` branch only runs when `homeState.repertoires.isNotEmpty`), so `onPressed` is always non-null here.

   Depends on steps 1 and 2.

4. **`src/test/screens/home_screen_test.dart` — Update existing button-presence test**

   The existing test that checks for "Start Drill", "Free Practice", and "Manage Repertoire" buttons should be updated to also assert `find.text('Add Line'), findsOneWidget`.

5. **`src/test/screens/home_screen_test.dart` — Update empty-state absence test**

   The existing empty-state test should add: `expect(find.text('Add Line'), findsNothing);`

6. **`src/test/screens/home_screen_test.dart` — Add navigation test for Add Line**

   Add a test verifying tapping "Add Line" navigates to `AddLineScreen`. Use the same in-memory database pattern as the existing navigation tests (e.g., "Manage Repertoire navigates to RepertoireBrowserScreen"). Seed a repertoire, tap "Add Line", assert `find.byType(AddLineScreen), findsOneWidget`.

   Depends on step 3.

## Risks / Open Questions

- **Button styling:** Need to read `home_screen.dart` to confirm the exact button widget type and style used. Plan assumes matching the existing pattern exactly.
- **Refresh on return:** The other navigation handlers all call `refresh()` on pop. Add Line should do the same because returning from adding a new line may change `totalCardCount`.
- **No `startingMoveId`:** From the home screen the user starts from the root position. Omitting `startingMoveId` (defaults to `null`) is consistent with how `AddLineController` initialises — it loads from the root when `startingMoveId` is null.
- **No controller or state changes needed:** The `HomeState` already exposes everything needed (`repertoire.id`).
