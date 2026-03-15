# CT-63: Context

## Relevant Files

- **`src/lib/screens/home_screen.dart`** — Main home screen widget. Already contains `_showCreateRepertoireDialog()` used for empty-state creation. Currently renders single-repertoire layout with inline action buttons. Must be extended for rename/delete dialogs and multi-repertoire list.

- **`src/lib/controllers/home_controller.dart`** — `HomeController` (AsyncNotifier) with `HomeState` and `RepertoireSummary`. Already has `createRepertoire()`, `renameRepertoire()`, and `deleteRepertoire()` methods. No controller changes needed.

- **`src/lib/repositories/repertoire_repository.dart`** — Abstract interface with `saveRepertoire()`, `deleteRepertoire()`, `renameRepertoire()`, `getAllRepertoires()`. All CRUD operations already defined.

- **`src/lib/repositories/local/local_repertoire_repository.dart`** — Concrete Drift-based implementation. `deleteRepertoire` uses `ON DELETE CASCADE`. No unique constraint on repertoire names.

- **`src/lib/repositories/local/database.dart`** — Drift schema. `Repertoires` table has `id` (autoincrement) and `name` (text, no unique constraint).

- **`src/lib/widgets/repertoire_card.dart`** — Pre-built `RepertoireCard` widget with `onRename` and `onDelete` callbacks, `PopupMenuButton` with "Rename" and "Delete" options, due-count badge, and inline action buttons. Currently not imported or used anywhere.

- **`src/lib/widgets/home_empty_state.dart`** — Empty-state widget for zero repertoires. No changes needed.

- **`src/lib/widgets/repertoire_dialogs.dart`** — Existing dialog helpers (`showDeleteConfirmationDialog`, etc.) demonstrating the codebase's dialog pattern: free functions returning `Future<T?>` via `showDialog`.

- **`src/lib/providers.dart`** — Riverpod provider declarations including `repertoireRepositoryProvider` and `reviewRepositoryProvider`.

- **`src/test/screens/home_screen_test.dart`** — Existing widget tests with `FakeRepertoireRepository`, `FakeReviewRepository`, `buildTestApp` helper. Tests for empty state, due counts, button navigation, and the create dialog.

- **`src/test/widgets/repertoire_dialogs_test.dart`** — Existing dialog widget tests using `DialogResultHolder` pattern and `pumpDialog` helper.

- **`features/home-screen.md`** — Feature spec documenting single-repertoire layout, CRUD operations, and onboarding.

## Architecture

Three-layer architecture:

1. **Repository layer** (`RepertoireRepository` / `LocalRepertoireRepository`) — raw CRUD operations against SQLite via Drift. Deletion cascades through foreign keys.

2. **Controller layer** (`HomeController`) — `AutoDisposeAsyncNotifier` loading all repertoires plus review card summaries into `HomeState` containing `List<RepertoireSummary>`. Exposes `createRepertoire()`, `renameRepertoire()`, and `deleteRepertoire()`.

3. **Screen layer** (`HomeScreen`) — `ConsumerStatefulWidget` watching `homeControllerProvider`. Renders empty state or action-button layout based on `homeState.repertoires`.

Key constraints:
- Controller already has all three CRUD methods — task is purely UI.
- No unique constraint on repertoire names in the database — duplicate handling must be at the UI layer.
- `RepertoireCard` widget exists with correct callbacks but is unused.
- Existing `_showCreateRepertoireDialog()` demonstrates the dialog pattern: `Future<String?>`, `StatefulBuilder` for reactive validation, disabled confirm when invalid.
