# 2-plan.md

## Goal

Refactor the home screen from a flat button layout to a per-repertoire card list, with each card showing Start Drill, Free Practice, and Add Line actions, and wire the new buttons to their respective screens.

## Steps

### 1. Add `totalCardCount` to `RepertoireSummary` and refactor navigation methods to accept `repertoireId`

**File:** `src/lib/screens/home_screen.dart` (modify)

**Part A -- Data model.** Add a `totalCardCount` field to `RepertoireSummary`:

```dart
class RepertoireSummary {
  final Repertoire repertoire;
  final int dueCount;
  final int totalCardCount;
  const RepertoireSummary({
    required this.repertoire,
    required this.dueCount,
    required this.totalCardCount,
  });
}
```

In `HomeController._load()`, call `reviewRepo.getAllCardsForRepertoire(repertoire.id)` for each repertoire and populate `totalCardCount` with `allCards.length`. This uses the existing `getAllCardsForRepertoire` method on `ReviewRepository` -- no repository changes needed.

**Part B -- Method signatures.** Refactor `_onAddLineTap()` and `_onRepertoireTap()` to accept a `repertoireId` parameter. These methods currently take no parameters and call `openRepertoire()` to auto-create a repertoire. With the per-card layout, callers always have a concrete repertoire ID, so `openRepertoire()` is no longer needed here.

```dart
void _onAddLineTap(int repertoireId) {
  Navigator.of(context)
      .push(MaterialPageRoute(
        builder: (_) => AddLineScreen(
          db: widget.db,
          repertoireId: repertoireId,
        ),
      ))
      .then((_) => ref.read(homeControllerProvider.notifier).refresh());
}

void _onRepertoireTap(int repertoireId) {
  Navigator.of(context)
      .push(MaterialPageRoute(
        builder: (_) => RepertoireBrowserScreen(
          db: widget.db,
          repertoireId: repertoireId,
        ),
      ))
      .then((_) => ref.read(homeControllerProvider.notifier).refresh());
}
```

The existing `_startDrill(int repertoireId)` and `_startFreePractice(int repertoireId)` already accept a `repertoireId` parameter and need no changes.

Retain `openRepertoire()` on `HomeController` -- it will be used exclusively from the empty-state flow (Step 3).

No dependencies on other steps.

### 2. Replace the flat Column layout with a per-repertoire card list

**File:** `src/lib/screens/home_screen.dart` (modify)

Replace the `_buildData` method's body. Instead of a single centered `Column` with global buttons, build a `ListView.builder` (or `Column` inside a `SingleChildScrollView`) that iterates over `homeState.repertoires`, rendering one `Card` widget per `RepertoireSummary`.

Each card should contain:
- **Header row:** Repertoire name (tappable, calls `_onRepertoireTap(summary.repertoire.id)` to navigate to Repertoire Browser) and due count badge.
- **Action row:** Three action buttons:
  - **Start Drill** (`FilledButton.icon`): Always tappable (never set `onPressed: null`). When `summary.dueCount > 0`, calls `_startDrill(summary.repertoire.id)` to navigate to DrillScreen. When `summary.dueCount == 0`, shows a `SnackBar` with the message "No cards due for review. Come back later!" instead of navigating. The button should be visually muted (lower-emphasis styling, e.g. reduced opacity or a tonal color) when `dueCount == 0` to signal the zero-due state, but remain interactive.
  - **Free Practice** (`OutlinedButton.icon`): Enabled when `summary.totalCardCount > 0`. Calls `_startFreePractice(summary.repertoire.id)`. Disabled (`onPressed: null`) when `totalCardCount == 0`.
  - **Add Line** (`OutlinedButton.icon` or `TextButton.icon`): Always enabled. Calls `_onAddLineTap(summary.repertoire.id)`.

Keep the summary "X cards due" text at the top of the screen (above the list) for the global `totalDueCount`, and the settings icon in the app bar.

The action row can use a `Wrap` or `Row` with `MainAxisAlignment.spaceEvenly` to fit three buttons. If horizontal space is tight on narrow screens, consider stacking them into two rows (Start Drill alone on top; Free Practice and Add Line on the second row) or using `IconButton` variants for secondary actions.

Remove the global `'Repertoire'` and `'Add Line'` buttons entirely -- these concepts are now per-card actions.

Depends on: Step 1 (method signatures must accept `repertoireId` before this step wires them into the card layout).

### 3. Handle the empty state (no repertoires)

**File:** `src/lib/screens/home_screen.dart` (modify)

When `homeState.repertoires.isEmpty`, display the empty-state onboarding UI instead of the card list:

```dart
if (homeState.repertoires.isEmpty) {
  return _buildEmptyState(context);
}
return _buildRepertoireList(context, homeState);
```

The empty state shows:
- A brief explanation: "Build your opening repertoire and practice it with spaced repetition."
- A "Create your first repertoire" button.

**Note on naming prompt (deferred):** The spec says this button should open the same creation dialog as "Create repertoire" -- a single text field for the name and a confirm button. However, the current `openRepertoire()` method auto-creates a repertoire named "My Repertoire" without prompting. Implementing the name-entry dialog is a separate concern (repertoire CRUD) and out of scope for this layout task. For now, use `openRepertoire()` with its auto-create behavior and add a `// TODO(CT-next): Replace with name-entry dialog per spec (Repertoire CRUD section)` comment.

After `openRepertoire()` returns the new repertoire ID, navigate to the Repertoire Browser for that repertoire:

