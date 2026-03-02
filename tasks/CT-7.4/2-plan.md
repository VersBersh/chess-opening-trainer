# CT-7.4 Implementation Plan

## Goal

Implement Free Practice mode: an SR-exempt drill session that lets the user practice all cards or filter by label, reusing the existing drill engine and drill screen.

## Steps

### 1. Add `getDistinctLabels()` to `RepertoireTreeCache`

**File:** `src/lib/models/repertoire.dart` (modify)

Add a method that collects all unique non-null labels from the `movesById` map:

```dart
/// Returns all distinct non-null labels across the tree, sorted alphabetically.
List<String> getDistinctLabels() {
  final labels = <String>{};
  for (final move in movesById.values) {
    if (move.label != null) {
      labels.add(move.label!);
    }
  }
  final sorted = labels.toList()..sort();
  return sorted;
}
```

No dependencies.

### 2. Add unit tests for `getDistinctLabels`

**File:** `src/test/services/drill_engine_test.dart` (modify)

Add a new top-level `group('RepertoireTreeCache -- getDistinctLabels')` at the bottom of the file. Use the existing `buildLine()` helper to create `RepertoireMove` objects, then manually set labels by reconstructing moves with the `label` field. Tests:

- Returns empty list when no moves have labels
- Returns single label when one move has a label
- Returns distinct labels sorted alphabetically when multiple moves share the same label
- Ignores null labels and returns only non-null values
- Returns labels from different branches of the tree

Example:

```dart
group('RepertoireTreeCache -- getDistinctLabels', () {
  test('returns empty list when no moves have labels', () {
    final moves = buildLine(['e4', 'e5', 'Nf3']);
    final cache = RepertoireTreeCache.build(moves);
    expect(cache.getDistinctLabels(), isEmpty);
  });

  test('returns distinct labels sorted alphabetically', () {
    final moves = buildLine(['e4', 'e5', 'Nf3', 'Nc6']);
    // Add labels by rebuilding with label field
    final labeled = [
      RepertoireMove(id: moves[0].id, repertoireId: 1, parentMoveId: null,
        fen: moves[0].fen, san: moves[0].san, sortOrder: 0, label: 'Sicilian'),
      moves[1],
      RepertoireMove(id: moves[2].id, repertoireId: 1, parentMoveId: moves[2].parentMoveId,
        fen: moves[2].fen, san: moves[2].san, sortOrder: 0, label: 'Italian'),
      RepertoireMove(id: moves[3].id, repertoireId: 1, parentMoveId: moves[3].parentMoveId,
        fen: moves[3].fen, san: moves[3].san, sortOrder: 0, label: 'Sicilian'),
    ];
    final cache = RepertoireTreeCache.build(labeled);
    expect(cache.getDistinctLabels(), ['Italian', 'Sicilian']);
  });
});
```

Depends on: Step 1.

### 3. Add `isFreePractice` to `SessionSummary` and introduce `DrillConfig` to generalize `DrillController`

**File:** `src/lib/screens/drill_screen.dart` (modify)

#### 3a. Add `DrillConfig` class

Define a class near the top of the file, after the imports. The family arg holds only the lightweight `repertoireId` and `isExtraPractice` flag. Preloaded cards are **not** included in the family key -- they are passed to the controller via a separate mechanism (see 3b):

```dart
/// Configuration for launching a drill session.
/// [repertoireId] identifies which repertoire's tree to load.
/// [isExtraPractice] suppresses SM-2 updates.
/// [preloadedCards] are passed through but NOT included in equality/hashCode
/// (the family key is just repertoireId + isExtraPractice).
class DrillConfig {
  final int repertoireId;
  final bool isExtraPractice;
  final List<ReviewCard>? preloadedCards;

  const DrillConfig({
    required this.repertoireId,
    this.isExtraPractice = false,
    this.preloadedCards,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrillConfig &&
          repertoireId == other.repertoireId &&
          isExtraPractice == other.isExtraPractice;

  @override
  int get hashCode => Object.hash(repertoireId, isExtraPractice);
}
```

This avoids deep list comparison entirely. Two `DrillConfig` values are considered equal when they share the same `repertoireId` and `isExtraPractice` flag. Since free practice always creates a fresh `DrillScreen` via navigation (never coexisting with a normal drill for the same repertoire), this is safe. The `preloadedCards` field is consumed by the controller in `build()` but does not participate in deduplication.

#### 3b. Change `DrillController` family arg from `int` to `DrillConfig`

