# CT-10.1: Implementation Notes

## Files Modified

- **`src/lib/screens/drill_screen.dart`** -- Updated `DrillController.build()` to call `getAllCardsForRepertoire` when `isExtraPractice` is true and no `preloadedCards` are provided; added shuffle for free practice mode; changed AppBar titles at locations A (async loading), B (async error), C (DrillLoading), and D (DrillCardStart/DrillUserTurn/DrillMistakeFeedback) to show "Free Practice" when `config.isExtraPractice` is true.

- **`src/lib/screens/home_screen.dart`** -- Changed `_startFreePractice` to navigate directly to `DrillScreen` with `DrillConfig(repertoireId, isExtraPractice: true)` instead of `FreePracticeSetupScreen`; removed `free_practice_setup_screen.dart` import.

- **`src/test/screens/home_screen_test.dart`** -- Removed `free_practice_setup_screen.dart` import; renamed test from "tapping Free Practice navigates to setup screen" to "tapping Free Practice navigates to drill screen" and changed assertion from `FreePracticeSetupScreen` to `DrillScreen`.

- **`src/test/screens/drill_screen_test.dart`** -- Extended `FakeReviewRepository` to support separate `_dueCards` and `_allCards` lists (matching the pattern in `home_screen_test.dart`); added two new tests in the free practice group: one verifying that free practice without `preloadedCards` loads all cards via `getAllCardsForRepertoire`, and one verifying the "Free Practice" AppBar title indicator.

## Files Deleted

- **`src/lib/screens/free_practice_setup_screen.dart`** -- Entire file removed (dead code after navigation change).
- **`src/test/screens/free_practice_setup_screen_test.dart`** -- Entire test file removed (tests the deleted screen).

## Deviations from Plan

None. All 11 steps were implemented as specified.

## Follow-up Work

- **CT-10.2**: Will re-add inline label filtering directly on the drill screen. The filtering logic previously in `FreePracticeSetupController` can be referenced from git history.
- **Shuffle determinism in tests**: The shuffle in Step 2 uses `List.shuffle()` with the default random source. This is fine for production but could theoretically cause test flakiness if a test depends on card order. The new tests do not depend on order (single-card scenarios), so this is not an issue currently.
