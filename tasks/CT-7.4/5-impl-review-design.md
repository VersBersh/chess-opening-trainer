- **Verdict** — `Needs Fixes`
- **Issues**
1. **Major — Hidden Coupling / Semantic + Temporal Coupling (provider key collision risk)**  
   `DrillConfig` intentionally excludes `preloadedCards` from equality/hashCode, but that same config is the Riverpod family key.  
   References: [drill_screen.dart:25](/C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:25), [drill_screen.dart:37](/C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:37), [drill_screen.dart:136](/C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:136), [drill_screen.dart:168](/C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:168), [free_practice_setup_screen.dart:137](/C:/code/misc/chess-trainer-2/src/lib/screens/free_practice_setup_screen.dart:137).  
   Why it matters: two free-practice launches for the same repertoire (`isExtraPractice: true`) can map to the same provider instance despite different card sets. That can reuse stale session state or wrong cards depending on route timing/disposal behavior. This is a real correctness risk, not just style.  
   Suggested fix: include a stable session discriminator in the family key (for example `sessionId`), or include a deterministic card-set identity in equality/hashCode (for example sorted card IDs hash). Do not key provider identity only by repertoire + mode when payload differs.

2. **Major — Dependency Inversion leak (UI/controller API depends on persistence entity)**  
   `DrillScreen`/`DrillConfig` now directly accepts `List<ReviewCard>` from `database.dart`.  
   References: [drill_screen.dart:9](/C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:9), [drill_screen.dart:28](/C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart:28).  
   Why it matters: screen-level orchestration is now coupled to Drift row model shape. Any persistence-schema refactor can force UI/controller API changes. This weakens module boundaries and makes extension harder.  
   Suggested fix: pass a domain-level drill input model (for example `DrillCardRef`/`PracticeSessionSeed`) and map DB types in repository/service layer.

3. **Minor — File size / Single Responsibility code smell (explicitly requested threshold >300 lines)**  
   Modified files above 300 lines: [drill_screen.dart](/C:/code/misc/chess-trainer-2/src/lib/screens/drill_screen.dart), [drill_screen_test.dart](/C:/code/misc/chess-trainer-2/src/test/screens/drill_screen_test.dart), [home_screen_test.dart](/C:/code/misc/chess-trainer-2/src/test/screens/home_screen_test.dart), [drill_engine_test.dart](/C:/code/misc/chess-trainer-2/src/test/services/drill_engine_test.dart).  
   Why it matters: design intent is harder to read; responsibilities are mixed (state model, controller orchestration, widget rendering, and mode-specific behavior in one large unit).  
   Suggested fix: split `drill_screen.dart` into `drill_config.dart`, `drill_controller.dart`, `drill_state.dart`, and `drill_screen_view.dart`; split long test files by concern (`free_practice`, `mistake_feedback`, `summary`, etc.).