Update the provider declaration:

```dart
final drillControllerProvider = AsyncNotifierProvider.autoDispose
    .family<DrillController, DrillScreenState, DrillConfig>(DrillController.new);
```

Update `DrillController`:

```dart
class DrillController
    extends AutoDisposeFamilyAsyncNotifier<DrillScreenState, DrillConfig> {
  late DrillEngine _engine;
  late ChessboardController boardController;
  late ReviewRepository _reviewRepo;
  bool _isExtraPractice = false; // stored from build() for use in _buildSummary()
  // ... other existing fields ...

  @override
  Future<DrillScreenState> build(DrillConfig arg) async {
    final config = arg;
    _isExtraPractice = config.isExtraPractice;
    final repertoireRepo = ref.read(repertoireRepositoryProvider);
    _reviewRepo = ref.read(reviewRepositoryProvider);

    final cards = config.preloadedCards ??
        await _reviewRepo.getDueCardsForRepertoire(config.repertoireId);

    if (cards.isEmpty) {
      return DrillSessionComplete(
        summary: SessionSummary(
          totalCards: 0,
          completedCards: 0,
          skippedCards: 0,
          perfectCount: 0,
          hesitationCount: 0,
          struggledCount: 0,
          failedCount: 0,
          sessionDuration: Duration.zero,
          isFreePractice: _isExtraPractice,
        ),
      );
    }

    final allMoves = await repertoireRepo.getMovesForRepertoire(config.repertoireId);
    final treeCache = RepertoireTreeCache.build(allMoves);

    _engine = DrillEngine(
      cards: cards,
      treeCache: treeCache,
      isExtraPractice: config.isExtraPractice,
    );
    // ... rest unchanged (boardController init, counter resets, startCard, etc.)
  }
}
```

#### 3c. Update `DrillScreen` widget

Change the widget to accept `DrillConfig` instead of `repertoireId`:

```dart
class DrillScreen extends ConsumerWidget {
  final DrillConfig config;

  const DrillScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(drillControllerProvider(config));
    // ...
  }
}
```

Update all internal references from `drillControllerProvider(repertoireId)` to `drillControllerProvider(config)`.

#### 3d. Add `isFreePractice` to `SessionSummary`

```dart
class SessionSummary {
  // ... existing fields ...
  final bool isFreePractice;

  const SessionSummary({
    // ... existing params ...
    this.isFreePractice = false,
  });
}
```

Update `_buildSummary()` in `DrillController` to pass `isFreePractice: _isExtraPractice`. The `_isExtraPractice` field was set during `build(DrillConfig config)` at controller initialization, so it is in scope when `_buildSummary()` is called later during session completion. (The old plan referenced `arg.isExtraPractice` which would not compile since `arg` is a local parameter of `build()`, not a controller field.)

#### 3e. Update home screen's `_startDrill` to pass `DrillConfig`

**File:** `src/lib/screens/home_screen.dart` (modify)

```dart
void _startDrill(int repertoireId) {
  Navigator.of(context)
      .push(
        MaterialPageRoute(
          builder: (_) => DrillScreen(
            config: DrillConfig(repertoireId: repertoireId),
          ),
        ),
      )
      .then((_) => ref.read(homeControllerProvider.notifier).refresh());
}
```

Depends on: Steps 1, 2.

### 4. Update session summary UI for free practice mode

**File:** `src/lib/screens/drill_screen.dart` (modify)

In `_buildSessionComplete()`:

- When `summary.isFreePractice` is true, change the heading from "Session Complete" to "Practice Complete"
- Add a subtitle "Free Practice -- no SR updates" below the heading when `isFreePractice` is true
- Hide the "Next review:" line when `isFreePractice` is true (since `earliestNextDue` will always be null anyway, but this makes the intent explicit)
- Keep all other summary elements (cards reviewed, skipped, quality breakdown, duration) -- they are still useful feedback even in practice mode

```dart
Text(
  summary.isFreePractice ? 'Practice Complete' : 'Session Complete',
  style: Theme.of(context).textTheme.headlineMedium,
),
if (summary.isFreePractice) ...[
  const SizedBox(height: 8),
  Text(
    'Free Practice \u2014 no SR updates',
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  ),
],
```

Also update the AppBar title:

```dart
appBar: AppBar(title: Text(summary.isFreePractice ? 'Practice Complete' : 'Session Complete')),
```

Depends on: Step 3.

### 5. Create `FreePracticeSetupScreen`

