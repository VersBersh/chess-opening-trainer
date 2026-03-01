# CT-1.4 Implementation Plan

## Goal

Migrate the home screen from direct repository access to Riverpod-managed state via a `HomeController`, fix due count refresh on return from the repertoire browser, and confirm all acceptance criteria are met.

## Steps

### 1. Create HomeController as a Riverpod AsyncNotifier

**File:** `src/lib/screens/home_screen.dart` (modify)

Define a `HomeState` data class and `HomeController` AsyncNotifier in the same file (co-located with the screen, matching the `drill_screen.dart` pattern):

```dart
class HomeState {
  final List<RepertoireSummary> repertoires;
  final int totalDueCount;
  const HomeState({this.repertoires = const [], this.totalDueCount = 0});
}

class RepertoireSummary {
  final Repertoire repertoire;
  final int dueCount;
  const RepertoireSummary({required this.repertoire, required this.dueCount});
}
```

The `HomeController` extends `AutoDisposeAsyncNotifier<HomeState>`:
- `build()`: reads `repertoireRepositoryProvider` and `reviewRepositoryProvider` via `ref.read`. Loads all repertoires via `getAllRepertoires()`. For each, calls `getDueCardsForRepertoire(id)` to get due count. Returns `HomeState` with the list and total.
- `refresh()`: re-runs the same load logic and updates state. Called on return from drill/repertoire screens.
- `openRepertoire()`: returns the ID of the first repertoire, auto-creating "My Repertoire" via `repertoireRepositoryProvider` if none exist. All repository access stays in the controller; the widget only receives the resulting ID and performs the navigation push. After creating a repertoire, the method also updates controller state so the repertoire list is current.

Define provider:
```dart
final homeControllerProvider = AsyncNotifierProvider.autoDispose<HomeController, HomeState>(HomeController.new);
```

No dependencies on other steps.

### 2. Migrate HomeScreen to ConsumerStatefulWidget with AsyncValue handling

**File:** `src/lib/screens/home_screen.dart` (modify)

- Change `HomeScreen` from `StatefulWidget` to `ConsumerStatefulWidget`.
- Keep `AppDatabase db` as a constructor parameter (transitional; needed only to pass to `RepertoireBrowserScreen` during navigation -- see Step 4 rationale).
- Remove the `_dueCount` / `_repertoireId` fields and `_loadDueCount()` method.
- Use `ref.watch(homeControllerProvider)` to get `AsyncValue<HomeState>`.
- Handle all three `AsyncValue` states using `.when()`, matching the `DrillScreen` pattern:
  - **`loading`**: Show a `CircularProgressIndicator` centered in the scaffold body. The "Start Drill" button is not rendered (or the scaffold shows only the spinner) until data loads.
  - **`error`**: Show an error message with a retry button that calls `ref.invalidate(homeControllerProvider)` to re-trigger `build()`.
  - **`data`**: Render the existing UI -- due count text, "Start Drill" button (disabled when totalDueCount == 0), "Repertoire" button.
- `ConsumerStatefulWidget` is used (not `ConsumerWidget`) because navigation `.then()` callbacks require `context` stability across async gaps.
- On return from drill navigation, call `ref.read(homeControllerProvider.notifier).refresh()`.

Depends on: Step 1.

### 3. Fix due count refresh on return from repertoire browser

**File:** `src/lib/screens/home_screen.dart` (modify)

The current `_onRepertoireTap()` navigates to `RepertoireBrowserScreen` but does NOT refresh due count on return (unlike `_startDrill()` which chains `.then((_) => _loadDueCount())`).

Add `.then((_) => ref.read(homeControllerProvider.notifier).refresh())` to the `Navigator.push` call for repertoire browser navigation.

Depends on: Steps 1, 2.

### 4. Update main.dart to remove db from ChessTrainerApp

**File:** `src/lib/main.dart` (modify)

- Remove `db` field from `ChessTrainerApp` since it is no longer needed there.
- `HomeScreen` still accepts `db` as a constructor parameter (for passing to `RepertoireBrowserScreen` during navigation). Pass `db` directly to `HomeScreen(db: db)` in main's `runApp` call, inside the `ProviderScope` child.

This is a minimal change: the `ChessTrainerApp` no longer needs to carry `db`, but `HomeScreen` retains it as transitional plumbing solely for the browser navigation path. See Risk 2 for the rationale against introducing `appDatabaseProvider`.

