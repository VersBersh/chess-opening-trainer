**Verdict** — Needs Revision

**Issues**
1. **Major — Step 7 (tests): removes extension-undo coverage without replacement.**  
   The plan deletes `group('Extension undo snackbar', ...)` from [repertoire_browser_screen_test.dart](/C:/code/misc/chess-trainer-2/src/test/screens/repertoire_browser_screen_test.dart), but equivalent UI coverage is not added to [add_line_screen_test.dart](/C:/code/misc/chess-trainer-2/src/test/screens/add_line_screen_test.dart), where extension/undo now lives. This creates a regression risk for a critical flow (card restoration + line rollback).  
   **Fix:** Add extension/undo widget tests to `add_line_screen_test.dart` before deleting the old group.

2. **Major — Step 5 vs Step 7: behavior specified but not fully tested.**  
   Step 5 defines a no-card path (`"No review card for this move."` snackbar), but Step 7 does not include a test for this branch. Given `getCardForLeaf()` can return `null` (confirmed in [local_review_repository.dart](/C:/code/misc/chess-trainer-2/src/lib/repositories/local/local_review_repository.dart)), this is an important edge case.  
   **Fix:** Add a test that selects a leaf without a card, taps Stats, and asserts snackbar text.

3. **Minor — Step 5 availability rule is slightly off-spec.**  
   Feature spec says View Card Stats is available when the selected node is a leaf **with an associated review card** ([features/repertoire-browser.md](/C:/code/misc/chess-trainer-2/features/repertoire-browser.md)). Plan enables Stats for any leaf and handles missing card at click time. That is workable, but not a strict match.  
   **Fix:** Either (a) disable Stats unless selected leaf has a card, or (b) explicitly note this intentional UX deviation in plan risks/decisions.

4. **Minor — Step 4/5 action-bar changes should explicitly cover both layouts.**  
   The screen has compact and non-compact action bars in [repertoire_browser_screen.dart](/C:/code/misc/chess-trainer-2/src/lib/screens/repertoire_browser_screen.dart). Plan text is explicit for Edit/Focus removal, but not explicit enough that Add Line/Stats must be added in both compact and full-width branches.  
   **Fix:** State explicitly that both `_buildBrowseModeActionBar(..., compact: true/false)` variants are updated, and add at least one wide-layout test if feasible.