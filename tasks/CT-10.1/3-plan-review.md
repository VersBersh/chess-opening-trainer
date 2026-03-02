**Verdict** — Needs Revision

**Issues**
1. **Major (Step 9): Core behavior is not being validated.**  
   The plan adds only a visual-indicator test, but the key functional change is that Free Practice with `preloadedCards == null` must load via `getAllCardsForRepertoire`, not due cards.  
   **Fix:** Add a dedicated drill-screen test that launches with `DrillConfig(isExtraPractice: true)` and no `preloadedCards`, with fake repo data where `dueCards` is empty but `allCards` is non-empty, and assert a real card session starts (not immediate empty completion).

2. **Major (Step 9, prerequisite): Current test fake can’t verify due-vs-all behavior.**  
   In `drill_screen_test.dart`, `FakeReviewRepository.getAllCardsForRepertoire()` returns the same list as due cards, so Step 1’s branch cannot be proven.  
   **Fix:** Extend the fake to store separate `dueCards` and `allCards` (as done in home screen tests), then use that in the new Step 9 test.

3. **Minor (Step 5): Loading-title coverage is incomplete/ambiguous.**  
   There are multiple loading paths in `DrillScreen` (top-level async loading and `DrillLoading` state). The plan mentions loading/error titles, but should explicitly include all loading AppBar paths so Free Practice labeling is consistent.  
   **Fix:** Explicitly list both loading scaffolds in Step 5 acceptance checks.