```dart
void _onCreateFirstRepertoire() async {
  final id = await ref.read(homeControllerProvider.notifier).openRepertoire();
  if (mounted) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => RepertoireBrowserScreen(
            db: widget.db,
            repertoireId: id,
          ),
        ))
        .then((_) => ref.read(homeControllerProvider.notifier).refresh());
  }
}
```

Depends on: Steps 1, 2.

### 4. Update existing tests for the new layout

**File:** `src/test/screens/home_screen_test.dart` (modify)

Update tests to account for the new per-repertoire card layout and removed global controls:

**Fake repository changes:**

Add a separate `allCards` collection to `FakeReviewRepository` so that `getAllCardsForRepertoire` and `getDueCardsForRepertoire` can return independent results. This is critical for testing `dueCount == 0 && totalCardCount > 0`:

```dart
class FakeReviewRepository implements ReviewRepository {
  List<ReviewCard> dueCards;
  List<ReviewCard> allCards;
  final List<ReviewCardsCompanion> savedReviews = [];

  FakeReviewRepository({
    List<ReviewCard>? dueCards,
    List<ReviewCard>? allCards,
  })  : dueCards = dueCards ?? [],
        allCards = allCards ?? dueCards ?? [];

  @override
  Future<List<ReviewCard>> getDueCardsForRepertoire(int repertoireId,
      {DateTime? asOf}) async {
    return dueCards.where((c) => c.repertoireId == repertoireId).toList();
  }

  @override
  Future<List<ReviewCard>> getAllCardsForRepertoire(int repertoireId) async =>
      allCards.where((c) => c.repertoireId == repertoireId).toList();

  // ... other methods unchanged
}
```

Default behavior: if only `dueCards` is provided, `allCards` defaults to the same list (preserving backward compatibility with existing tests). When the caller needs `totalCardCount > dueCount`, they provide both `allCards` and `dueCards`.

**Tests to update:**

- **"disables Start Drill button when no cards due"** -- Replace: verify Start Drill is still tappable when `dueCount == 0`, but shows a SnackBar with "No cards due for review. Come back later!" instead of navigating.
- **"Free Practice button is enabled when repertoire exists"** -- Replace with: "Free Practice is enabled when repertoire has cards (`totalCardCount > 0`)". Set up `FakeReviewRepository` with `allCards` containing cards.
- **"Free Practice button is disabled when no repertoire exists"** -- Replace with two tests:
  1. "Free Practice is disabled when repertoire has no cards (`totalCardCount == 0`)".
  2. "Empty state shows Create your first repertoire button when no repertoires exist".
- **"shows Repertoire button"** -- Remove this test. The global `'Repertoire'` button no longer exists.
- **Due count display tests** -- Minimal adjustment, should still pass with global summary text.

Depends on: Steps 1-3.

### 5. Add new tests for the three-button card layout

**File:** `src/test/screens/home_screen_test.dart` (modify)

Add new test cases:

- **Test: each repertoire card shows Start Drill, Free Practice, and Add Line buttons.** Create a `FakeRepertoireRepository` with two repertoires, provide `allCards` and `dueCards` independently. Verify all six buttons render.
- **Test: Start Drill shows snackbar when dueCount == 0.** Set up a repertoire with `dueCount == 0` but `totalCardCount > 0`. Tap Start Drill. Verify SnackBar with "No cards due for review. Come back later!" appears.
- **Test: Start Drill navigates to DrillScreen when dueCount > 0.** Verify navigation.
- **Test: Free Practice is enabled when repertoire has cards but none are due.** Set up `allCards` with cards, `dueCards` empty. Verify Free Practice `onPressed` is not null.
- **Test: Free Practice is disabled when repertoire has no cards.** Set up empty `allCards`. Verify Free Practice `onPressed` is null.
- **Test: tapping Add Line navigates to AddLineScreen.** Seed the in-memory `AppDatabase` with a matching repertoire row before pumping (because `AddLineController.loadData()` calls `getRepertoire()` on the real DB). After tapping, verify `find.byType(AddLineScreen)` is found.
- **Test: tapping repertoire name navigates to RepertoireBrowserScreen.** Seed the test DB similarly. Verify navigation.
- **Test: empty state shows "Create your first repertoire" button.** Set up `FakeRepertoireRepository(repertoires: [])`. Verify the CTA button renders and no repertoire cards are shown.

Depends on: Steps 1-4.

## Risks / Open Questions

1. **Layout density on small screens.** Three buttons per repertoire card may be tight on narrow mobile screens. Start with a `Wrap` and adjust if needed.

2. **"Total card count" vs "has cards" boolean.** Adding `totalCardCount` as an integer is forward-compatible with displaying "47 lines" on the card per the spec's `RepertoireSummary` model.

3. **Performance of `getAllCardsForRepertoire` per repertoire.** Loads all card objects just to count them. Fine for a small app. A `getCardCountForRepertoire(int)` method can be added later (noted in spec Key Decision 4).

4. **`openRepertoire()` auto-create pattern.** Retained only for the empty-state flow. Per-card actions always have a concrete repertoire ID.

5. **`AppDatabase` dependency on `AddLineScreen`.** The home screen must continue to carry `widget.db` and pass it through. For tests, the in-memory `AppDatabase` must be seeded with a matching repertoire row before navigating to `AddLineScreen`.

6. **Multiple repertoire test infrastructure.** The existing `FakeRepertoireRepository` supports this via the `repertoires` parameter.

7. **Empty-state naming prompt is deferred.** The plan uses `openRepertoire()` auto-create with a TODO comment. A follow-up task should implement the full Create Repertoire dialog.

8. **Drill no-due snackbar approach.** The spec says the drill button should remain tappable when no cards are due and show a brief message. A `SnackBar` matches the spec's "brief message" language. The button is visually muted but never disabled.
