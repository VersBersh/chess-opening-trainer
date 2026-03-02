- **Verdict** — Approved with Notes
- **Issues**
1. **Major — Hidden semantic coupling in `DrillConfig` card-source contract (Hidden Coupling, Embedded Design Principle)**  
   In [drill_screen.dart:182](/C:/code/misc/chess-trainer-1/src/lib/screens/drill_screen.dart:182), card loading behavior depends on the *combination* of `isExtraPractice` and whether `preloadedCards` is `null`. This makes `null` vs empty list semantically significant but not explicit in the API (`DrillConfig` at [drill_screen.dart:27](/C:/code/misc/chess-trainer-1/src/lib/screens/drill_screen.dart:27)). A caller passing `preloadedCards: []` in free-practice mode gets immediate completion instead of repository loading, which is easy to misuse.  
   **Why it matters:** behavior is correct only if callers know an implicit rule; this is a semantic coupling hazard.  
   **Suggested fix:** replace the implicit `null` contract with an explicit source model (for example, `enum CardSource { due, all, provided }` + `providedCards`), so configuration communicates intent directly.

2. **Minor — Repeated mode/title branching in UI paths (DRY, Single Responsibility at method level)**  
   The same `config.isExtraPractice ? 'Free Practice' : 'Drill'` / title-format branching appears in multiple places ([drill_screen.dart:466](/C:/code/misc/chess-trainer-1/src/lib/screens/drill_screen.dart:466), [drill_screen.dart:470](/C:/code/misc/chess-trainer-1/src/lib/screens/drill_screen.dart:470), [drill_screen.dart:523](/C:/code/misc/chess-trainer-1/src/lib/screens/drill_screen.dart:523), [drill_screen.dart:535](/C:/code/misc/chess-trainer-1/src/lib/screens/drill_screen.dart:535), [drill_screen.dart:549](/C:/code/misc/chess-trainer-1/src/lib/screens/drill_screen.dart:549), [drill_screen.dart:565](/C:/code/misc/chess-trainer-1/src/lib/screens/drill_screen.dart:565)).  
   **Why it matters:** small text/design changes now require multi-site edits and increase divergence risk.  
   **Suggested fix:** centralize with helper getters like `_screenTitle(config)` and `_progressTitle(config, drillState)`.

3. **Minor — File-size code smell in modified files (Clean Code: File Size)**  
   Modified files exceed the 300-line threshold: [drill_screen.dart](/C:/code/misc/chess-trainer-1/src/lib/screens/drill_screen.dart) (~872), [home_screen.dart](/C:/code/misc/chess-trainer-1/src/lib/screens/home_screen.dart) (~367), [drill_screen_test.dart](/C:/code/misc/chess-trainer-1/src/test/screens/drill_screen_test.dart) (~1272), [home_screen_test.dart](/C:/code/misc/chess-trainer-1/src/test/screens/home_screen_test.dart) (~757).  
   **Why it matters:** high cognitive load and weaker architectural readability.  
   **Suggested fix:** split by responsibility (for example, move `DrillScreenState`/summary widgets/controller into separate files; split large test files by feature groups).