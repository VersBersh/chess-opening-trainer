- **Verdict** — `Needs Fixes`

- **Progress**
  - [x] Step 1: Add queue-replacement method (`DrillSession.resetQueue`, `DrillEngine.replaceQueue`) — **Done**
  - [x] Step 2: Add filter state + `applyFilter` in controller — **Done**
  - [x] Step 3: Add explicit `DrillFilterNoResults` state variant — **Done**
  - [x] Step 4: Build filter UI widget (chips + autocomplete) — **Done**
  - [ ] Step 5: Integrate filter box into layout and fully match no-results scaffold behavior — **Partially done**
  - [x] Step 6: Handle mid-card filter interaction with early generation bump + keep counters — **Done**
  - [x] Step 7: Label-to-moveId mapping + subtree union + dedupe — **Done**
  - [ ] Step 8: Tests — **Partially done**

- **Issues**
  1. **Major** — No-results state does not reset board position to neutral start, so stale board position can persist after filtering to zero cards.  
     References: [drill_screen.dart:515](/C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:515), [drill_screen.dart:517](/C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:517), [drill_screen.dart:651](/C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:651), [drill_screen.dart:701](/C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:701)  
     Why: Plan Step 3/5 requires neutral/disabled board for `DrillFilterNoResults`. `applyFilter` emits `DrillFilterNoResults` without resetting `boardController`, so UI can show leftover in-line position from prior card.  
     Suggested fix: Before setting `DrillFilterNoResults`, call `boardController.resetToInitial()` (or equivalent neutral reset) so board state matches the state contract.

  2. **Major** — Test deliverable is incomplete relative to the plan: missing explicit “change filter mid-card abandons current card safely” coverage (generation/stale-callback path).  
     References: [drill_filter_test.dart:397](/C:/code/misc/chess-trainer-2/src/test/screens/drill_filter_test.dart:397), [drill_filter_test.dart:741](/C:/code/misc/chess-trainer-2/src/test/screens/drill_filter_test.dart:741)  
     Why: Plan Step 8 explicitly calls for mid-card filter-change behavior verification. Current tests cover visibility, empty results, label selection, and queue reset, but do not assert stale intro/revert callbacks are cancelled when filtering during active play.  
     Suggested fix: Add a widget/controller test that starts a card, triggers intro/revert timing, changes filter immediately, then asserts no stale callback mutates board/state from the old generation.

  3. **Minor** — Wide-layout placement is centered, not bottom-anchored as described in the plan/goal.  
     Reference: [drill_screen.dart:744](/C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:744)  
     Why: Right-side column uses `mainAxisAlignment: MainAxisAlignment.center`, so filter/status stack sits in the middle rather than bottom area.  
     Suggested fix: Use bottom-aligned composition for wide layout (e.g., spacer + status/filter at bottom) if strict plan adherence is required.

  4. **Minor** — `applyFilter` stores external mutable set reference directly.  
     Reference: [drill_screen.dart:477](/C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:477)  
     Why: `_selectedLabels = labels;` can alias caller-owned mutable data. Current callers create fresh sets, so risk is low, but controller API is public.  
     Suggested fix: defensively copy: `_selectedLabels = Set<String>.of(labels);`.

