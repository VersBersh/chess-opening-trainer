- **Verdict** — `Needs Fixes`

- **Issues**
1. **Major — Hidden side effects / error-state handling (Clean Code, Temporal Coupling)**  
   In [`home_screen.dart`](/C:/code/misc/chess-trainer-1/src/lib/screens/home_screen.dart#L64), `refresh()` sets `state` to loading and then awaits `_load()` directly. If `_load()` throws, the provider can be left in loading and the exception bubbles from callbacks at [`home_screen.dart`](/C:/code/misc/chess-trainer-1/src/lib/screens/home_screen.dart#L109) and [`home_screen.dart`](/C:/code/misc/chess-trainer-1/src/lib/screens/home_screen.dart#L123).  
   Why it matters: refresh becomes failure-prone and can produce a stuck spinner/unhandled async error path.  
   Suggested fix: use guarded assignment so failure transitions to `AsyncError`, e.g. `state = await AsyncValue.guard(_load);` (optionally keep previous data during refresh).

2. **Major — Dependency direction is inverted at module level (DIP, Embedded Design Principle)**  
   [`home_screen.dart`](/C:/code/misc/chess-trainer-1/src/lib/screens/home_screen.dart#L4) imports [`main.dart`](/C:/code/misc/chess-trainer-1/src/lib/main.dart#L17) to access providers. A feature screen/controller depending on the app entrypoint creates architectural back-coupling.  
   Why it matters: composition root and feature layer become mutually entangled, making architecture harder to read and evolve safely.  
   Suggested fix: move shared providers (e.g., `repertoireRepositoryProvider`, `reviewRepositoryProvider`) into a dedicated module (for example `lib/providers/repository_providers.dart`) imported by both `main.dart` and feature screens.

3. **Minor — Semantic coupling between total due count and selected drill repertoire (Hidden Coupling, SRP boundary clarity)**  
   `HomeState.totalDueCount` aggregates all repertoires in [`home_screen.dart`](/C:/code/misc/chess-trainer-1/src/lib/screens/home_screen.dart#L51), but “Start Drill” always launches the first repertoire from [`home_screen.dart`](/C:/code/misc/chess-trainer-1/src/lib/screens/home_screen.dart#L163) and [`home_screen.dart`](/C:/code/misc/chess-trainer-1/src/lib/screens/home_screen.dart#L189).  
   Why it matters: with multiple repertoires, UI may show cards due but open a repertoire with none due.  
   Suggested fix: either compute drill target repertoire based on due cards, or explicitly enforce/document single-repertoire invariant until multi-repertoire UX is implemented.

4. **Minor — Test file size/duplication smell (Clean Code: File Size, DRY)**  
   [`home_screen_test.dart`](/C:/code/misc/chess-trainer-1/src/test/screens/home_screen_test.dart#L1) is ~399 lines and duplicates fake repositories already present in drill tests.  
   Why it matters: duplicated test infra increases maintenance cost and drifts easily.  
   Suggested fix: extract shared fakes/builders into `src/test/helpers/` and keep screen test files focused on scenarios.