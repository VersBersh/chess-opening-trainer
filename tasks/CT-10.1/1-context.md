# CT-10.1: Context

## Relevant Files

- **`src/lib/screens/free_practice_setup_screen.dart`** — The intermediate setup screen to be deleted. Contains `FreePracticeSetupState`, `FreePracticeSetupController` (provider), and the `FreePracticeSetupScreen` widget. Currently loads all cards, supports label filtering, and navigates to `DrillScreen` with `DrillConfig(isExtraPractice: true, preloadedCards: cards)`.

- **`src/lib/screens/home_screen.dart`** — Contains the `_startFreePractice(int repertoireId)` method that currently navigates to `FreePracticeSetupScreen`. This needs to be changed to navigate directly to `DrillScreen`. Also imports `free_practice_setup_screen.dart`.

- **`src/lib/screens/drill_screen.dart`** — The shared drill screen widget and its `DrillController`/`DrillConfig`. Currently, `DrillController.build()` uses `config.preloadedCards ?? getDueCardsForRepertoire(...)` to determine the card set. For direct Free Practice navigation, the `DrillController` must detect `isExtraPractice && preloadedCards == null` and call `getAllCardsForRepertoire()` instead of `getDueCardsForRepertoire()`.

- **`src/lib/repositories/review_repository.dart`** — Abstract interface for `ReviewRepository`, specifically the `getAllCardsForRepertoire(int)` method used to load all cards for free practice.

- **`src/lib/services/drill_engine.dart`** — The pure business-logic drill engine. Accepts a list of `ReviewCard` and a `RepertoireTreeCache`. Already supports `isExtraPractice` mode. No changes needed.

- **`src/lib/providers.dart`** — Global Riverpod providers for `repertoireRepositoryProvider` and `reviewRepositoryProvider`. The `DrillController` already reads from these providers.

- **`src/test/screens/free_practice_setup_screen_test.dart`** — Test file for the setup screen being removed. Must be deleted.

- **`src/test/screens/home_screen_test.dart`** — Tests for the home screen. Contains a test that asserts navigation to `FreePracticeSetupScreen`. Must be updated to assert navigation to `DrillScreen`.

- **`src/test/screens/drill_screen_test.dart`** — Existing drill screen tests including free practice tests. New tests for the Free Practice visual indicator should be added here.

## Architecture

The Free Practice flow currently works as follows:

1. **Home Screen** (`HomeScreen`): The `_startFreePractice(repertoireId)` method pushes `FreePracticeSetupScreen` via `Navigator.push`.

2. **Setup Screen** (`FreePracticeSetupScreen`): Loads all cards and the move tree via `FreePracticeSetupController`. Offers label-based filtering and two start buttons ("Start Practice" with filter, "Practice All"). Both push `DrillScreen` with `DrillConfig(repertoireId, preloadedCards: cards, isExtraPractice: true)`.

3. **Drill Screen** (`DrillScreen`/`DrillController`): Uses the `preloadedCards` from the config. When `isExtraPractice` is true, SM-2 updates are suppressed. Session summary shows "Practice Complete" and "no SR updates" when `isFreePractice` is true.

**Key constraint**: The `DrillController.build()` method currently falls back to `getDueCardsForRepertoire()` when `preloadedCards` is null. For free practice to work without the setup screen, the `DrillController` must detect `isExtraPractice && preloadedCards == null` and call `getAllCardsForRepertoire()` instead.

**Navigation pattern**: The app uses imperative `Navigator.push(MaterialPageRoute(...))` throughout. No named routing or go_router. The home screen refreshes its state via `.then((_) => refresh())` after popping back from a pushed screen.
