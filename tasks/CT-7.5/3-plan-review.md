**Verdict** — Needs Revision

**Issues**
1. **Critical — Step 2/3 ordering is backwards.**  
   Step 2 calls `_onAddLineTap(summary.repertoire.id)` and `_onRepertoireTap(summary.repertoire.id)`, but those methods currently take no parameters; the refactor is in Step 3.  
   **Fix:** Move the method-signature refactor before (or together with) Step 2, or have Step 2 use temporary closures until Step 3 lands.

2. **Major — Step 6 navigation test for Add Line is likely invalid with current test harness.**  
   `AddLineScreen` uses real `AppDatabase` + `AddLineController.loadData()` and calls `getRepertoire(repertoireId)` via local repo. In `home_screen_test.dart`, the in-memory DB is not seeded with matching repertoire rows, so pushing `AddLineScreen` can throw.  
   **Fix:** Seed the test DB with a repertoire matching the tapped `repertoireId` before asserting Add Line navigation, or inject a fake Add Line destination in tests.

3. **Major — Step 5/6 has contradictory and partially incorrect fake-repo guidance for `totalCardCount`.**  
   Plan says to make `getAllCardsForRepertoire()` configurable (correct), but later says existing filtering over `dueCards` “already works” for no-cards scenarios (not sufficient for `dueCount == 0 && totalCardCount > 0`).  
   **Fix:** Split fake data into separate `allCards` and `dueCards` collections and use them independently in fake methods.

4. **Major — Test update scope is incomplete for removed global controls.**  
   Existing tests assert a global `'Repertoire'` button and `'Free Practice disabled when no repertoire exists'`. With the new per-card UI + empty state, these expectations are no longer valid.  
   **Fix:** Explicitly replace/remove those tests with card-based and empty-state assertions (including “Create your first repertoire” CTA).

5. **Major — Drill no-due behavior in Step 2 conflicts with spec.**  
   `features/home-screen.md` says per-repertoire drill should remain tappable when no due cards and show a brief message; Step 2 disables the button (`onPressed: null`).  
   **Fix:** Keep Start Drill tappable and show snackbar/toast when `dueCount == 0` instead of disabling.

6. **Minor — Empty-state creation flow in Step 4 deviates from spec’d naming prompt.**  
   Spec describes “Create repertoire” via name entry; plan uses `openRepertoire()` auto-creating `"My Repertoire"`.  
   **Fix:** Either add a “deferred” note with rationale, or include a follow-up step to align empty-state creation with the name-entry flow.