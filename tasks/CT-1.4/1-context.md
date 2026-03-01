# CT-1.4 Context

## Relevant Files

### Specs
- `features/home-screen.md` — Primary spec: repertoire list, per-repertoire drill button, navigation, CRUD, onboarding, reactive due counts
- `features/drill-mode.md` — Drill mode spec: how drill session is entered from home screen
- `architecture/state-management.md` — Riverpod architecture: widgets never call repos directly, HomeController pattern with `List<RepertoireSummary>`
- `architecture/models.md` — Domain models: Repertoire, ReviewCard, transient RepertoireSummary

### Source — Screens
- `src/lib/screens/home_screen.dart` — Current home screen: StatefulWidget with direct `AppDatabase` dependency. Creates `LocalRepertoireRepository` / `LocalReviewRepository` inline. Shows global due count, "Start Drill" button (refreshes on return), "Repertoire" button (does NOT refresh on return). Drill button disabled when `_dueCount == 0`.
- `src/lib/screens/drill_screen.dart` — Drill screen: ConsumerWidget using Riverpod. Takes `repertoireId` constructor param. Uses `drillControllerProvider(repertoireId)` family provider. Reference for the correct Riverpod pattern.
- `src/lib/screens/repertoire_browser_screen.dart` — Repertoire browser: StatefulWidget receiving `AppDatabase` and `repertoireId`. Not yet migrated to Riverpod.

### Source — Repositories
- `src/lib/repositories/repertoire_repository.dart` — Abstract interface. Key: `getAllRepertoires()`, `getMovesForRepertoire(int)`, `countLeavesInSubtree(int)`
- `src/lib/repositories/review_repository.dart` — Abstract interface. Key: `getDueCards()`, `getDueCardsForRepertoire(int)`, `getAllCardsForRepertoire(int)`
- `src/lib/repositories/local/local_repertoire_repository.dart` — Concrete Drift-backed implementation
- `src/lib/repositories/local/local_review_repository.dart` — Concrete Drift-backed implementation

### Source — App Infrastructure
- `src/lib/main.dart` — Entry point. Creates `AppDatabase`, repo instances, calls `seedDevData()` in debug mode, wraps in `ProviderScope` with repo overrides. Defines `repertoireRepositoryProvider` and `reviewRepositoryProvider` (throw-unless-overridden pattern). Passes `AppDatabase` to `HomeScreen`.
- `src/lib/services/dev_seed.dart` — Dev seed function: seeds "Dev Openings" repertoire with branching tree (4 leaf nodes), all cards due today. Idempotent.

### Source — Tests
- `src/test/screens/drill_screen_test.dart` — Drill screen widget tests. Defines `FakeRepertoireRepository`, `FakeReviewRepository`, `buildTestApp()` helper with ProviderScope overrides. Reusable test infrastructure.

## Architecture

The home screen is the app's entry point and navigation hub. Currently implemented as a StatefulWidget that directly instantiates concrete repository implementations from a passed `AppDatabase` — violating the state-management spec principle that "widgets never call repositories directly."

The prescribed architecture (from `architecture/state-management.md`):

```
ReviewRepository + RepertoireRepository
    │
    ▼
HomeController (Riverpod AsyncNotifier)
    │  - Loads repertoires and due counts
    │  - Exposes: List<RepertoireSummary>
    │  - Handles: refresh(), startDrill()
    │
    ▼
HomeScreen widget (ConsumerWidget / ConsumerStatefulWidget)
    │  - Reads state from controller via ref.watch
    │  - Dispatches actions to controller
    │  - Never imports repository classes
```

Riverpod infrastructure is already in place: `ProviderScope` in `main.dart`, repository providers defined. The DrillScreen uses this pattern correctly. The HomeScreen is the remaining screen to migrate.

**Key constraints:**
- `RepertoireBrowserScreen` still takes `AppDatabase` directly (not migrated to Riverpod). Home screen needs to pass `db` when navigating to it.
- The spec calls for reactive due counts via Drift `watch` queries, but manual refresh (`.then()` on nav return) is sufficient for CT-1.4 acceptance criteria. Reactive streams are a future enhancement.
- Dev seed function is already complete and meets all acceptance criteria.
