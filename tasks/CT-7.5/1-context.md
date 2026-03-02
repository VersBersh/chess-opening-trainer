# 1-context.md

## Relevant Files

### Specs
- `features/home-screen.md` -- Primary spec for the home screen. Defines per-repertoire list items with drill, free practice, and add line actions. Describes RepertoireSummary with `total_lines`, `due_count`, and `last_drilled_date`.
- `features/free-practice.md` -- Free Practice spec. Entry point is a per-repertoire button on the home screen, always available when the repertoire has cards.
- `features/add-line.md` -- Add Line spec. Navigation section specifies a per-repertoire "Add Line" action on the home screen.

### Source -- Screens
- `src/lib/screens/home_screen.dart` -- Current home screen. Contains `RepertoireSummary` (with `repertoire` and `dueCount` only, lacking `totalCardCount`), `HomeState`, `HomeController` (Riverpod AsyncNotifier), and `HomeScreen` widget. Currently uses a flat centered `Column` layout with four global buttons (Start Drill, Free Practice, Repertoire, Add Line). All buttons reference the first repertoire's ID. No per-repertoire card layout exists.
- `src/lib/screens/free_practice_setup_screen.dart` -- Free Practice setup screen. Navigation target for the Free Practice button. Takes `repertoireId` as constructor param. Provides label filtering and card count display.
- `src/lib/screens/add_line_screen.dart` -- Add Line screen. Navigation target for the Add Line button. Takes `db` (AppDatabase) and `repertoireId` as constructor params, with optional `startingMoveId`.
- `src/lib/screens/drill_screen.dart` -- Drill screen. Takes `DrillConfig` with `repertoireId`. Reference for navigation patterns and `DrillConfig` construction.
- `src/lib/screens/repertoire_browser_screen.dart` -- Repertoire browser. Takes `db` and `repertoireId`. Currently navigated to from the "Repertoire" button on the home screen.
- `src/lib/screens/settings_screen.dart` -- Settings screen, navigated to from the app bar.

### Source -- State & Infrastructure
- `src/lib/providers.dart` -- Riverpod providers for `RepertoireRepository`, `ReviewRepository`, `SharedPreferences`. All use throw-unless-overridden pattern.
- `src/lib/main.dart` -- App entry point. Creates `AppDatabase`, repo instances, wraps in `ProviderScope`. Passes `db` to `HomeScreen`.
- `src/lib/repositories/repertoire_repository.dart` -- Abstract interface. Key method: `getAllRepertoires()`.
- `src/lib/repositories/review_repository.dart` -- Abstract interface. Key methods: `getDueCardsForRepertoire(int)`, `getAllCardsForRepertoire(int)`.
- `src/lib/repositories/local/database.dart` -- Drift database schema. Defines `Repertoires`, `RepertoireMoves`, `ReviewCards` tables.

### Source -- Tests
- `src/test/screens/home_screen_test.dart` -- Existing home screen widget tests. Defines `FakeRepertoireRepository`, `FakeReviewRepository`, `buildTestApp()` helper. Tests due count display, button enable/disable, Free Practice navigation. Will need updating.
- `src/test/screens/free_practice_setup_screen_test.dart` -- Free Practice setup screen tests. Reference for test patterns with `buildLine()` and `buildReviewCard()` helpers.
- `src/test/screens/add_line_screen_test.dart` -- Add Line screen tests. Uses real in-memory `AppDatabase` for testing.

### Dev Data
- `src/lib/services/dev_seed.dart` -- Seeds one "Dev Openings" repertoire with 4 leaf nodes (all due). Only creates one repertoire, so the current single-repertoire home screen works by accident.

## Architecture

The home screen is the app's entry point and navigation hub, implemented as a `ConsumerStatefulWidget` backed by a Riverpod `AsyncNotifier` (`HomeController`). The controller loads all repertoires from `RepertoireRepository` and their due counts from `ReviewRepository`, packaging them into `List<RepertoireSummary>` within `HomeState`.

The current layout is a single centered `Column` with global action buttons that all reference the first repertoire's ID. This was a deliberate simplification in CT-1.4 (noted as "Multi-repertoire UI deferred"), but it now needs to evolve into a per-repertoire card list to support the three-action layout (Start Drill, Free Practice, Add Line) required by the spec.

Navigation is imperative (`Navigator.push` with `MaterialPageRoute`), and every navigation `.then()` callback calls `homeControllerProvider.notifier.refresh()` to update state on return.

Key constraint: `RepertoireSummary` currently only carries `dueCount`. The spec and acceptance criteria require knowing whether a repertoire has any cards at all (to enable/disable Free Practice), which means a `totalCardCount` field must be added.

The `AddLineScreen` requires an `AppDatabase` parameter (legacy pattern from before Riverpod migration), so `HomeScreen` still carries `widget.db` for navigation purposes.
