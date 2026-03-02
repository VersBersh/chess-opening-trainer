# 2-plan.md

## Goal

Verify that line name display already works correctly in Free Practice mode (since CT-8 implemented it using shared code paths), and add Free-Practice-specific widget tests to explicitly confirm this behavior.

## Steps

### 1. Verify implementation completeness (no code changes needed)

**Files:** `src/lib/screens/drill_screen.dart`, `src/lib/services/drill_engine.dart`

After tracing all code paths, the line label display is already fully functional in Free Practice mode:

- `DrillEngine.getLineLabelName()` is mode-agnostic (no `isExtraPractice` check).
- `DrillController.build()` calls `_currentLineLabel = _engine.getLineLabelName()` unconditionally after `_engine.startCard()`.
- `DrillController._startNextCard()` does the same.
- All state class constructors (`DrillCardStart`, `DrillUserTurn`, `DrillMistakeFeedback`) receive `lineLabel: _currentLineLabel`.
- `_buildDrillScaffold` renders the label widget when `lineLabel.isNotEmpty`, regardless of mode.
- `keepGoing()` calls `_startNextCard()`, so labels work across passes.
- `applyFilter()` calls `_startNextCard()`, so labels work after filter changes.

**No production code changes are required.**

### 2. Add widget tests confirming line label display in Free Practice mode

**File:** `src/test/screens/drill_screen_test.dart`

Add a new test group within or alongside the existing `'DrillScreen -- free practice'` group. The existing `'DrillScreen -- line label display'` group only tests with the default config (regular drill). Adding Free-Practice-specific tests provides explicit coverage for the acceptance criteria.

Test cases to add:

**2a. "shows line label above board in Free Practice mode"**
- Build a line with a label (e.g., `label: 'Sicilian'` on one move).
- Create a `DrillConfig` with `isExtraPractice: true` and `preloadedCards: [card]`.
- Render the drill screen, pump through intro.
- Assert `find.text('Sicilian')` finds one widget.
- Assert `find.byKey(const ValueKey('drill-line-label'))` finds one widget.

**2b. "line label is hidden in Free Practice when line has no labels"**
- Build a line with no labels.
- Create a `DrillConfig` with `isExtraPractice: true`.
- Render, pump through intro.
- Assert `find.byKey(const ValueKey('drill-line-label'))` finds nothing.

**2c. "line label updates after Keep Going in Free Practice"**
- Build a single-card session with a labeled line, `isExtraPractice: true`.
- Complete the card, arrive at `DrillPassComplete`.
- Tap "Keep Going", pump through intro of the reshuffled card.
- Assert the label text is still present (same card, same label).

**2d. "line label updates after filter change in Free Practice"** (optional, lower priority)
- Build two lines with different labels.
- Start a free practice session with all cards.
- Apply a filter that selects only one label.
- Assert the label shown corresponds to the filtered card.

**Depends on:** Step 1 (verification that no production code changes are needed).

## Risks / Open Questions

1. **This task may already be "done."** The implementation analysis shows that CT-8 implemented the line label using mode-agnostic shared code. Both regular Drill and Free Practice use identical code paths for label computation, state propagation, and rendering. The only gap is explicit test coverage -- there are no widget tests that verify line label display specifically in Free Practice mode (with `isExtraPractice: true`). **Recommendation:** Add the tests (Step 2) to provide explicit proof that the acceptance criteria are met, and to guard against future regressions if the shared code paths are ever split.

2. **Repertoire name fallback.** The spec says "If the line has no labels, the header area is blank or shows the repertoire name as a fallback." The current implementation shows blank (hidden). This matches the CT-8 decision and is noted in `tasks/CT-8/2-plan.md` Risks section. No change is needed for this task.

3. **Test scaffolding.** The existing free practice widget tests use `preloadedCards` with `FakeRepertoireRepository` and `FakeReviewRepository`. The new tests should follow the same pattern. Labeled lines can be constructed using `buildLine` + `copyWith(label: const Value('...'))`, as already done in the CT-8 line label test group.
