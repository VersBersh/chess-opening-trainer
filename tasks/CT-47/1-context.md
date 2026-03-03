# CT-47: Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/screens/home_screen.dart` | Primary file to modify. Contains `HomeScreen` widget with repertoire list, FAB, rename/delete dialogs, and navigation callbacks for drill, free practice, add line, and repertoire browser. |
| `src/lib/controllers/home_controller.dart` | `HomeController` (AsyncNotifier) that loads `HomeState` containing `List<RepertoireSummary>` and `totalDueCount`. Provides `createRepertoire`, `renameRepertoire`, `deleteRepertoire`, `refresh`. Must be preserved. |
| `src/lib/widgets/repertoire_card.dart` | `RepertoireCard` widget displaying per-repertoire header (name, due badge, context menu) and action buttons (Start Drill, Free Practice, Add Line). Will become unused after this change. |
| `src/lib/widgets/home_empty_state.dart` | `HomeEmptyState` widget for zero-repertoire onboarding. Shows explanation text and "Create your first repertoire" button. Kept as-is. |
| `src/lib/screens/drill_screen.dart` | Navigation target for Start Drill and Free Practice. Accepts `DrillConfig(repertoireId, isExtraPractice)`. |
| `src/lib/screens/repertoire_browser_screen.dart` | Navigation target for Manage Repertoire. Accepts `repertoireId` as constructor parameter. |
| `src/lib/screens/add_line_screen.dart` | Currently navigated to from the old Add Line button. The new home screen drops this button (users reach it via the repertoire browser). |
| `src/lib/providers.dart` | Riverpod providers for `repertoireRepositoryProvider`, `reviewRepositoryProvider`, etc. |
| `src/test/screens/home_screen_test.dart` | Extensive widget tests covering due counts, button states, navigation, CRUD dialogs, FAB, and empty state. Must be substantially rewritten. |
| `features/home-screen.md` | Feature spec defining the single-repertoire three-button layout, onboarding, and navigation targets. |

## Architecture

The home screen subsystem follows a controller + state pattern using Riverpod:

1. **HomeController** (`AsyncNotifier`) loads all repertoires from `RepertoireRepository.getAllRepertoires()` and their summary counts from `ReviewRepository.getRepertoireSummaries()`. It produces a `HomeState` containing a list of `RepertoireSummary` objects (each with a `Repertoire`, `dueCount`, and `totalCardCount`) and a `totalDueCount`.

2. **HomeScreen** (`ConsumerStatefulWidget`) watches `homeControllerProvider` and renders based on the async state: loading spinner, error with retry, or data. When data is available, it branches on `homeState.repertoires.isEmpty` to show either `HomeEmptyState` or a scrollable list of `RepertoireCard` widgets plus a FAB.

3. **RepertoireCard** is a per-repertoire widget containing: a name header with due badge and popup menu (rename/delete), and three action buttons (Start Drill, Free Practice, Add Line). Navigation callbacks (`_startDrill`, `_startFreePractice`, `_onAddLineTap`, `_onRepertoireTap`) are defined in `_HomeScreenState` and passed down.

4. **Navigation** uses imperative `Navigator.push()` with `MaterialPageRoute`. After returning from any pushed screen, `refresh()` is called on the controller to update counts.

**Key constraints:**
- The `HomeController` and all repository CRUD methods must be preserved for future multi-repertoire support.
- The empty state (zero repertoires) with the "Create your first repertoire" flow must continue to work.
- The "first repertoire" is determined by creation order (the first element of `getAllRepertoires()`).