Depends on: Step 2.

### 5. Wire openRepertoire through the controller for repertoire tap

**File:** `src/lib/screens/home_screen.dart` (modify)

Replace the current `_onRepertoireTap()` method. The widget calls `ref.read(homeControllerProvider.notifier).openRepertoire()` to get the repertoire ID (the controller handles the get-or-create logic via the repository). The widget then uses the returned ID to push `RepertoireBrowserScreen(db: widget.db, repertoireId: id)`.

This keeps all repository access in the controller per the architecture spec ("widgets never call repositories directly").

Depends on: Steps 1, 2, 4.

### 6. Add home screen widget test for due count refresh

**File:** `src/test/screens/home_screen_test.dart` (create)

Write at least one widget test verifying that the due count refreshes after returning from repertoire navigation. Follow the patterns established in `drill_screen_test.dart`:

- Reuse `FakeRepertoireRepository` and `FakeReviewRepository` from `drill_screen_test.dart` (or extract them into a shared test helper file if the import is cleaner; otherwise duplicate/re-export).
- Create a `buildTestApp()` helper that wraps `HomeScreen` in a `ProviderScope` with repository overrides, similar to the drill screen test helper. Since `HomeScreen` still takes `db`, either pass a dummy/mock `AppDatabase` or restructure the helper to avoid needing a real database (the controller reads repos from providers, not from `widget.db`, so the `db` parameter is only used for navigation -- which the test can stub or skip).
- **Test: due count displays on initial load.** Pump the widget, verify the due count text matches the fake repository's due card count.
- **Test: due count refreshes after navigation return.** Mutate the fake repository's due cards list (e.g., clear it to simulate cards being reviewed), simulate a navigation push/pop cycle, and verify the displayed due count updates.

The test does not need to actually navigate to `RepertoireBrowserScreen` -- it can verify that `refresh()` is called and that the UI reflects the updated count by directly invoking the controller's `refresh()` method via the provider container after mutating the fake repo state.

Depends on: Steps 1, 2.

## Risks / Open Questions

1. **Scope calibration.** The four acceptance criteria are functionally met by CT-1.3's implementation. This task is primarily an architectural migration (Riverpod) plus the missing repertoire-return refresh. The migration is prescribed by the state-management spec and was explicitly deferred to CT-1.4 by CT-1.3.

2. **AppDatabase as transitional plumbing on HomeScreen (review issue 4).** The review suggested either keeping `db` on `HomeScreen` or introducing an `appDatabaseProvider`. This plan keeps `db` on `HomeScreen` as the simpler option. The `db` parameter is only used when pushing `RepertoireBrowserScreen`, which still takes `AppDatabase` directly. Introducing a provider for `AppDatabase` adds a new provider, a `ProviderScope` override, and a `ref.read` call -- all of which will be removed when the browser screen is migrated to Riverpod. Keeping `db` on the constructor is less code churn and equally correct for this transitional phase.

3. **Reactive due counts deferred.** The spec recommends Drift `watch` queries for reactive due counts. Manual refresh via `.then()` on navigation return is sufficient for the acceptance criteria. Reactive streams would require adding `watchDueCards` methods to the repository interface -- out of scope for CT-1.4.

4. **Multi-repertoire UI deferred.** The spec describes a per-repertoire list with individual drill buttons. The current simplified single-view is acceptable since the dev seed only creates one repertoire. The `HomeState` model supports multiple repertoires in its data structure for future expansion.

5. **Test database dependency.** `HomeScreen` takes `AppDatabase db` as a constructor param, but in tests the controller reads repos from Riverpod providers (not from `widget.db`). The `db` param is only used when navigating to `RepertoireBrowserScreen`. Tests that do not exercise browser navigation can pass a dummy/null value or a mock. If constructing a real `AppDatabase` in tests is impractical, consider making the `db` parameter nullable with a `TODO` comment noting it will be removed when the browser screen is migrated.

6. **Shared test fakes.** The drill screen test file defines `FakeRepertoireRepository` and `FakeReviewRepository`. The home screen tests need the same fakes. Options: (a) import them directly from `drill_screen_test.dart` (Dart allows this but it is unconventional), (b) extract into a shared `test/helpers/` file, or (c) duplicate them. Option (b) is cleanest but adds a refactoring step. Choose whichever is fastest during implementation -- the fakes are small and stable.
