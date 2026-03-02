# CT-10.2: Implementation Plan

## Goal

Add an inline label-filter box to the bottom of the drill screen, visible only in Free Practice mode, that allows the user to scope the card queue to subtrees of selected labels via autocomplete — with immediate queue updates on filter change.

## Steps

### 1. Add a queue-replacement method to `DrillEngine`

**File:** `src/lib/services/drill_engine.dart`

The `DrillEngine` currently receives a fixed card list at construction and has no way to swap it mid-session. Add a public method `replaceQueue(List<ReviewCard> newCards)` that:

- Accepts a new shuffled card list.
- Resets the queue contents via in-place mutation (`_session.cardQueue..clear()..addAll(newCards)`) and sets `_session.currentCardIndex` to 0.
- Clears `_currentCardState` and `_userColor` (same as `_advanceToNextCard` but resetting the index).
- This is the mechanism by which filter changes propagate into the engine.

**File:** `src/lib/models/review_card.dart`

Add a `resetQueue` method to `DrillSession` that uses in-place mutation, keeping the `final` modifier on `cardQueue`:
```dart
void resetQueue(List<ReviewCard> newCards) {
  cardQueue
    ..clear()
    ..addAll(newCards);
  currentCardIndex = 0;
}
```
No changes needed to the `final` keyword on `cardQueue`. Since `final` only prevents reassignment of the reference and `List` is mutable, `clear()` + `addAll()` works on the existing list instance.

### 2. Add filter state and `applyFilter` method to `DrillController`

**File:** `src/lib/screens/drill_screen.dart`

Add instance fields to `DrillController`:
- `Set<String> _selectedLabels = {}` — currently selected label strings.
- `List<String> _availableLabels = []` — all distinct labels in the repertoire (populated from `treeCache.getDistinctLabels()` during `build()`).
- Store `_treeCache` as an instance field (it is currently a local variable in `build()`; promote it so `applyFilter` can use it later).

Add a public method `Future<void> applyFilter(Set<String> labels)`:
1. Set `_selectedLabels = labels`.
2. **Immediately increment `_cardGeneration`** to cancel any in-flight intro animations or revert timers from the previous card. This must happen *before* any async work (DB fetches) so that stale callbacks from the previous card's `_autoPlayIntro` or `_revertAfterMistake` see the new generation and bail out via `_isStale(gen)`.
3. If labels is empty: load all cards via `_reviewRepo.getAllCardsForRepertoire(config.repertoireId)`.
4. If labels is non-empty: for each label, find all move IDs in `_treeCache.movesById.values` where `move.label == label`. For each such move ID, call `_reviewRepo.getCardsForSubtree(moveId)`. Collect all results, deduplicate by card ID, and shuffle.
5. Check the generation again after async work (`if (_isStale(gen)) return;`) to avoid applying stale filter results if the user changed the filter again during the fetch.
6. Call `_engine.replaceQueue(filteredCards)` (from step 1).
7. If the new queue is empty, emit the `DrillFilterNoResults` state (from step 3 below). The filter remains visible and editable.
8. If the new queue is non-empty, call `_startNextCard()` to begin the first card from the new filtered set.

During `build()`, after building the tree cache, populate `_availableLabels = treeCache.getDistinctLabels()` and save `_treeCache = treeCache`.

Add a public getter `List<String> get availableLabels => _availableLabels` and `Set<String> get selectedLabels => _selectedLabels` so the UI can read them.

### 3. Add an explicit empty-filter-results state variant

**File:** `src/lib/screens/drill_screen.dart`

Add a new state class to the sealed hierarchy:
```dart
class DrillFilterNoResults extends DrillScreenState {
  const DrillFilterNoResults();
}
```
This state is emitted exclusively when a label filter produces zero matching cards. It is distinct from `DrillSessionComplete` (which represents a finished session the user navigates away from) and from `DrillCardStart` (which assumes a real current card exists with `currentCardNumber`, `userColor`, etc.).

