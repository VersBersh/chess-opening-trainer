# CT-20.4 Implementation Plan

## Goal

Refactor all screens, controllers, and services so they obtain `RepertoireRepository` and `ReviewRepository` through Riverpod provider injection instead of constructing `Local*Repository` instances directly from an `AppDatabase` passed through widget constructors. Additionally, extract repository-calling business logic from `RepertoireBrowserScreen` into a dedicated controller, bringing it into compliance with the architecture rule that widgets never call repositories directly.

## Steps

### Step 1: Add a `databaseProvider` to `providers.dart`

**File:** `src/lib/providers.dart`

`PgnImporter` needs raw `AppDatabase` access for `_db.transaction()`. Rather than passing `AppDatabase` through widget constructors, expose it as a Riverpod provider alongside the existing repository providers. This follows the same pattern -- override in the root `ProviderScope` at startup.

**Changes:**
- Add `final databaseProvider = Provider<AppDatabase>((ref) { throw UnimplementedError(...); });` to `providers.dart`.
- In `src/lib/main.dart`, add `databaseProvider.overrideWithValue(db)` to the `ProviderScope.overrides` list.

**Depends on:** nothing.

### Step 2: Refactor `AddLineController` to accept repository interfaces

**File:** `src/lib/controllers/add_line_controller.dart`

The controller currently stores `AppDatabase _db` and constructs `LocalRepertoireRepository(_db)` / `LocalReviewRepository(_db)` in every method that needs data access.

**Changes:**
- Change the constructor to accept `RepertoireRepository` and `ReviewRepository` instead of `AppDatabase`.
- Store them as `final RepertoireRepository _repertoireRepo` and `final ReviewRepository _reviewRepo`.
- Replace every `LocalRepertoireRepository(_db)` call with `_repertoireRepo` and every `LocalReviewRepository(_db)` call with `_reviewRepo` (5 occurrences in `loadData`, `_persistMoves`, `undoExtension`, `updateLabel`).
- Remove the `import` of `local_repertoire_repository.dart` and `local_review_repository.dart`.
- Remove the `import` of `database.dart` (if no longer needed for types -- note: `ReviewCardsCompanion`, `RepertoireMovesCompanion`, `ReviewCard` types are defined in `database.dart` and re-exported, so this import may need to stay or be replaced with the specific type imports).

**Depends on:** nothing.

### Step 3: Refactor `PgnImporter` to accept repository interfaces plus `AppDatabase`

**File:** `src/lib/services/pgn_importer.dart`

`PgnImporter` needs `_db.transaction()` for per-game atomicity, so it cannot drop `AppDatabase` entirely. However, all repository calls inside the transaction can use injected repository instances (Drift transactions share the same underlying connection, so repositories constructed from the same `AppDatabase` work inside `_db.transaction()`).

**Changes:**
- Change the constructor to accept `RepertoireRepository repertoireRepo`, `ReviewRepository reviewRepo`, and `AppDatabase db`.
- Store them as fields. Use the injected repos for all repository calls.
- Replace all `LocalRepertoireRepository(_db)` / `LocalReviewRepository(_db)` construction (2 in `importPgn`, 1 in `_mergeGame`) with the stored fields.
- Remove imports of `local_repertoire_repository.dart` and `local_review_repository.dart`.

**Note:** The transaction call `_db.transaction(() async { ... })` remains, wrapping calls to the injected repo instances. This works because the local repo implementations share the same Drift `AppDatabase` connection. The `_db` field is only used for `_db.transaction()`.

**Depends on:** nothing.

### Step 4: Extract `RepertoireBrowserController`

**File (new):** `src/lib/controllers/repertoire_browser_controller.dart`

The architecture spec (`architecture/state-management.md`) states: "Widgets never call repositories directly. An intermediate layer (controllers, notifiers, or blocs) encapsulates business logic and exposes reactive state to the UI." Currently `RepertoireBrowserScreen` calls repository methods in ~8 places across `_loadData()`, `_onEditLabelForMove()`, `_deleteMoveAndGetParent()`, `_onDeleteBranch()`, `_handleOrphans()`, `_showOrphanPrompt()`, and `_onViewCardStats()`. Simply switching to `ref.read(...)` would still violate this rule.

Extract a `RepertoireBrowserController` as a `ChangeNotifier` (same pattern as `AddLineController`) that owns the `RepertoireBrowserState` and encapsulates all repository interactions.

