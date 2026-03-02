# CT-10.1: Implementation Plan

## Goal

Remove the intermediate Free Practice setup screen so that tapping "Free Practice" on the home screen navigates directly to the drill screen in Free Practice mode with all repertoire cards loaded, and add a visual "Free Practice" indicator to the active drill screen.

## Steps

### Step 1: Update `DrillController.build()` to auto-load all cards in free practice mode

**File:** `src/lib/screens/drill_screen.dart`

In `DrillController.build()`, change the card-loading logic from:

```dart
final cards = config.preloadedCards ??
    await _reviewRepo.getDueCardsForRepertoire(config.repertoireId);
```

to:

```dart
final cards = config.preloadedCards ??
    (config.isExtraPractice
        ? await _reviewRepo.getAllCardsForRepertoire(config.repertoireId)
        : await _reviewRepo.getDueCardsForRepertoire(config.repertoireId));
```

This allows the drill controller to fetch all cards itself when launched in free practice mode without `preloadedCards`.

### Step 2: Shuffle cards for free practice mode

**File:** `src/lib/screens/drill_screen.dart`

After loading cards in `DrillController.build()`, if `config.isExtraPractice` is true, shuffle the cards list to serve them in random order. The `preloadedCards` list may be unmodifiable, so create a mutable copy:

```dart
var cardList = List.of(cards);
if (config.isExtraPractice) {
  cardList.shuffle();
}
```

### Step 3: Update `_startFreePractice` in home screen to navigate directly to `DrillScreen`

**File:** `src/lib/screens/home_screen.dart`

Change the `_startFreePractice(int repertoireId)` method to navigate to `DrillScreen` instead of `FreePracticeSetupScreen`:

```dart
void _startFreePractice(int repertoireId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => DrillScreen(
              config: DrillConfig(
                repertoireId: repertoireId,
                isExtraPractice: true,
              ),
            ),
          ),
        )
        .then((_) => ref.read(homeControllerProvider.notifier).refresh());
  }
```

No `preloadedCards` is passed — the `DrillController` will load all cards itself per Step 1.

### Step 4: Remove the `free_practice_setup_screen.dart` import from home screen

**File:** `src/lib/screens/home_screen.dart`

Remove the import of `free_practice_setup_screen.dart`. The home screen already imports `drill_screen.dart`, so no new import is needed.

### Step 5: Add a visual "Free Practice" indicator to the drill screen

**File:** `src/lib/screens/drill_screen.dart`

When `config.isExtraPractice` is true, modify the AppBar title in all drill screen states to indicate Free Practice mode. There are six AppBar locations that need updating:

**A. Top-level async loading state** (the `asyncState.when(loading: ...)` callback, currently `AppBar(title: const Text('Drill'))`):
Change to show "Free Practice" when `config.isExtraPractice` is true, otherwise "Drill".

**B. Top-level async error state** (the `asyncState.when(error: ...)` callback, currently `AppBar(title: const Text('Drill'))`):
Same conditional — "Free Practice" vs "Drill".

**C. `DrillLoading` state inside `_buildForState`** (currently `AppBar(title: const Text('Drill'))`):
Same conditional — "Free Practice" vs "Drill".

**D. `DrillCardStart`, `DrillUserTurn`, and `DrillMistakeFeedback` states** (all pass a `title` to `_buildDrillScaffold`):
Change the title string from `'Card X of Y'` to `'Free Practice — X/Y'` when `config.isExtraPractice` is true:

```dart
title: config.isExtraPractice
    ? 'Free Practice — ${drillState.currentCardNumber}/${drillState.totalCards}'
    : 'Card ${drillState.currentCardNumber} of ${drillState.totalCards}',
```

**E. `DrillSessionComplete`** already handles free practice via `summary.isFreePractice` — no change needed.

### Step 6: Delete the free practice setup screen file

**File to delete:** `src/lib/screens/free_practice_setup_screen.dart`

This removes `FreePracticeSetupScreen`, `FreePracticeSetupState`, `FreePracticeSetupController`, and `freePracticeSetupProvider` — all dead code after Steps 3-4.

### Step 7: Delete the free practice setup screen test file

**File to delete:** `src/test/screens/free_practice_setup_screen_test.dart`

All tests in this file test the setup screen that no longer exists.

### Step 8: Update home screen tests

**File:** `src/test/screens/home_screen_test.dart`

- Remove the import of `free_practice_setup_screen.dart`.
- Update the test "tapping Free Practice navigates to setup screen": Change the assertion from `expect(find.byType(FreePracticeSetupScreen), findsOneWidget)` to `expect(find.byType(DrillScreen), findsOneWidget)`. Rename the test to "tapping Free Practice navigates to drill screen".

### Step 9: Extend `FakeReviewRepository` in drill screen tests to support separate due/all card lists

**File:** `src/test/screens/drill_screen_test.dart`

The current `FakeReviewRepository` in this file stores only a single `_dueCards` list and returns it from both `getDueCardsForRepertoire` and `getAllCardsForRepertoire`. This makes it impossible to verify that Step 1's branching logic calls the correct method.

Update the fake to match the pattern already used in `home_screen_test.dart`:

