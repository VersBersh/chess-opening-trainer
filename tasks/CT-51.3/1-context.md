# CT-51.3 Context

## Relevant Files

- `src/lib/screens/home_screen.dart` — The home screen widget. Contains `_buildActionButtons`, the method that renders the three current action buttons (Start Drill, Free Practice, Manage Repertoire). Primary file to modify.
- `src/lib/screens/add_line_screen.dart` — The destination screen. Already accepts `repertoireId` and an optional `startingMoveId`. No changes needed here.
- `src/lib/controllers/home_controller.dart` — The Riverpod controller and `HomeState` backing the home screen. No changes needed: the `repertoireId` is already available from `homeState.repertoires.first.repertoire.id`.
- `src/test/screens/home_screen_test.dart` — Widget tests for the home screen. Needs new test cases to cover the Add Line button: presence, enabled state, navigation, and absence in the empty state.

## Architecture

The home screen is a `ConsumerStatefulWidget` backed by the `homeControllerProvider` (an `AutoDisposeAsyncNotifier`). When data loads, `_buildData` delegates to `_buildActionButtons` if at least one repertoire exists, otherwise shows `HomeEmptyState`. `_buildActionButtons` pulls the first repertoire from `homeState.repertoires` and renders the three buttons in a `Column` inside a `SingleChildScrollView`. Each navigation action is a private method on `_HomeScreenState` that calls `Navigator.of(context).push(...)` and then triggers `homeControllerProvider.notifier.refresh()` on return.

The `AddLineScreen` widget takes `repertoireId` (required) and an optional `startingMoveId`. When navigated to from the Repertoire Manager, `startingMoveId` is set to the currently-selected node; from the home screen the starting position is the root, so `startingMoveId` should be omitted (or passed as `null`).

The home screen test file uses `FakeRepertoireRepository` and `FakeReviewRepository` with a `buildTestApp` helper that wires providers via `ProviderScope` overrides. Navigation tests that need a live screen use an in-memory `AppDatabase` instead. The existing pattern for testing navigation is to push via `tester.tap(...)`, call `pumpAndSettle()`, then assert `find.byType(TargetScreen)`.