**Changes:**
- Create `RepertoireBrowserController` accepting `RepertoireRepository` and `ReviewRepository` (plus `repertoireId`).
- Move `RepertoireBrowserState` into this file (or a shared state file).
- Move the following business logic methods from the screen into the controller:
  - `_loadData()` -> `loadData()`
  - `_computeInitialExpandState()` -> private helper in controller
  - `_onEditLabelForMove()` -> `editLabel(int moveId)` (performs the DB write and reloads; returns before/after showing dialogs -- see note below)
  - `_deleteMoveAndGetParent()` -> `deleteMoveAndGetParent(int moveId)`
  - `_onDeleteBranch()` pre-deletion queries -> `getBranchDeleteInfo(int moveId)` (returns line count + card count for confirmation dialog)
  - `_handleOrphans()` -> `handleOrphans(int? parentMoveId, Future<OrphanChoice?> Function(int moveId) promptUser)` (accepts a callback for UI prompts so the controller can drive the orphan-walking loop without importing Flutter)
  - `_onViewCardStats()` data fetch -> `getCardForLeaf(int moveId)` (returns the `ReviewCard?` so the screen can display the dialog)
- Move pure UI state methods (`_onNodeSelected`, `_onNodeToggleExpand`, `_onFlipBoard`, `_onNavigateBack`, `_onNavigateForward`) into the controller as well, since they mutate `RepertoireBrowserState`.
- The controller calls `notifyListeners()` after state changes, and the screen listens (same pattern as `AddLineController`).

**Dialog interaction pattern:** Methods that need user confirmation (edit label multi-line warning, branch delete confirmation, orphan prompts) either:
  (a) Return the data the screen needs to show a dialog, then accept the user's choice in a follow-up call (e.g., `getBranchDeleteInfo()` + `executeBranchDelete()`), or
  (b) Accept a callback parameter for prompts that occur mid-loop (orphan handling).

This keeps the controller free of Flutter/UI imports.

**Depends on:** nothing.

### Step 5: Refactor `AddLineScreen` to use providers

**File:** `src/lib/screens/add_line_screen.dart`

**Changes:**
- Remove `final AppDatabase db` from the widget constructor.
- Change to `ConsumerStatefulWidget` / `ConsumerState`.
- In `initState`, construct `AddLineController` with repositories from providers:
  ```dart
  _controller = AddLineController(
    ref.read(repertoireRepositoryProvider),
    ref.read(reviewRepositoryProvider),
    widget.repertoireId,
    startingMoveId: widget.startingMoveId,
  );
  ```
  Note: In `ConsumerStatefulWidget`, `ref` is available in `initState` through the `ConsumerState` mixin, so this should work directly.
- Remove import of `database.dart`.
- Add import of `providers.dart`.

**Depends on:** Step 2 (AddLineController refactored to accept repos).

### Step 6: Refactor `ImportScreen` to use providers

**File:** `src/lib/screens/import_screen.dart`

**Changes:**
- Remove `final AppDatabase db` from the widget constructor.
- Change to `ConsumerStatefulWidget` / `ConsumerState`.
- In `_onImport()`, construct `PgnImporter` using injected dependencies:
  ```dart
  final importer = PgnImporter(
    repertoireRepo: ref.read(repertoireRepositoryProvider),
    reviewRepo: ref.read(reviewRepositoryProvider),
    db: ref.read(databaseProvider),
  );
  ```
- Remove import of `database.dart`.
- Add imports of `providers.dart` and `flutter_riverpod`.

**Depends on:** Step 1 (databaseProvider), Step 3 (PgnImporter refactored).

### Step 7: Convert `RepertoireBrowserScreen` to use `RepertoireBrowserController` and providers

**File:** `src/lib/screens/repertoire_browser_screen.dart`

This step depends on Steps 4, 5, and 6. Steps 5 and 6 must be completed first (or simultaneously) because this step removes `db:` arguments from `AddLineScreen(...)` and `ImportScreen(...)` navigation calls, which requires those constructors to already be updated.

**Changes:**
- Change the class hierarchy: `StatefulWidget` -> `ConsumerStatefulWidget`, `State` -> `ConsumerState`.
- Remove `final AppDatabase db` from the widget constructor. The constructor keeps `repertoireId` only.
- In `initState`, create the `RepertoireBrowserController` with repositories from providers:
  ```dart
  _controller = RepertoireBrowserController(
    ref.read(repertoireRepositoryProvider),
    ref.read(reviewRepositoryProvider),
    widget.repertoireId,
  );
  ```
- Replace all direct repository construction and calls with controller method calls.
- Remove all business logic methods that moved to the controller.
- Keep dialog methods (`_showLabelDialog`, `_showDeleteConfirmationDialog`, `_showBranchDeleteConfirmationDialog`, `_showOrphanPrompt`, `_showMultiLineWarningDialog`) in the screen since they are UI concerns, but wire them to the controller via the callback/two-step pattern.
- Update `_onAddLine()`: remove `db: widget.db` from the `AddLineScreen(...)` constructor call.
- Update Import button handlers (compact and full action bar): remove `db: widget.db` from the `ImportScreen(...)` constructor call.
- Add import for `providers.dart`, `flutter_riverpod`, and the new controller file.
- Remove imports of `local_repertoire_repository.dart`, `local_review_repository.dart`, `database.dart` (unless still needed for types like `ReviewCard` in the card stats dialog -- if so, keep a targeted import).