```dart
class FakeReviewRepository implements ReviewRepository {
  final List<ReviewCard> _dueCards;
  final List<ReviewCard> _allCards;
  final List<ReviewCardsCompanion> savedReviews = [];

  FakeReviewRepository({List<ReviewCard>? dueCards, List<ReviewCard>? allCards})
      : _dueCards = dueCards ?? [],
        _allCards = allCards ?? dueCards ?? [];

  @override
  Future<List<ReviewCard>> getDueCards({DateTime? asOf}) async => _dueCards;

  @override
  Future<List<ReviewCard>> getDueCardsForRepertoire(int repertoireId,
      {DateTime? asOf}) async {
    return _dueCards.where((c) => c.repertoireId == repertoireId).toList();
  }

  @override
  Future<ReviewCard?> getCardForLeaf(int leafMoveId) async =>
      _dueCards.where((c) => c.leafMoveId == leafMoveId).firstOrNull;

  @override
  Future<void> saveReview(ReviewCardsCompanion card) async {
    savedReviews.add(card);
  }

  @override
  Future<void> deleteCard(int id) async {}

  @override
  Future<List<ReviewCard>> getCardsForSubtree(int moveId,
          {bool dueOnly = false, DateTime? asOf}) async =>
      [];

  @override
  Future<List<ReviewCard>> getAllCardsForRepertoire(int repertoireId) async =>
      _allCards.where((c) => c.repertoireId == repertoireId).toList();
}
```

Existing tests that only pass `dueCards` are unaffected because `_allCards` defaults to `dueCards` when not specified.

### Step 10: Add functional test for free practice card loading (no preloadedCards)

**File:** `src/test/screens/drill_screen_test.dart`

Add a test inside the existing `'DrillScreen -- free practice'` group that verifies free practice with no `preloadedCards` loads all cards (not just due cards):

```dart
testWidgets('free practice without preloadedCards loads all cards', (tester) async {
  final allCard = buildReviewCard(whiteLine9);
  final freePracticeConfig = DrillConfig(
    repertoireId: 1,
    isExtraPractice: true,
    // No preloadedCards — controller must fetch them itself
  );
  final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
  // dueCards is empty, allCards has a card — proves getAllCardsForRepertoire is called
  final reviewRepo = FakeReviewRepository(dueCards: [], allCards: [allCard]);

  await tester.pumpWidget(buildTestApp(
    repertoireRepo: repertoireRepo,
    reviewRepo: reviewRepo,
    config: freePracticeConfig,
  ));
  await tester.pumpAndSettle(const Duration(seconds: 5));

  // Should have loaded the card and be showing a drill state, not session-complete
  expect(find.textContaining('Free Practice'), findsOneWidget);
  // Verify we did NOT get the empty-session outcome
  expect(find.text('Practice Complete'), findsNothing);
});
```

Key design: `dueCards` is empty but `allCards` is non-empty. If the controller incorrectly called `getDueCardsForRepertoire`, it would get zero cards and show "Practice Complete" immediately. The test asserts an active drill session started, proving `getAllCardsForRepertoire` was called.

### Step 11: Add test for free practice visual indicator in AppBar

**File:** `src/test/screens/drill_screen_test.dart`

Add a test inside the existing `'DrillScreen -- free practice'` group that verifies the AppBar title contains "Free Practice" when `isExtraPractice: true`:

```dart
testWidgets('free practice shows "Free Practice" in AppBar title', (tester) async {
  final card = buildReviewCard(whiteLine9);
  final freePracticeConfig = DrillConfig(
    repertoireId: 1,
    preloadedCards: [card],
    isExtraPractice: true,
  );
  final repertoireRepo = FakeRepertoireRepository(moves: whiteLine9);
  final reviewRepo = FakeReviewRepository(dueCards: [card]);

  await tester.pumpWidget(buildTestApp(
    repertoireRepo: repertoireRepo,
    reviewRepo: reviewRepo,
    config: freePracticeConfig,
  ));
  await tester.pumpAndSettle(const Duration(seconds: 5));

  // AppBar should say "Free Practice — 1/1"
  expect(find.text('Free Practice — 1/1'), findsOneWidget);
});
```

## Risks / Open Questions

1. **Card shuffling**: The spec says "Cards are served in random order" for free practice. The current setup screen does not explicitly shuffle. Step 2 adds shuffling. The database query order for `getAllCardsForRepertoire` is likely deterministic (by ID), so without shuffling, users would always see the same card order.

2. **Visual indicator design**: The acceptance criteria say "Free Practice mode is visually indicated on the drill screen (e.g., a header or badge)" but do not prescribe a specific design. The plan proposes modifying the AppBar title — minimal and consistent with existing patterns.

3. **CT-10.2 dependency**: CT-10.2 will re-add inline label filtering to the drill screen. The filtering logic currently in `FreePracticeSetupController` will need to be re-implemented. Some code being deleted here may be useful reference — it can be found in git history.

4. **`DrillConfig` equality**: When no `preloadedCards` is provided (both null), two `DrillConfig` instances with the same `repertoireId` and `isExtraPractice` will be equal, which is correct for Riverpod family deduplication.

5. **`FakeReviewRepository` divergence across test files**: After Step 9, both `drill_screen_test.dart` and `home_screen_test.dart` will have their own `FakeReviewRepository` with separate `dueCards`/`allCards` support. These are intentionally independent copies (not shared via a helper file) to match the existing test architecture in this project, where each test file owns its fakes. If this becomes a maintenance concern, a shared test-helper file could be extracted in a future task.
