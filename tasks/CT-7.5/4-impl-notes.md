# 4-impl-notes.md

## Files Modified

### `src/lib/screens/home_screen.dart`
- Added `totalCardCount` field to `RepertoireSummary` class.
- Updated `HomeController._load()` to call `reviewRepo.getAllCardsForRepertoire()` and populate `totalCardCount`.
- Refactored `_onAddLineTap()` and `_onRepertoireTap()` from async methods using `openRepertoire()` to sync methods accepting a `repertoireId` parameter directly.
- Replaced flat `Column` layout in `_buildData()` with routing to either `_buildEmptyState()` or `_buildRepertoireList()`.
- Added `_buildRepertoireList()`: renders global "X cards due" header and a per-repertoire `Card` for each `RepertoireSummary`.
- Added `_buildRepertoireCard()`: renders header row (tappable repertoire name + due badge) and action row with Start Drill (`FilledButton.icon`), Free Practice (`OutlinedButton.icon`), and Add Line (`OutlinedButton.icon`). Start Drill is always tappable but shows a `SnackBar` when `dueCount == 0` and uses muted styling. Free Practice is disabled when `totalCardCount == 0`.
- Added `_buildEmptyState()`: onboarding UI with explanation text and "Create your first repertoire" button.
- Added `_onCreateFirstRepertoire()`: uses `openRepertoire()` for auto-create, then navigates to `RepertoireBrowserScreen`. Includes `TODO(CT-next)` comment for name-entry dialog.
- Removed the global `'Repertoire'` and `'Add Line'` buttons entirely.

### `src/test/screens/home_screen_test.dart`
- Added `drift/drift.dart` import (with `hide isNull, isNotNull`) for `RepertoiresCompanion.insert` usage in DB-seeding tests.
- Added imports for `AddLineScreen`, `DrillScreen`, and `RepertoireBrowserScreen` for navigation assertions.
- Updated `FakeReviewRepository` to accept separate `allCards` and `dueCards` collections. Default: `allCards` falls back to `dueCards` if not provided, preserving backward compatibility.
- Replaced "disables Start Drill button when no cards due" test with "Start Drill shows snackbar when no cards due" -- verifies `onPressed` is not null and SnackBar appears on tap.
- Replaced "Free Practice button is enabled when repertoire exists" with "Free Practice is enabled when repertoire has cards" -- now provides `allCards` with cards.
- Replaced "Free Practice button is disabled when no repertoire exists" with two tests: "Free Practice is disabled when repertoire has no cards" and "empty state shows Create your first repertoire button when no repertoires exist".
- Updated "tapping Free Practice navigates to setup screen" to provide `allCards` so the button is enabled.
- Removed "shows Repertoire button" test group (global button no longer exists).
- Added new test group "HomeScreen -- per-repertoire card layout" with 8 tests:
  - Each repertoire card shows Start Drill, Free Practice, and Add Line buttons (two-repertoire setup).
  - Start Drill shows snackbar when dueCount == 0.
  - Start Drill navigates to DrillScreen when dueCount > 0.
  - Free Practice is enabled when repertoire has cards but none due.
  - Free Practice is disabled when repertoire has no cards.
  - Tapping Add Line navigates to AddLineScreen (seeds in-memory DB).
  - Tapping repertoire name navigates to RepertoireBrowserScreen (seeds in-memory DB).
  - Empty state shows CTA button and no repertoire cards.

## Deviations from Plan

None. All five steps were implemented as specified.

## Follow-up Work

- **CT-next: Name-entry dialog for repertoire creation.** The `_onCreateFirstRepertoire()` method uses `openRepertoire()` which auto-creates "My Repertoire". A `TODO(CT-next)` comment marks where a proper name-entry dialog should replace this.
- **Performance: `getCardCountForRepertoire`.** The current implementation loads all card objects just to count them. A dedicated count query could be added later (noted in plan as Risk 3).