**Depends on:** Steps 4, 5, 6.

### Step 8: Remove `AppDatabase db` from `HomeScreen`

**File:** `src/lib/screens/home_screen.dart`

**Changes:**
- Remove `final AppDatabase db` from the `HomeScreen` widget constructor.
- In `_onAddLineTap()`, `_onRepertoireTap()`, and `_onCreateFirstRepertoire()`, remove `db: widget.db` from the `AddLineScreen(...)` and `RepertoireBrowserScreen(...)` constructor calls.
- Remove import of `database.dart`.

**Depends on:** Steps 5, 7 (child screens no longer require `db`).

### Step 9: Update `main.dart`

**File:** `src/lib/main.dart`

**Changes:**
- Add `databaseProvider.overrideWithValue(db)` to the `ProviderScope.overrides` list.
- Change `HomeScreen(db: db)` to `const HomeScreen()` (or `HomeScreen()` if `const` is not applicable).

**Depends on:** Step 8 (HomeScreen no longer requires `db`).

### Step 10: Update `home_screen_test.dart`

**File:** `src/test/screens/home_screen_test.dart`

**Changes:**
- In `buildTestApp()`, remove the `AppDatabase? db` parameter and the `HomeScreen(db: testDb)` constructor call. Change to `const HomeScreen()`.
- For navigation tests that currently create a real `AppDatabase` to pass to `HomeScreen` (so that `AddLineScreen` / `RepertoireBrowserScreen` can load data from it), these tests will need to instead override the repository providers with real `LocalRepertoireRepository` / `LocalReviewRepository` backed by the in-memory database. Alternatively, if the child screens now use Riverpod providers and the test already overrides those providers with fakes, the navigation tests may work without a real DB.
- Review each test that passes `db: db` to `buildTestApp` and determine whether the fake repos are sufficient or whether the test relies on real DB state (e.g., the "tapping Add Line navigates to AddLineScreen" test seeds a repertoire into the DB because `AddLineController.loadData()` reads from it). After this refactor, `AddLineController` reads from the injected `RepertoireRepository`, so the fake should suffice if it returns the expected data.
- Update the `buildTestApp` helper and affected tests accordingly. Add `databaseProvider.overrideWithValue(testDb)` if any test still needs it.

**Depends on:** Steps 8, 5.

### Step 11: Update `repertoire_browser_screen_test.dart`

**File:** `src/test/screens/repertoire_browser_screen_test.dart`

**Changes:**
- The `buildTestApp` helper currently constructs `RepertoireBrowserScreen(db: db, repertoireId: repertoireId)`. Update to `RepertoireBrowserScreen(repertoireId: repertoireId)`.
- Add provider overrides for `repertoireRepositoryProvider` and `reviewRepositoryProvider` backed by the test `AppDatabase`. Since these tests use a real in-memory DB, override with `LocalRepertoireRepository(db)` and `LocalReviewRepository(db)`:
  ```dart
  ProviderScope(
    overrides: [
      repertoireRepositoryProvider.overrideWithValue(LocalRepertoireRepository(db)),
      reviewRepositoryProvider.overrideWithValue(LocalReviewRepository(db)),
      sharedPreferencesProvider.overrideWithValue(_testPrefs),
    ],
    ...
  )
  ```
- Remove the `db` parameter from the `RepertoireBrowserScreen(...)` constructor call.

**Depends on:** Step 7.

### Step 12: Update `add_line_controller_test.dart`

**File:** `src/test/controllers/add_line_controller_test.dart`

**Changes:**
- The test currently constructs `AddLineController(db, repId, ...)`. Update to construct with repository interfaces: `AddLineController(LocalRepertoireRepository(db), LocalReviewRepository(db), repId, ...)`.
- The test directly uses the DB for seeding and verification, which is fine (test setup is not production code).

**Depends on:** Step 2.

### Step 13: Update `add_line_screen_test.dart`

**File:** `src/test/screens/add_line_screen_test.dart`

**Changes:**
- The test constructs `AddLineScreen(db: db, repertoireId: repId, ...)`. Update to `AddLineScreen(repertoireId: repId, ...)`.
- Wrap in a `ProviderScope` with repository provider overrides backed by the test DB.

**Depends on:** Step 5.

### Step 14: Update `import_screen_test.dart`

**File:** `src/test/screens/import_screen_test.dart`

**Changes:**
- The test constructs `ImportScreen(db: db, repertoireId: repId)`. Update to `ImportScreen(repertoireId: repId)`.
- Wrap in a `ProviderScope` with `repertoireRepositoryProvider`, `reviewRepositoryProvider`, and `databaseProvider` overrides backed by the test DB.

