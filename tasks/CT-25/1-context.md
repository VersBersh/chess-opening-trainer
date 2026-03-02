# 1-context.md

## Relevant Files

- **`src/lib/screens/drill_screen.dart`** -- The 1261-line file to split. Contains DrillConfig, DrillScreenState sealed hierarchy, SessionSummary data class, drillControllerProvider declaration, DrillController (Riverpod async notifier), DrillScreen widget, and _DrillFilterAutocomplete widget.
- **`src/lib/controllers/add_line_controller.dart`** -- Reference pattern for extracting a controller to `controllers/`. Uses ChangeNotifier with co-located state class.
- **`src/lib/controllers/repertoire_browser_controller.dart`** -- Second reference pattern for controller extraction. Also uses ChangeNotifier with co-located state/result classes.
- **`src/lib/models/repertoire.dart`** -- Reference pattern for a model file (RepertoireTreeCache). Shows the convention for the `models/` directory.
- **`src/lib/models/review_card.dart`** -- Reference for a small model file (DrillSession, DrillCardState data classes).
- **`src/lib/services/drill_engine.dart`** -- Pure business-logic service consumed by DrillController. Contains MoveResult sealed types and CardResult. Exports `QualityBucket` from sm2_scheduler.
- **`src/lib/providers.dart`** -- Central Riverpod provider declarations. Currently does NOT host drillControllerProvider (it lives in drill_screen.dart).
- **`src/lib/theme/drill_feedback_theme.dart`** -- DrillFeedbackTheme extension used by both the session-complete summary widget and the active-drill feedback rendering.
- **`src/lib/screens/home_screen.dart`** -- Imports DrillScreen and DrillConfig from drill_screen.dart. Navigation call-site.
- **`src/lib/screens/add_line_screen.dart`** -- Reference pattern for how a screen file imports its controller from `controllers/`.
- **`src/lib/screens/repertoire_browser_screen.dart`** -- Reference pattern for a screen that imports its controller from `controllers/`.
- **`src/test/screens/drill_screen_test.dart`** -- Widget tests that import `drill_screen.dart` and reference DrillScreen, DrillConfig, drillControllerProvider, and DrillSessionComplete.
- **`src/test/screens/drill_filter_test.dart`** -- Widget tests for drill filter that import `drill_screen.dart` and reference DrillScreen, DrillConfig, drillControllerProvider.
- **`src/test/screens/home_screen_test.dart`** -- Imports DrillScreen for navigation verification.

## Architecture

The drill subsystem handles spaced-repetition practice sessions. The architecture has three tiers:

1. **DrillEngine** (`services/drill_engine.dart`) -- Pure business logic. Manages card queues, validates user moves, tracks mistakes, computes SM-2 scoring. No Flutter/Riverpod dependencies.

2. **DrillController** (`screens/drill_screen.dart`, lines 177-607) -- Riverpod `AutoDisposeFamilyAsyncNotifier<DrillScreenState, DrillConfig>`. Bridges DrillEngine with repository persistence and UI state. Owns a `ChessboardController`, manages async intro animations, mistake revert timing, pass accumulation for free-practice mode, and label-based filtering. Unlike `AddLineController` and `RepertoireBrowserController` (which use `ChangeNotifier`), DrillController uses Riverpod's family notifier pattern with the provider declared at module scope.

3. **DrillScreen** (`screens/drill_screen.dart`, lines 613-1261) -- `ConsumerWidget` that watches `drillControllerProvider(config)` and renders different UI for each `DrillScreenState` variant: loading, card-start, user-turn, mistake-feedback, pass-complete, session-complete, and filter-no-results.

Key constraints:
- **DrillConfig** is the Riverpod family key. It must be importable by both the controller and the screen, plus by call-sites like home_screen.dart.
- **drillControllerProvider** is the bridge between controller and screen. Its type signature references both `DrillController`, `DrillScreenState`, and `DrillConfig`.
- **DrillScreenState sealed hierarchy** is the shared contract between controller (producer) and screen (consumer). The controller sets `state = AsyncData(SomeVariant(...))` and the screen pattern-matches on it.
- The **_DrillFilterAutocomplete** stateful widget is private to drill_screen.dart and only used within `DrillScreen._buildFilterBox`.
- Test files access `drillControllerProvider` to drive the controller directly in integration-style widget tests.
