# CT-8: Implementation Plan

## Goal

Display the aggregate display name of the deepest labeled position along the current card's line above the board in drill mode, updating each time a new card begins.

## Steps

### 1. Add a `getLineLabelName` method to `DrillEngine`

**File:** `src/lib/services/drill_engine.dart`

Add a public method that computes the line label for the current card. This method should be called after `startCard()` and uses the `DrillCardState.lineMoves` list (already populated by `startCard()`).

```dart
/// Returns the aggregate display name for the deepest labeled position
/// along the current card's line, or an empty string if no labels exist.
String getLineLabelName() {
  final state = _currentCardState;
  if (state == null) return '';

  // Walk the line in reverse to find the deepest labeled move
  for (var i = state.lineMoves.length - 1; i >= 0; i--) {
    if (state.lineMoves[i].label != null) {
      return _treeCache.getAggregateDisplayName(state.lineMoves[i].id);
    }
  }
  return '';
}
```

This follows the task spec: "the aggregate display name is computed by walking the card's line from root to leaf and collecting all labels, joined with ' -- '. The deepest (most specific) label's aggregate name is used." The `getAggregateDisplayName` method on `RepertoireTreeCache` already walks root-to-node and joins all labels with em dash, so calling it on the deepest labeled move gives the correct result.

**Depends on:** Nothing.

### 2. Add `lineLabel` field to the drill screen state classes

**File:** `src/lib/screens/drill_screen.dart`

Add a `String lineLabel` field (defaulting to `''`) to the three board-displaying state classes: `DrillCardStart`, `DrillUserTurn`, and `DrillMistakeFeedback`. The field is final and set at construction time.

For `DrillCardStart`:
```dart
class DrillCardStart extends DrillScreenState {
  final int currentCardNumber;
  final int totalCards;
  final Side userColor;
  final String lineLabel;

  const DrillCardStart({
    required this.currentCardNumber,
    required this.totalCards,
    required this.userColor,
    this.lineLabel = '',
  });
}
```

Apply the same pattern to `DrillUserTurn` and `DrillMistakeFeedback` -- add `final String lineLabel` with `this.lineLabel = ''` in the constructor.

**Depends on:** Nothing.

### 3. Populate `lineLabel` in `DrillController`

**File:** `src/lib/screens/drill_screen.dart`

Update the `DrillController` to compute and propagate the line label. Add a `String _currentLineLabel = ''` instance field.

In the `build()` method, after `_engine.startCard()`:
```dart
_engine.startCard();
_currentLineLabel = _engine.getLineLabelName();
```

Pass `_currentLineLabel` into the `DrillCardStart` constructor.

In `_startNextCard()`, after `_engine.startCard()`:
```dart
_engine.startCard();
_currentLineLabel = _engine.getLineLabelName();
```

Update every place that creates `DrillUserTurn` or `DrillMistakeFeedback` to pass `lineLabel: _currentLineLabel`. These occur in:
- `_autoPlayIntro` (creates `DrillUserTurn`)
- `processUserMove` (creates `DrillUserTurn` and `DrillMistakeFeedback`)
- `_revertAfterMistake` (creates `DrillUserTurn`)

In each case, add `lineLabel: _currentLineLabel` to the constructor call. The label is computed once per card and stays constant, so `_currentLineLabel` is always the correct value for the duration of a card.

**Depends on:** Steps 1, 2.

### 4. Render the line label in the drill scaffold

**File:** `src/lib/screens/drill_screen.dart`

Update `_buildDrillScaffold` to accept and display the line label. Add a `String lineLabel` parameter.

Extract the label from the state in `_buildForState` and pass it to `_buildDrillScaffold`. For each case (`DrillCardStart`, `DrillUserTurn`, `DrillMistakeFeedback`), pass `lineLabel: drillState.lineLabel`.

In `_buildDrillScaffold`, add the label widget between the `AppBar` and the `ChessboardWidget` inside the `Column`. Follow the same pattern used in the repertoire browser screen. Give the label container a `ValueKey` so widget tests can robustly assert its presence or absence:

```dart
if (lineLabel.isNotEmpty)
  Container(
    key: const ValueKey('drill-line-label'),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Text(
      lineLabel,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  ),
```

When `lineLabel` is empty, the `if` clause hides the label container entirely, leaving the layout unchanged from the current behavior. The `ValueKey('drill-line-label')` enables the "label hidden" widget test to assert `find.byKey(const ValueKey('drill-line-label'))` is absent, rather than relying on fragile `Container` matching.

**Depends on:** Steps 2, 3.

### 5. Add unit tests for `DrillEngine.getLineLabelName`

**File:** `src/test/services/drill_engine_test.dart`

Add `import 'package:drift/drift.dart' hide isNull, isNotNull;` at the top of the file. This import brings `Value` into scope, which is needed for `RepertoireMove.copyWith(label: Value('...'))`. The `hide isNull, isNotNull` clause prevents conflicts with `flutter_test` matchers -- this is the established pattern used across the test suite (e.g., `local_repertoire_repository_test.dart`, `repertoire_browser_screen_test.dart`, `pgn_importer_test.dart`).