**File:** `src/lib/screens/free_practice_setup_screen.dart` (create)

Create a new screen with:

- A Riverpod `AutoDisposeFamilyAsyncNotifier<FreePracticeSetupState, int>` (family arg is `repertoireId`) that loads the tree cache and all review cards on build
- State holds: `List<String> availableLabels`, `String? selectedLabel`, `int totalCardCount`, `int filteredCardCount`, `List<ReviewCard> allCards`, `RepertoireTreeCache treeCache`
- The notifier exposes `setSelectedLabel(String? label)` and `buildPracticeCards()` methods
- `buildPracticeCards()` is a **pure data method** that filters cards by label (using `treeCache.getSubtree()` to collect all move IDs under labeled nodes, then filtering `allCards` to those whose `leafMoveId` is in the subtree set) and returns a `List<ReviewCard>`. It does **not** perform navigation.
- **Navigation lives in the widget**, not the notifier. The `FreePracticeSetupScreen` widget calls `buildPracticeCards()` on the notifier, constructs the `DrillConfig`, and performs `Navigator.push(...)` itself. This follows the codebase convention where controllers do data orchestration and widgets handle navigation (see `HomeController.openRepertoire()` returning an ID, with `HomeScreen._onRepertoireTap()` performing the `Navigator.push`).

