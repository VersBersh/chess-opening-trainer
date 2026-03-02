# CT-17: Context

## Relevant Files

- **`src/lib/screens/home_screen.dart`** -- HomeScreen widget and HomeController (AsyncNotifier). Contains `RepertoireSummary`, `HomeState`, and `HomeController` with the `openRepertoire()` method that auto-creates "My Repertoire" (the stopgap to replace). The `_buildEmptyState` method has a `TODO(CT-next)` marking the spot. The `_buildRepertoireCard` method renders each repertoire card -- the context menu must be added here.

- **`src/lib/repositories/repertoire_repository.dart`** -- Abstract `RepertoireRepository` interface. Has `saveRepertoire(RepertoiresCompanion)` (insert-only) and `deleteRepertoire(int id)`, but **no rename/update method**. A `renameRepertoire(int id, String newName)` method must be added.

- **`src/lib/repositories/local/local_repertoire_repository.dart`** -- `LocalRepertoireRepository` implementing `RepertoireRepository`. Uses Drift `_db.into(_db.repertoires).insert(...)` for save and `_db.delete(...)` for delete. The rename implementation will use `_db.update(_db.repertoires)..where(...)`.write(...)`.

- **`src/lib/repositories/local/database.dart`** -- Drift database schema. `Repertoires` table has `id` (autoincrement) and `name` (text). `RepertoireMoves` and `ReviewCards` both reference `Repertoires` with `onDelete: KeyAction.cascade`, so deleting a repertoire cascades correctly.

- **`src/lib/repositories/local/database.g.dart`** -- Generated Drift code. `RepertoiresCompanion` has `id` and `name` fields with `Value<T>` wrappers, supporting partial updates. `Repertoire` data class has `id` (int) and `name` (String).

- **`src/test/screens/home_screen_test.dart`** -- Existing widget tests. Contains `FakeRepertoireRepository` and `FakeReviewRepository` fakes, plus a `buildTestApp` helper. The `FakeRepertoireRepository.deleteRepertoire` is a no-op stub -- it does not actually remove from the list. Tests cover due counts, button states, empty state, navigation. No context menu or dialog tests exist.

- **`src/lib/providers.dart`** -- Riverpod providers for `databaseProvider`, `repertoireRepositoryProvider`, `reviewRepositoryProvider`, and `sharedPreferencesProvider`.

- **`features/home-screen.md`** -- Feature spec. The "Repertoire CRUD" section defines Create (dialog with text field + confirm), Rename (context menu, pre-filled dialog), and Delete (context menu, confirmation dialog with cascade warning). The "Onboarding" section specifies that the empty-state "Create your first repertoire" button opens the same creation dialog.

- **`architecture/state-management.md`** -- Documents the Riverpod pattern: widgets never call repositories directly; controllers (AsyncNotifiers) encapsulate business logic. The HomeController example explicitly lists `createRepertoire()` and `deleteRepertoire()` as expected controller methods.

- **`architecture/testing-strategy.md`** -- Testing approach. Widget tests focus on interaction behavior with mocked dependencies. Repository tests run against in-memory SQLite. The strategy lists "CRUD for repertoires" under RepertoireRepository tests.

- **`src/lib/screens/add_line_screen.dart`** -- Contains `_showLabelDialog`, the closest existing pattern for a text-field-in-dialog flow. Uses `showDialog<String>` with `AlertDialog`, `TextEditingController`, `StatefulBuilder` for reactive validation preview, autofocus, and Cancel/Save actions. This is the reference pattern for the Create and Rename dialogs.

- **`src/lib/screens/repertoire_browser_screen.dart`** -- Contains `_showDeleteConfirmationDialog`, the reference pattern for the Delete confirmation dialog. Uses `showDialog<bool>` returning `true` (confirm) or `false` (cancel) via `Navigator.of(context).pop(...)`.

## Architecture

The home screen follows the standard Riverpod controller pattern. `HomeController` is an `AutoDisposeAsyncNotifier<HomeState>` that loads repertoire summaries from `RepertoireRepository` and `ReviewRepository`. The widget (`HomeScreen`) is a `ConsumerStatefulWidget` that watches `homeControllerProvider` and renders the list or empty state.

The data flow for CRUD operations will be:

1. **UI** shows dialog, collects user input (name for create/rename, confirmation for delete).
2. **UI** calls a method on `HomeController` (e.g., `createRepertoire(name)`, `renameRepertoire(id, name)`, `deleteRepertoire(id)`).
3. **HomeController** calls the corresponding `RepertoireRepository` method.
4. **HomeController** refreshes state by calling `_load()` to rebuild the repertoire list.
5. **UI** rebuilds from the new `AsyncValue<HomeState>`.

Key constraints:
- Widgets never call repositories directly (enforced by architecture).
- The `openRepertoire()` auto-create pattern must be removed entirely and replaced with dialog-driven creation.
- Delete cascade is handled at the database level (`ON DELETE CASCADE`), so the controller only needs to call `deleteRepertoire(id)` and refresh.
- The repository interface needs a new `renameRepertoire` method since `saveRepertoire` does insert-only (it takes a `RepertoiresCompanion` used with `_db.into(...).insert(...)`).
