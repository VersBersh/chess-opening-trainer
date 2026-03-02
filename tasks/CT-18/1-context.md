# CT-18: Context

## Relevant Files

- **`src/lib/screens/home_screen.dart`** -- The file to decompose. Currently 522 lines containing four concerns: data models (`RepertoireSummary`, `HomeState`), the Riverpod controller (`HomeController`, `homeControllerProvider`), the screen widget (`HomeScreen` / `_HomeScreenState` with navigation, dialogs, and composition), and extracted widget builders (`_buildRepertoireCard`, `_buildEmptyState`).

- **`src/lib/controllers/add_line_controller.dart`** -- Reference pattern for controller decomposition. Contains `AddLineState` (immutable state), sealed result types, and `AddLineController extends ChangeNotifier` in a single controller file. The corresponding screen file (`add_line_screen.dart`) imports the controller and focuses on widget composition.

- **`src/lib/controllers/repertoire_browser_controller.dart`** -- Second reference pattern for controller decomposition. Contains `RepertoireBrowserState` (with `copyWith`), auxiliary data types (`BranchDeleteInfo`, `OrphanChoice`), and `RepertoireBrowserController extends ChangeNotifier`. The screen file imports it and handles only widget building and dialog presentation.

- **`src/lib/screens/add_line_screen.dart`** -- Reference for how a screen file looks after controller extraction. Imports from `../controllers/add_line_controller.dart`, instantiates the controller in `initState`, and contains only widget building methods and thin event handlers that delegate to the controller.

- **`src/lib/screens/repertoire_browser_screen.dart`** -- Second reference for screen-after-extraction pattern. Same structure as `add_line_screen.dart`: imports controller, builds UI, shows dialogs, delegates logic.

- **`src/lib/screens/drill_screen.dart`** -- Counter-example: a screen that has NOT been decomposed. Contains its controller (`DrillController`), state, config, and widget all in one ~900-line file. Uses Riverpod `AsyncNotifier` pattern (same as `HomeController`), unlike the `ChangeNotifier` pattern used by the other two extracted controllers.

- **`src/lib/providers.dart`** -- Central Riverpod provider declarations. `homeControllerProvider` is currently defined in `home_screen.dart`, not here. After extraction, the provider must be accessible to both the controller file and the screen file.

- **`src/lib/main.dart`** -- App entry point. Imports `home_screen.dart` and uses `HomeScreen` as the root widget. The import path will need to remain valid after the split.

- **`src/test/screens/home_screen_test.dart`** -- 1131-line test file. Imports `home_screen.dart` to access `HomeScreen`, `homeControllerProvider`, and `HomeController`. After the split, tests will need to import from the new file locations. Tests reference `homeControllerProvider` directly for refresh calls.

- **`features/home-screen.md`** -- Feature specification for the home screen. Defines the domain model (`RepertoireSummary`), repertoire list display, CRUD operations, empty state / onboarding, and navigation targets. Useful as the authoritative reference for what belongs to the controller vs. what belongs to the UI.

## Architecture

The home screen is the app's entry point. It loads a list of repertoire summaries (with due-card counts), renders them as cards, handles navigation to drill/browser/add-line screens, and provides repertoire CRUD via dialogs.

The current file mixes three distinct responsibilities:

1. **State management** -- `HomeState`, `RepertoireSummary`, `HomeController` (an `AutoDisposeAsyncNotifier<HomeState>`), and the `homeControllerProvider` Riverpod provider. The controller loads data from `RepertoireRepository` and `ReviewRepository`, and exposes `refresh()`, `createRepertoire()`, `renameRepertoire()`, and `deleteRepertoire()` methods.

2. **Per-card widget rendering** -- `_buildRepertoireCard` is a 112-line method that renders a Card with a header row (name, due badge, popup menu), an action row (Start Drill, Free Practice, Add Line), and wires up context menu actions for rename/delete through dialogs.

3. **Empty-state / onboarding widget** -- `_buildEmptyState` is a 30-line method that renders a centered column with an icon, explanatory text, and a "Create your first repertoire" button that triggers a dialog-then-navigate flow.

The codebase has an established decomposition pattern: controllers go in `src/lib/controllers/`, screen widgets stay in `src/lib/screens/`, and reusable widgets go in `src/lib/widgets/`. The two existing controllers (`AddLineController`, `RepertoireBrowserController`) both use `ChangeNotifier`, while `HomeController` uses Riverpod's `AsyncNotifier`. This is an important distinction -- the `HomeController` extraction keeps the Riverpod provider pattern and does not convert to `ChangeNotifier`.

Key constraints:
- `homeControllerProvider` must remain accessible to both the controller file and the screen file. It is currently defined alongside `HomeController` in the same file, which is the natural Riverpod pattern (provider next to its notifier class).
- `DrillConfig` is imported from `drill_screen.dart` by the home screen. The new `RepertoireCard` widget will need this import to create `DrillConfig` instances for navigation.
- The CRUD dialogs (`_showCreateRepertoireDialog`, `_showRenameRepertoireDialog`, `_showDeleteRepertoireDialog`) are only used within `_HomeScreenState` and should remain in `home_screen.dart` since they are tightly coupled to the screen's `BuildContext` and navigation flow.
- Tests import `home_screen.dart` and directly reference `HomeScreen`, `homeControllerProvider`, and the `HomeController` notifier. Barrel exports or re-exports from the screen file can maintain backward compatibility.
