# CT-20.4 Context

## Relevant Files

### Production code

| File | Role |
|------|------|
| `src/lib/providers.dart` | Declares Riverpod providers for `RepertoireRepository`, `ReviewRepository`, and `SharedPreferences`. These throw at runtime unless overridden in a `ProviderScope`. |
| `src/lib/main.dart` | App entry point. Creates `AppDatabase`, constructs `LocalRepertoireRepository` and `LocalReviewRepository`, overrides providers in the root `ProviderScope`, and passes `db` to `HomeScreen`. |
| `src/lib/repositories/repertoire_repository.dart` | Abstract `RepertoireRepository` interface. |
| `src/lib/repositories/review_repository.dart` | Abstract `ReviewRepository` interface. |
| `src/lib/repositories/local/local_repertoire_repository.dart` | Concrete `LocalRepertoireRepository` backed by Drift/SQLite. |
| `src/lib/repositories/local/local_review_repository.dart` | Concrete `LocalReviewRepository` backed by Drift/SQLite. |
| `src/lib/repositories/local/database.dart` | Drift `AppDatabase` class and generated table definitions (`Repertoire`, `RepertoireMove`, `ReviewCard`, companions). |
| `src/lib/screens/home_screen.dart` | Home screen widget and `HomeController` (Riverpod `AsyncNotifier`). Widget accepts `AppDatabase db` in its constructor and passes it to child screens. `HomeController` correctly uses providers. |
| `src/lib/screens/repertoire_browser_screen.dart` | Repertoire browser. A plain `StatefulWidget` (not `ConsumerWidget`). Accepts `AppDatabase db` in its constructor. Directly constructs `LocalRepertoireRepository(widget.db)` and `LocalReviewRepository(widget.db)` in ~8 separate methods. |
| `src/lib/screens/add_line_screen.dart` | Add-line screen. A plain `StatefulWidget`. Accepts `AppDatabase db` and passes it to `AddLineController`. |
| `src/lib/controllers/add_line_controller.dart` | Business logic controller for add-line flow. A `ChangeNotifier` that accepts `AppDatabase` and constructs `LocalRepertoireRepository(_db)` and `LocalReviewRepository(_db)` internally in ~5 methods. |
| `src/lib/services/pgn_importer.dart` | PGN import service. Accepts `AppDatabase` directly (documented rationale: per-game transactions). Constructs `LocalRepertoireRepository(_db)` and `LocalReviewRepository(_db)` internally. |
| `src/lib/screens/import_screen.dart` | Import screen. Accepts `AppDatabase db` and passes it to `PgnImporter`. |
| `src/lib/screens/drill_screen.dart` | Drill screen. Does NOT accept `AppDatabase`; uses Riverpod providers correctly. Serves as the reference pattern. |

### Architecture specs

| File | Role |
|------|------|
| `architecture/state-management.md` | Defines the Riverpod-based DI and state-management rules. Key principle: "Widgets never call repositories directly" and "Dependency injection is explicit." |
| `architecture/repository.md` | Defines the abstract `RepertoireRepository` / `ReviewRepository` interfaces and the local Drift implementation behind them. |

### Test files

| File | Role |
|------|------|
| `src/test/screens/home_screen_test.dart` | Tests for `HomeScreen`. Uses `FakeRepertoireRepository` / `FakeReviewRepository` via provider overrides. Also passes an in-memory `AppDatabase` to `HomeScreen(db: ...)` for navigation tests. |
| `src/test/screens/repertoire_browser_screen_test.dart` | Tests for `RepertoireBrowserScreen`. Uses a real `AppDatabase(NativeDatabase.memory())` and passes it to the widget's `db` constructor. The screen internally constructs `LocalRepertoireRepository` / `LocalReviewRepository` from that `db`. |
| `src/test/controllers/add_line_controller_test.dart` | Unit tests for `AddLineController`. Uses a real in-memory `AppDatabase` passed directly to the controller constructor. |
| `src/test/screens/add_line_screen_test.dart` | Widget tests for `AddLineScreen`. Uses a real in-memory `AppDatabase` passed to the widget's `db` constructor. |
| `src/test/screens/import_screen_test.dart` | Widget tests for `ImportScreen`. Uses a real in-memory `AppDatabase` passed to the widget's `db` constructor. |
| `src/test/services/pgn_importer_test.dart` | Unit tests for `PgnImporter`. Uses a real in-memory `AppDatabase` passed to `PgnImporter(db: ...)`. |

## Architecture

### Current design

The app uses Riverpod for dependency injection. At startup (`main.dart`), the `AppDatabase` is created, `LocalRepertoireRepository` and `LocalReviewRepository` are constructed from it, and both are provided as `Provider<RepertoireRepository>` and `Provider<ReviewRepository>` overrides in the root `ProviderScope`.

The **intended** data flow (per `architecture/state-management.md`) is:

```
Repository (provided via Riverpod)
    |
    v
Controller / Notifier (reads repository via ref.read)
    |
    v
Widget (reads state from controller, dispatches actions)
```

### Where the architecture is followed

- **`HomeController`** (in `home_screen.dart`) is a Riverpod `AsyncNotifier` that reads `repertoireRepositoryProvider` and `reviewRepositoryProvider` via `ref.read`. This is the correct pattern.
- **`DrillScreen` / `DrillController`** use Riverpod providers for repository access. No `AppDatabase` constructor parameter.

### Where the architecture is violated

1. **`HomeScreen` widget** accepts `AppDatabase db` in its constructor solely to forward it to child screens (`AddLineScreen`, `RepertoireBrowserScreen`). The `HomeController` itself does not use `db` -- it uses providers. The `db` parameter exists only for prop-drilling.

2. **`RepertoireBrowserScreen`** accepts `AppDatabase db` and constructs `LocalRepertoireRepository(widget.db)` / `LocalReviewRepository(widget.db)` directly in at least 8 places across `_loadData()`, `_onEditLabelForMove()`, `_deleteMoveAndGetParent()`, `_onDeleteBranch()`, `_handleOrphans()`, `_showOrphanPrompt()`, and the Import/AddLine navigation handlers. It is a plain `StatefulWidget`, not a `ConsumerWidget`.

3. **`AddLineScreen`** accepts `AppDatabase db` and passes it to `AddLineController`.

4. **`AddLineController`** is a `ChangeNotifier` that stores `AppDatabase _db` and constructs `LocalRepertoireRepository(_db)` / `LocalReviewRepository(_db)` in `loadData()`, `_persistMoves()`, `undoExtension()`, and `updateLabel()`.

5. **`ImportScreen`** accepts `AppDatabase db` and passes it to `PgnImporter(db: widget.db)`.

6. **`PgnImporter`** accepts `AppDatabase` directly and constructs local repositories internally. The documented rationale is "per-game transactions", but this couples the service to the concrete database implementation and bypasses the repository abstraction.

### Key constraints

- `PgnImporter` uses `_db.transaction()` for per-game atomicity. The refactored design must preserve this capability. The simplest approach is to have `PgnImporter` accept repository interfaces but continue receiving the `AppDatabase` for transaction scoping, or to move the transaction boundary into the repository.
- `RepertoireBrowserScreen` is not currently a `ConsumerWidget` / `ConsumerStatefulWidget`. Converting it is part of this task.
- Navigation to child screens (`AddLineScreen`, `ImportScreen`) currently passes `widget.db`. After refactoring, these child screens will read repositories from the Riverpod scope instead.
- The `HomeScreen` tests already use fake repositories via provider overrides but also create a real `AppDatabase` for navigation tests. After removing `db` from widget constructors, the tests that verify navigation to child screens must be updated.