UI layout:
- AppBar: "Free Practice"
- Body: centered column with:
  - Autocomplete text field for label filtering (using Flutter's `Autocomplete` widget)
  - Text showing card count: "X cards" (updates when label filter changes)
  - "Start Practice" `FilledButton` (disabled when filtered count is 0)
  - "Practice All (Y cards)" `OutlinedButton` to skip label filtering

Start Practice button handler (in the widget):

```dart
void _startPractice(BuildContext context) {
  final notifier = ref.read(freePracticeSetupProvider(repertoireId).notifier);
  final cards = notifier.buildPracticeCards();
  if (cards.isEmpty) return;
  Navigator.of(context)
      .push(
        MaterialPageRoute(
          builder: (_) => DrillScreen(
            config: DrillConfig(
              repertoireId: repertoireId,
              preloadedCards: cards,
              isExtraPractice: true,
            ),
          ),
        ),
      );
}
```

Practice All button handler (in the widget):

```dart
void _startPracticeAll(BuildContext context, List<ReviewCard> allCards) {
  if (allCards.isEmpty) return;
  Navigator.of(context)
      .push(
        MaterialPageRoute(
          builder: (_) => DrillScreen(
            config: DrillConfig(
              repertoireId: repertoireId,
              preloadedCards: allCards,
              isExtraPractice: true,
            ),
          ),
        ),
      );
}
```

Label filtering logic for `setSelectedLabel(String? label)`:
1. If `label` is null or empty, show all cards count
2. Otherwise, find all moves where `move.label == label`, collect their subtree move IDs via `treeCache.getSubtree()`, then count `allCards` where `leafMoveId` is in that ID set

The Autocomplete widget should use `optionsBuilder` that filters `availableLabels` by the current text input (case-insensitive prefix match).

```dart
Autocomplete<String>(
  optionsBuilder: (textEditingValue) {
    if (textEditingValue.text.isEmpty) return availableLabels;
    return availableLabels.where(
      (label) => label.toLowerCase().contains(textEditingValue.text.toLowerCase()),
    );
  },
  onSelected: (label) => notifier.setSelectedLabel(label),
  // ...
)
```

Depends on: Steps 1, 3.

### 6. Add "Free Practice" button to home screen

**File:** `src/lib/screens/home_screen.dart` (modify)

Add a new button between "Start Drill" and "Repertoire" in `_buildData()`:

```dart
const SizedBox(height: 16),
OutlinedButton.icon(
  onPressed: repertoireId != null
      ? () => _startFreePractice(repertoireId)
      : null,
  icon: const Icon(Icons.fitness_center),
  label: const Text('Free Practice'),
),
```

Add the navigation method:

```dart
void _startFreePractice(int repertoireId) {
  Navigator.of(context)
      .push(
        MaterialPageRoute(
          builder: (_) => FreePracticeSetupScreen(repertoireId: repertoireId),
        ),
      )
      .then((_) => ref.read(homeControllerProvider.notifier).refresh());
}
```

Add import for `FreePracticeSetupScreen` at the top of the file.

The "Free Practice" button is always enabled when a repertoire exists (unlike "Start Drill" which requires due cards), since free practice works with all cards regardless of due status.

Depends on: Step 5.

### 7. Update existing `DrillScreen` tests for `DrillConfig` parameterization

**File:** `src/test/screens/drill_screen_test.dart` (modify)

Update `buildTestApp()` to accept `DrillConfig` instead of `repertoireId`, and **return the config** so tests can reference it for provider reads:

```dart
const _defaultConfig = DrillConfig(repertoireId: 1);

Widget buildTestApp({
  required FakeRepertoireRepository repertoireRepo,
  required FakeReviewRepository reviewRepo,
  DrillConfig config = _defaultConfig,
}) {
  return ProviderScope(
    overrides: [
      repertoireRepositoryProvider.overrideWithValue(repertoireRepo),
      reviewRepositoryProvider.overrideWithValue(reviewRepo),
    ],
    child: MaterialApp(
      home: DrillScreen(config: config),
    ),
  );
}
```

Update every test that reads from `drillControllerProvider(1)` to use the same `DrillConfig` instance that was passed to `buildTestApp`. The key detail is that Riverpod uses `==` to match family args, so the config used in `container.read(drillControllerProvider(drillConfig))` must be value-equal to the one used to build the `DrillScreen`.

Concrete approach -- in each test that accesses the provider directly:

1. Declare the config at the top of the test (or use the file-level `_defaultConfig` constant for standard tests):
   ```dart
   const drillConfig = DrillConfig(repertoireId: 1);
   ```
2. Pass it to `buildTestApp`:
   ```dart
   await tester.pumpWidget(buildTestApp(
     repertoireRepo: repertoireRepo,
     reviewRepo: reviewRepo,
     config: drillConfig,
   ));
   ```
3. Replace every `drillControllerProvider(1)` with `drillControllerProvider(drillConfig)`:
   ```dart
   final notifier = container.read(drillControllerProvider(drillConfig).notifier);
   // ...
   final state = container.read(drillControllerProvider(drillConfig));
   ```

Since the default `DrillConfig(repertoireId: 1)` has `isExtraPractice: false` and `preloadedCards: null`, the controller behavior is identical to the old `int` arg -- it fetches due cards from the repo. All existing tests continue to pass unchanged in behavior.

Tests that do **not** read the provider directly (e.g., the board orientation tests, empty queue test, skip test) only need the `buildTestApp` signature change, which is handled by the default parameter.

Depends on: Step 3.

### 8. Write widget tests for free practice drill behavior

**File:** `src/test/screens/drill_screen_test.dart` (modify)

Add a new `group('DrillScreen -- free practice')` with tests:

- **Free practice does not save reviews:** Create a `DrillConfig(repertoireId: 1, preloadedCards: [card], isExtraPractice: true)`, complete a card, verify `reviewRepo.savedReviews` is empty.
- **Free practice session summary shows "Practice Complete":** Complete a free practice session, verify `find.text('Practice Complete')` appears and `find.text('Session Complete')` does not.
- **Free practice session summary shows SR-exempt subtitle:** Verify `find.textContaining('no SR updates')` appears.
- **Free practice session summary hides next review date:** Complete a card in free practice, verify `find.textContaining('Next review:')` finds nothing.

Use `buildTestApp(config: DrillConfig(repertoireId: 1, preloadedCards: [card], isExtraPractice: true))` to exercise the preloaded-cards path. Thread that same config instance to all `container.read(drillControllerProvider(config))` calls inside each test.

Depends on: Steps 4, 7.

### 9. Write widget tests for `FreePracticeSetupScreen`

**File:** `src/test/screens/free_practice_setup_screen_test.dart` (create)

Create a new test file. Reuse the `FakeRepertoireRepository` and `FakeReviewRepository` patterns from the drill screen tests. Build a `buildTestApp` helper that wraps `FreePracticeSetupScreen(repertoireId: 1)` in a `ProviderScope` + `MaterialApp`.

Tests:
- **Shows autocomplete field and start button:** Verify `find.byType(Autocomplete<String>)` and `find.text('Start Practice')` exist.
- **Shows total card count on initial load:** With 3 all-cards in the fake repo, verify "3 cards" text appears.
- **Label autocomplete filters options:** Enter text into the autocomplete, verify matching labels appear as options.
- **Selecting a label updates card count:** Select a label, verify the displayed count changes to reflect only cards under that label's subtree.
- **Start Practice button navigates to DrillScreen:** Tap "Start Practice", verify `DrillScreen` is pushed.
- **Disables Start Practice when filtered count is 0:** Select a label with no cards, verify button is disabled.

Depends on: Step 5.

### 10. Write widget tests for home screen "Free Practice" button

**File:** `src/test/screens/home_screen_test.dart` (modify)

Add a new `group('HomeScreen -- Free Practice button')`:

- **Shows Free Practice button:** Verify `find.text('Free Practice')` exists.
- **Free Practice button is enabled when repertoire exists:** Verify `button.onPressed` is not null.
- **Free Practice button is disabled when no repertoire exists:** Create `FakeRepertoireRepository(repertoires: [])`, verify button is disabled (or hidden).
- **Tapping Free Practice navigates to setup screen:** Tap the button, pump, verify `FreePracticeSetupScreen` is pushed.

Depends on: Step 6.

## Risks / Open Questions

1. **`DrillConfig` equality excludes `preloadedCards`.** The equality/hashCode on `DrillConfig` intentionally ignores `preloadedCards` to avoid deep list comparison. This is safe because free practice sessions always create a fresh navigation route (a new `DrillScreen` widget), so two `DrillConfig` instances with the same `repertoireId` and `isExtraPractice` will never coexist in Riverpod's family cache. If a future feature required multiple simultaneous free practice sessions for the same repertoire with different card sets, the family arg strategy would need revision (e.g., adding a unique session ID to the config, or storing preloaded cards in a separate `StateProvider`).

2. **`package:collection` not needed.** The original plan used `ListEquality` from `package:collection` for deep list comparison in `DrillConfig`. This dependency is not in `pubspec.yaml` and is no longer needed since `preloadedCards` is excluded from equality. No new dependencies are required.

3. **Navigation stays in widgets, not notifiers.** The review flagged that the original plan had `startPractice()` in the `FreePracticeSetup` notifier performing `Navigator.push(...)`. This has been corrected: `buildPracticeCards()` is a pure data method on the notifier that returns `List<ReviewCard>`, and the widget performs the navigation. This follows the established codebase pattern (e.g., `HomeController.openRepertoire()` returns data, `HomeScreen._onRepertoireTap()` navigates).

4. **`_isExtraPractice` stored as a controller field.** The review flagged that `arg.isExtraPractice` is not in scope inside `_buildSummary()` since `arg` is a local parameter of `build()`. The fix is to store `_isExtraPractice` as a controller field, set it at the top of `build(DrillConfig arg)`, and reference it in `_buildSummary()`. This is a simple, reliable pattern.

5. **Test provider reads must use value-equal `DrillConfig`.** The review flagged that "mechanical replace" of `drillControllerProvider(1)` is insufficient. The revised plan (Step 7) explicitly threads a `drillConfig` variable through `buildTestApp` and every `container.read(...)` call. Since `DrillConfig` implements `==` based on `repertoireId` and `isExtraPractice`, any `const DrillConfig(repertoireId: 1)` will match, but the plan uses a shared constant `_defaultConfig` for clarity and safety.

6. **Label-to-cards mapping is computed in-memory.** For free practice filtering, we load all moves (via `getMovesForRepertoire`) and all cards (via `getAllCardsForRepertoire`), build the tree, find labeled move IDs, walk subtrees, then intersect with card `leafMoveId` values. This is fine for typical repertoire sizes (hundreds to low thousands of moves) but could be slow for very large repertoires. No database-level filtering by label exists today.

7. **Multiple moves can share the same label string.** When a user selects a label like "Sicilian", the filter should collect subtrees from all moves that have that exact label, not just the first one. The implementation in Step 5 must iterate all moves with `move.label == selectedLabel` and union their subtree IDs.

8. **Labels are on interior nodes, not leaves.** A label marks a position in the tree (e.g., "Sicilian" on 1...c5). The cards to practice are those whose leaf move is a descendant of any move with that label. This subtree-walk approach is already supported by `RepertoireTreeCache.getSubtree(moveId)`.

9. **Home screen button enablement.** "Free Practice" should be enabled whenever a repertoire exists (since it can practice any cards, not just due ones). However, if the repertoire has zero review cards at all, the button could lead to an empty session. The setup screen handles this gracefully by showing "0 cards" and disabling the start button.

10. **Existing test maintenance.** Changing `DrillController`'s family arg from `int` to `DrillConfig` is a breaking change that requires updating every test that references `drillControllerProvider(1)`. Step 7 handles this by introducing a shared `_defaultConfig` constant and threading it through each test. Run the full test suite after this change to catch any missed references.
