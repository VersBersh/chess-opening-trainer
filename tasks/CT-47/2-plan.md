# CT-47: Implementation Plan (Revised)

## Goal

Replace the multi-repertoire card list on the home screen with three direct action buttons (Start Drill, Free Practice, Manage Repertoire) that operate on the first repertoire, removing the repertoire name display, rename/delete UI, and FAB while preserving the controller, repositories, and empty-state onboarding.

## Steps

### Step 1: Add deterministic ordering to `getAllRepertoires()`

**File:** `src/lib/repositories/local/local_repertoire_repository.dart`

The current `getAllRepertoires()` implementation calls `_db.select(_db.repertoires).get()` with no `ORDER BY`. The plan relies on `.first` to select the active repertoire, so ordering must be deterministic.

Change the method to:

```dart
@override
Future<List<Repertoire>> getAllRepertoires() {
  return (_db.select(_db.repertoires)
        ..orderBy([(r) => OrderingTerm.asc(r.id)]))
      .get();
}
```

This guarantees the first element is the earliest-created repertoire (lowest autoincrement ID), matching the feature spec's "first repertoire by creation order" contract. No interface change is required.

### Step 2: Simplify `_buildData` -- remove FAB and card list, add three-button layout

**File:** `src/lib/screens/home_screen.dart`

In `_buildData()`:
- Remove the `floatingActionButton` property entirely.
- Keep the empty-state branch (`homeState.repertoires.isEmpty ? HomeEmptyState(...) : ...`).
- Replace the call to `_buildRepertoireList(context, homeState)` with a new method `_buildActionButtons(context, homeState)`.

### Step 3: Implement `_buildActionButtons` method

**File:** `src/lib/screens/home_screen.dart`

Create `_buildActionButtons(BuildContext context, HomeState homeState)`:
- Extract the first repertoire summary: `final summary = homeState.repertoires.first;`
- Extract `repertoireId = summary.repertoire.id`, `hasDueCards = summary.dueCount > 0`, `hasCards = summary.totalCardCount > 0`.
- Build a centered `Column` with padding, containing:
  - Due count headline using `summary.dueCount` (not `homeState.totalDueCount`)
  - Three full-width buttons:

  1. **Start Drill** -- `FilledButton.icon` with `Icons.play_arrow`. Tappable always (onPressed is non-null), but visually muted when `!hasDueCards` (using reduced-alpha background color, same pattern as `RepertoireCard`). When tapped with no due cards, show the snackbar "No cards due for review. Come back later!" instead of navigating. When tapped with due cards, call `_startDrill(repertoireId)`.

  2. **Free Practice** -- `OutlinedButton.icon` with `Icons.fitness_center`. `onPressed` is `hasCards ? () => _startFreePractice(repertoireId) : null` (disabled when no cards).

  3. **Manage Repertoire** -- `OutlinedButton.icon` with `Icons.library_books`. `onPressed` calls `_onRepertoireTap(repertoireId)`. Always enabled when a repertoire exists.

**Depends on:** Step 2.

### Step 4: Remove unused dialog methods, callbacks, and imports

**File:** `src/lib/screens/home_screen.dart`

Remove:
- `_showRenameRepertoireDialog`
- `_showDeleteRepertoireDialog`
- `_onAddLineTap`
- `_buildRepertoireList`
- Import for `repertoire_card.dart`
- Import for `add_line_screen.dart`

Keep:
- `_showCreateRepertoireDialog` (used by `_onCreateFirstRepertoire`)
- `_startDrill`, `_startFreePractice`, `_onRepertoireTap`, `_onCreateFirstRepertoire`

**Depends on:** Steps 2, 3.

### Step 5: Update tests -- remove tests for deleted UI elements

**File:** `src/test/screens/home_screen_test.dart`

Remove or rewrite test groups that test removed UI:
- Tests asserting multiple repertoire names, Card widgets, Add Line button
- FAB create flow tests
- Context menu / Rename dialog tests
- Delete dialog tests
- Tests referencing `PopupMenuButton`, `FloatingActionButton`, `Card`, or `'Add Line'`

**Depends on:** Steps 1-4.

### Step 6: Update tests -- revise existing tests and add new ones for new layout

**File:** `src/test/screens/home_screen_test.dart`

Add/revise tests:
1. **Three buttons visible:** Assert `find.text('Start Drill')`, `find.text('Free Practice')`, `find.text('Manage Repertoire')` each `findsOneWidget`.
2. **No Card or FAB:** Assert `find.byType(Card)` and `find.byType(FloatingActionButton)` are `findsNothing`.
3. **Manage Repertoire navigates to browser:** Tap "Manage Repertoire", assert `find.byType(RepertoireBrowserScreen)` appears.
4. **Start Drill navigates to DrillScreen when due cards exist:** Set up repertoire with due cards, tap "Start Drill", assert `find.byType(DrillScreen)` appears.
5. **Start Drill shows snackbar when no due cards:** Tap "Start Drill" when `dueCount == 0`, assert snackbar text appears and no navigation. Focus on behavior, not style assertions.
6. **Free Practice navigates to DrillScreen when cards exist:** Set up repertoire with cards, tap "Free Practice", assert `find.byType(DrillScreen)` appears.
7. **Free Practice disabled when no cards:** Verify still passes.
8. **Due count uses per-repertoire count:** Assert displayed count matches `summary.dueCount`.
9. **Loading/error and empty-state tests:** Adjust as needed.

**Depends on:** Step 5.

## Risks / Open Questions

1. **"Manage Repertoire" icon:** The spec doesn't specify an icon. `Icons.library_books` is a reasonable choice.

2. **Due count display:** Uses `summary.dueCount` (first repertoire's count) in the headline, not the aggregate `totalDueCount`. This matches the single-repertoire UI intent.

3. **Test breakage scope:** A significant portion of the test file will need deletion/rewriting for the new layout.

4. **Multiple repertoires in data layer:** The controller still loads all repertoires; `.first` is used in the UI. This is by design for future multi-repertoire support.

5. **Muted-style test approach:** Tests focus on behavior (button tappable, snackbar appears, no navigation) rather than asserting specific color/alpha values, avoiding theme-dependent fragility.