Add a test group for `getLineLabelName`. Test cases:

- **Line with no labels returns empty string:** Build a line with no labels, start a card, verify `engine.getLineLabelName()` returns `''`.
- **Line with a single label returns that label:** Build a line where one move has `label: 'Sicilian'`, start a card, verify returns `'Sicilian'`.
- **Line with multiple labels returns aggregate of root-to-deepest:** Build a line where move at index 1 has `label: 'Sicilian'` and move at index 3 has `label: 'Najdorf'`, start a card, verify returns `'Sicilian — Najdorf'`.
- **Uses deepest label, not leaf:** Build a line where the label is on an intermediate move but not on the leaf. Verify the aggregate display name is computed for the labeled move's position, not the leaf.

To create moves with labels in tests, use the existing `buildLine` helper and then apply `copyWith(label: Value('...'))` on specific moves. For example:

```dart
final line = buildLine(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
final labeledLine = [
  line[0],
  line[1].copyWith(label: const Value('Sicilian')),
  line[2],
  line[3].copyWith(label: const Value('Najdorf')),
  line[4],
];
```

**Depends on:** Step 1.

### 6. Add widget tests for label display in the drill screen

**File:** `src/test/screens/drill_screen_test.dart`

Add `import 'package:drift/drift.dart' hide isNull, isNotNull;` at the top of the file (same pattern as Step 5 -- needed for `Value` in `copyWith` calls).

Add a test group `'DrillScreen -- line label display'`. Test cases:

- **Shows label above board when line has labels:** Build a line with a label on one move (e.g., move at index 1 labeled `'Sicilian'`), create a card, render the drill screen, pump through intro. Verify the label text `'Sicilian'` appears on screen via `find.text('Sicilian')`.

- **Label is hidden when line has no labels:** Build a line with no labels, render the drill screen, pump through intro. Assert `find.byKey(const ValueKey('drill-line-label'))` finds nothing. This is more robust than searching for a generic `Container`, since the `ValueKey` from Step 4 uniquely identifies the label header widget.

- **Label persists through user turn and mistake feedback states:** Verify the label text is still visible during `DrillUserTurn` and `DrillMistakeFeedback` states. Build a labeled line, pump through intro to `DrillUserTurn`, assert the label text is present. Then play a wrong move, pump to `DrillMistakeFeedback`, assert the label text is still present. Drain the revert timer afterward.

- **Aggregate label format (multiple labels):** Build a line with two labels ("Sicilian" on move at index 1 and "Najdorf" on move at index 3), verify the displayed text is "Sicilian — Najdorf" via `find.text('Sicilian — Najdorf')`.

- **Label updates when advancing to next card:** Build two lines with different deepest labels (e.g., card 1's line has label "Sicilian" and card 2's line has label "French"). Set up two due cards. Complete card 1 by playing all correct moves, pump through the next card's intro. Assert that the label text now shows "French" (card 2's label) and that "Sicilian" (card 1's label) is no longer on screen. This directly tests the spec requirement that the label "updates each time a new card begins."

Use the existing test helpers (`buildLine`, `buildReviewCard`, `FakeRepertoireRepository`, `FakeReviewRepository`, `buildTestApp`). Construct labeled moves using `copyWith(label: Value('...'))`.

**Depends on:** Steps 3, 4.

## Risks / Open Questions

1. **Repertoire name fallback.** The spec says the fallback "can be blank or show a generic fallback like the repertoire name." This plan implements the simpler option (blank/hidden). The blank approach is sufficient because the "Card N of M" title in the AppBar already provides context, and the absence of a label simply means the line is unnamed. If the fallback is wanted later, it can be added without breaking changes.

2. **State class proliferation.** Adding `lineLabel` to three state classes (`DrillCardStart`, `DrillUserTurn`, `DrillMistakeFeedback`) means every constructor call in the controller needs updating. The `lineLabel` field with a default of `''` minimizes breakage since all existing constructor calls will compile without changes, though they should be updated for correctness.

3. **Label with `Value` wrapper in `copyWith`.** The `RepertoireMove.copyWith` uses Drift's `Value<String?>` wrapper for the `label` parameter. Test code needs to use `copyWith(label: const Value('Sicilian'))` rather than `copyWith(label: 'Sicilian')`. Both unit test (Step 5) and widget test (Step 6) files need `import 'package:drift/drift.dart' hide isNull, isNotNull;` to bring `Value` into scope. The `hide` clause prevents conflicts with `flutter_test`'s `isNull`/`isNotNull` matchers -- this is the established convention in the test suite.

4. **Performance.** The `getLineLabelName()` method iterates the `lineMoves` list once in reverse (O(n) where n is the line depth, typically 5-20 moves), then calls `getAggregateDisplayName` which walks root-to-node (also O(n)). This is called once per card start, so performance is negligible.

5. **No interference guarantee.** The label is a static `Container` widget in the `Column` layout, above the `Expanded` `ChessboardWidget`. It does not participate in animations, does not affect board orientation, and does not interact with the intro move auto-play.
