# CT-63: Context

## Relevant Files

| File | Role |
|------|------|
| `features/home-screen.md` | Feature spec for the home screen. Documents single-repertoire layout, CRUD operations (create/rename/delete), onboarding empty state, and notes that rename/delete are not exposed in the current single-repertoire UI. |
| `src/lib/screens/home_screen.dart` | **Primary change target.** Contains `_HomeScreenState` with the existing `_showCreateRepertoireDialog` method (lines 72-108), the single-repertoire action-button layout (`_buildActionButtons`), and the `_onCreateFirstRepertoire` handler. New rename/delete dialogs and a repertoire list UI will be added here. |
| `src/lib/controllers/home_controller.dart` | Home screen state management. Defines `HomeState` (list of `RepertoireSummary`) and `HomeController` with `createRepertoire`, `renameRepertoire`, and `deleteRepertoire` methods already implemented. These controller methods reload state after mutation via `_load()`. No changes expected. |
| `src/lib/widgets/home_empty_state.dart` | Empty-state widget shown when zero repertoires exist. Displays onboarding text and a "Create your first repertoire" button. No changes expected. |
| `src/lib/repositories/repertoire_repository.dart` | Abstract repository interface. Declares `saveRepertoire`, `deleteRepertoire`, and `renameRepertoire`. All three are already implemented. |
| `src/lib/repositories/local/local_repertoire_repository.dart` | Concrete Drift implementation of `RepertoireRepository`. `deleteRepertoire` deletes the row (cascade handles moves and cards). `renameRepertoire` updates the name column. No changes expected. |
| `src/lib/repositories/local/database.dart` | Drift schema. `Repertoires` table has `id` (auto-increment) and `name` (text, no uniqueness constraint). `RepertoireMoves` and `ReviewCards` reference `Repertoires.id` with `ON DELETE CASCADE`. |
| `src/lib/repositories/local/database.g.dart` | Generated Drift code. `Repertoire` data class has `id: int` and `name: String`. `RepertoiresCompanion` used for inserts. |
| `src/lib/providers.dart` | Riverpod providers for `databaseProvider`, `repertoireRepositoryProvider`, `reviewRepositoryProvider`, `sharedPreferencesProvider`, `clockProvider`. Used to override dependencies in tests. |
| `src/lib/widgets/repertoire_dialogs.dart` | Existing shared dialogs (delete move, delete branch, orphan prompt, card stats, no-name warning, reroute confirmation, label impact warning). Provides the dialog pattern/convention used throughout the codebase. New repertoire CRUD dialogs could be placed here or kept inline in `home_screen.dart`. |
| `src/test/screens/home_screen_test.dart` | **Test change target.** Existing tests for home screen layout, due counts, empty state, and create dialog. Contains `FakeRepertoireRepository` and `FakeReviewRepository` test doubles plus a `buildTestApp` helper. New tests for rename/delete dialogs will be added here. |
| `src/test/widgets/repertoire_dialogs_test.dart` | Existing tests for `showLabelImpactWarningDialog`. Demonstrates the project's dialog-testing pattern: pump a `MaterialApp` with a `Builder` that shows the dialog in `addPostFrameCallback`, interact with buttons, and verify result via a holder object. |

## Architecture

### Subsystem Overview

The home screen is the app's entry point. It uses `HomeController` (a Riverpod `AsyncNotifier`) to load a list of `RepertoireSummary` objects from the repository layer. Each summary bundles a `Repertoire` record with computed `dueCount` and `totalCardCount` values.

### Current Single-Repertoire Pattern

The home screen currently assumes a single repertoire. When repertoires exist, it accesses `homeState.repertoires.first` and renders four action buttons (Start Drill, Free Practice, Add Line, Manage Repertoire). There is no repertoire list, no context menu, and no way to create additional repertoires after the first one. The empty state (zero repertoires) shows an onboarding screen with a "Create your first repertoire" button.

### Controller Layer (Already Complete)

`HomeController` already has all three CRUD methods:
- `createRepertoire(String name)` -- saves via repository, reloads state, returns the new ID.
- `renameRepertoire(int id, String newName)` -- updates via repository, reloads state.
- `deleteRepertoire(int id)` -- deletes via repository (cascade removes moves + cards), reloads state.

All three reload `HomeState` after mutation, so the UI will update reactively.

### Repository/Database Layer (Already Complete)

- `RepertoireRepository.saveRepertoire` inserts a new row.
- `RepertoireRepository.renameRepertoire` updates the name column.
- `RepertoireRepository.deleteRepertoire` deletes the row; `ON DELETE CASCADE` foreign keys on `repertoire_moves` and `review_cards` handle cleanup.
- There is **no uniqueness constraint** on repertoire names in the database schema. Duplicate name handling is a UI-level concern.

### Dialog Conventions

The codebase uses top-level `Future<T?> show...Dialog(BuildContext, ...)` functions that call `showDialog<T>`. Dialogs are `AlertDialog` widgets with title, content, and action buttons. Cancel returns `null` or `false`; confirm returns the result value. The existing `_showCreateRepertoireDialog` in `home_screen.dart` uses `StatefulBuilder` for reactive validation (disabling the Create button when the name is empty).

### Key Constraints

1. The home screen layout must transition from single-repertoire buttons to a repertoire list that shows each repertoire with its stats and a context menu.
2. Controller and repository layers require no changes -- all CRUD methods are already implemented.
3. Deletion cascades in the database, so no extra cleanup is needed in the UI layer.
4. No unique constraint on names exists at the DB level, so duplicate name validation must be done in the dialog (comparing against the current list of repertoire names).