The `DrillFilterNoResults` state is handled in `_buildForState` by rendering the drill scaffold with the filter still visible and editable, a "No cards match this filter" message in the status area, the board in a neutral/disabled state (`PlayerSide.none`), and no skip button.

### 4. Build the filter UI widget

**File:** `src/lib/screens/drill_screen.dart`

Add a private method `_buildFilterBox(BuildContext context, WidgetRef ref)` that returns a `Widget` (or `null` if not in free practice mode):

- Only render if `config.isExtraPractice` is true.
- The widget is a `Container` at the bottom of the screen (below the status text in narrow layout, below the board panel in wide layout).
- Contents:
  - A row of `InputChip` widgets for each selected label, with an `onDeleted` callback that removes the label and calls `notifier.applyFilter(...)`.
  - A `RawAutocomplete<String>` (or Flutter's `Autocomplete` widget) text field for searching and adding labels.
    - `optionsBuilder`: filters `notifier.availableLabels` by the current input text (case-insensitive prefix/substring match), excluding already-selected labels.
    - `onSelected`: adds the label to the selected set and calls `notifier.applyFilter(...)`. Clears the text field.
  - If no labels are selected, show placeholder text like "Filter by label..." in the text field.

The text field should be compact and unobtrusive. Use `InputDecoration` with a search icon prefix and clear/compact styling to match the drill screen's existing aesthetic.

### 5. Integrate the filter box into the drill screen layout

**File:** `src/lib/screens/drill_screen.dart`

Modify `_buildDrillScaffold` to include the filter box:

- In the **narrow (mobile) layout** (`Column`): add the filter widget below the `statusWidget`, before the column ends. The layout becomes: `[lineLabelWidget, boardWidget (Expanded), statusWidget, filterBox]`.
- In the **wide layout** (`Row`): add the filter widget below the status widget in the right-side `Column`.
- The filter widget is conditionally included: only when `config.isExtraPractice` is true. In regular drill mode, nothing changes.

Ensure the filter box does not overlap the board or push the board off-screen. Since the board is in an `Expanded` widget in narrow layout, adding a fixed-height filter below the status text should work — the board will shrink slightly to accommodate.

Handle the `DrillFilterNoResults` state in `_buildForState`: render it through `_buildDrillScaffold` with neutral board orientation (`Side.white` default), `PlayerSide.none`, `showSkip: false`, and an empty `lineLabel`. The status text builder handles this state by displaying "No cards match this filter."

### 6. Handle filter interaction during active card play

**File:** `src/lib/screens/drill_screen.dart`

When the user changes the filter while a card is in progress (mid-intro or mid-user-turn):

- `applyFilter` increments `_cardGeneration` **at the very start**, before any async DB fetches. This immediately invalidates any in-flight intro animations or revert timers via the existing `_isStale(gen)` mechanism. The previous plan only bumped generation inside `_startNextCard`, which left a window between the filter request and queue replacement where stale callbacks could still fire.
- The current card is abandoned (not scored, not counted as skipped) and the session restarts with the new filtered queue.
- Do NOT reset `_completedCards` and `_skippedCards` counters. The user may filter, do some cards, re-filter, do more. Resetting would lose their progress count. Keep cumulative counters and only reset them if a future "Keep Going" feature (CT-10.3) explicitly resets.

### 7. Populate the filter from tree cache label-to-moveId mapping

**File:** `src/lib/screens/drill_screen.dart` (in `applyFilter`)

The `RepertoireTreeCache` stores all moves indexed by ID. To find move IDs for a given label string:

```dart
final moveIdsForLabel = _treeCache.movesById.values
    .where((m) => labels.contains(m.label))
    .map((m) => m.id)
    .toList();
```

Then for each move ID, call `_reviewRepo.getCardsForSubtree(moveId)` and collect + deduplicate. Use a `Set<int>` of card IDs to deduplicate:

```dart
final seen = <int>{};
final cards = <ReviewCard>[];
for (final moveId in moveIdsForLabel) {
  final subtreeCards = await _reviewRepo.getCardsForSubtree(moveId);
  for (final card in subtreeCards) {
    if (seen.add(card.id)) cards.add(card);
  }
}
cards.shuffle();
```

### 8. Write tests

**Files:** new test file `src/test/screens/drill_filter_test.dart` or extend existing drill tests.

Test cases:
- Filter box is visible in free practice mode, not visible in regular drill mode.
- Selecting a label scopes cards to the correct subtree.
- Selecting multiple labels unions the subtrees (with deduplication).
- Clearing all labels returns to the full card set.
- Changing the filter mid-card correctly abandons the current card and starts the new queue.
- Empty filter result shows `DrillFilterNoResults` state with filter still editable.
- Changing filter from an empty-result state to a valid label correctly starts the new queue.
- `DrillEngine.replaceQueue` correctly resets the queue and index.

## Risks / Open Questions

1. **Performance of multi-label filtering.** Each selected label triggers one or more `getCardsForSubtree` calls, each executing a recursive CTE. For repertoires with many labels, this could be slow. Mitigation: labels are typically few (5-20 per repertoire). If performance is an issue, the filtering could be done entirely in-memory using the tree cache instead of SQL queries. The tree cache already has `getSubtree(moveId)` which returns all descendant moves — we could intersect those with known leaf move IDs to produce the card list without DB calls. However, this requires having the full card list in memory. Since `getAllCardsForRepertoire` is already called at session start for free practice, we could keep it in memory and filter in-memory rather than re-querying.

2. **Label-to-moveId is many-to-many.** Multiple moves can share the same label string (e.g., "Najdorf" might label two different nodes if the user duplicated it). The current plan handles this correctly by iterating all moves with the matching label. But the autocomplete should show each distinct label string only once (which `getDistinctLabels()` already ensures).

3. **Keyboard and focus management.** The autocomplete text field at the bottom of the drill screen could cause the keyboard to cover the board on mobile. Consider using `resizeToAvoidBottomInset: true` on the `Scaffold` (the default), which will push the layout up when the keyboard appears. Alternatively, the filter could use a compact chip-based UI that opens a bottom sheet or overlay for label selection instead of an inline text field. Start with inline and adjust based on testing.

4. **Interaction during intro animation.** If the user interacts with the filter while intro moves are animating, the `_cardGeneration` mechanism should correctly cancel the animation. The plan now ensures `_cardGeneration` is incremented at the start of `applyFilter` before any async work, closing the race window. Verify this in testing.

5. **Session summary accuracy.** When the filter changes mid-session, the completed/skipped counts reflect cards from potentially different filter scopes. The summary may show "5 cards reviewed" even though the user switched filters partway through. This is acceptable for free practice (no SR updates), but the summary could be confusing. Consider whether to note the filter changes in the summary, or simply accept the combined count.

6. **CT-10.3 interaction ("Keep Going").** The "Keep Going" feature (CT-10.3) will need to know the current filter state to reload the same filtered card set. The `_selectedLabels` field added here provides that. Ensure the field persists across the session-complete state transition so CT-10.3 can read it.

7. **Review issue: in-place list mutation vs. removing `final`.** The reviewer flagged that removing `final` from `DrillSession.cardQueue` is unnecessary churn. This is correct — `final` on a `List` field only prevents reassignment of the reference; the list itself is fully mutable via `clear()` + `addAll()`. The revised plan (Step 1) uses in-place mutation and keeps `final`.

8. **Review issue: `DrillFilterNoResults` state variant.** The reviewer flagged that reusing `DrillCardStart(totalCards: 0)` would violate that state's contract (it assumes a real current card with `currentCardNumber`, `userColor`, line context). The revised plan (Step 3) adds an explicit `DrillFilterNoResults` state variant to avoid invalid UI states like "1/0" card counter, skip-on-empty-queue, and undefined board orientation.