**Depends on:** Step 6.

### Step 15: Update `pgn_importer_test.dart`

**File:** `src/test/services/pgn_importer_test.dart`

**Changes:**
- The test constructs `PgnImporter(db: db)`. Update to `PgnImporter(repertoireRepo: LocalRepertoireRepository(db), reviewRepo: LocalReviewRepository(db), db: db)`.

**Depends on:** Step 3.

### Step 16: Add unit tests for `RepertoireBrowserController`

**File (new):** `src/test/controllers/repertoire_browser_controller_test.dart`

**Changes:**
- Add unit tests for the new `RepertoireBrowserController`, following the same pattern as `add_line_controller_test.dart` (real in-memory `AppDatabase`, construct controller with `LocalRepertoireRepository(db)` and `LocalReviewRepository(db)`).
- Test: `loadData` populates state with tree cache, expanded nodes, and due counts.
- Test: `editLabel` updates the move label and reloads data.
- Test: `deleteMoveAndGetParent` returns the correct parent ID.
- Test: `handleOrphans` walks up the tree correctly with different user choices.
- Test: `getCardForLeaf` returns the review card when present.
- Test: pure state methods (`selectNode`, `toggleExpand`, `flipBoard`, `navigateBack`, `navigateForward`).

**Depends on:** Step 4.

### Step 17: Verify and run all tests

Run `flutter test` to confirm all existing tests pass with the new wiring.

**Depends on:** all previous steps.

## Risks / Open Questions

1. **`PgnImporter` transaction semantics.** The `_mergeGame` method wraps repository calls inside `_db.transaction()`. Drift transactions work by replacing the executor on the database object, so repository instances constructed from the same `AppDatabase` before the transaction will still route through the transactional executor. This should work correctly with injected repos (they hold a reference to the same `AppDatabase`), but must be verified by running the PGN importer tests. If it does not work, an alternative is to add a `runInTransaction(Future<T> Function() action)` method to the repository interface or keep the `AppDatabase` reference specifically for transaction wrapping.

2. **`ConsumerStatefulWidget` `ref` availability in `initState`.** In `ConsumerStatefulWidget`, the `ref` property is available in `initState` because `ConsumerState` overrides it. However, providers should ideally be read lazily rather than eagerly in `initState`. Verify that reading `ref.read(...)` in `initState` does not cause lifecycle issues. If it does, move the controller construction to the first `build()` call or use `late final` with initialization in `didChangeDependencies`.

3. **Test helper duplication.** The `seedRepertoire` / `createTestDatabase` helpers are duplicated across several test files. This refactoring does not address that duplication (out of scope for CT-20.4), but consolidating them into a shared test utility would be a good follow-up.

4. **Scope of `PgnImporter` refactoring.** The task description says `PgnImporter` needs `AppDatabase` for per-game transactions. The plan preserves `AppDatabase` injection alongside repository interfaces. A cleaner long-term approach would be to add a `transaction` method to the repository interface, but that is a larger change better deferred to a dedicated task.

5. **Navigation tests in `home_screen_test.dart`.** The "tapping Add Line navigates to AddLineScreen" and "tapping repertoire name navigates to RepertoireBrowserScreen" tests currently seed a real DB and pass it through. After this refactor, the child screens read from providers. The tests must ensure the provider overrides supply data that the child screens can load (i.e., the fake repos or real-DB-backed repos return valid data). The existing `FakeRepertoireRepository` may need additional method stubs if child screen initialization calls methods not currently stubbed.

6. **Controller dialog interaction pattern.** The `RepertoireBrowserController` must not depend on Flutter for showing dialogs. Methods like `editLabel` and `handleOrphans` that require user confirmation use a two-step call pattern (query data, then execute after screen shows dialog) or accept a callback. This adds some interaction complexity between screen and controller but is necessary to keep the controller testable in isolation, per the architecture spec: "State holders are testable in isolation. Business logic can be unit-tested without Flutter widgets."

7. **Review issue #1 from `3-plan-review.md` -- extracting `RepertoireBrowserController`.** The reviewer correctly identified that the original plan's Step 4 merely replaced `LocalRepertoireRepository(widget.db)` with `ref.read(repertoireRepositoryProvider)` but left all repository calls inside the widget, violating `architecture/state-management.md`. The revised plan adds Step 4 (extract controller) and Step 16 (controller tests) to address this.

8. **Review issue #2 from `3-plan-review.md` -- step ordering.** The reviewer correctly identified that the original Step 4 removed `db:` args from `AddLineScreen`/`ImportScreen` navigation calls before those constructors were changed in Steps 5/6. The revised plan reorders: Steps 5 and 6 now come before Step 7 (the new combined step for converting `RepertoireBrowserScreen`), and Step 7's dependency list explicitly includes Steps 5 and 6.
