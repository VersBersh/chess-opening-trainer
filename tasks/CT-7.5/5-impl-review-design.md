**Verdict** — Approved with Notes

**Issues**
1. **Major — Single Responsibility / File Size / Embedded Design**
   - [home_screen.dart:112](C:/code/misc/chess-trainer-2/src/lib/screens/home_screen.dart:112) defines controller interaction, navigation orchestration, empty-state flow, and full card-list rendering in one state class; file is now 364 lines.
   - Why it matters: this increases cognitive load and gives the module multiple reasons to change (state loading, navigation policy, UI composition), making future feature work riskier.
   - Suggested fix: split into focused units, e.g. `home_controller.dart` (state/load/open logic), `home_screen.dart` (page shell), and reusable widgets like `repertoire_card.dart` / `home_empty_state.dart`.

2. **Major — Clean Code (File Size) / DRY in Tests**
   - [home_screen_test.dart:189](C:/code/misc/chess-trainer-2/src/test/screens/home_screen_test.dart:189) has grown to 758 lines, with repeated `ReviewCard(...)` fixture construction across many tests (for example at [home_screen_test.dart:198](C:/code/misc/chess-trainer-2/src/test/screens/home_screen_test.dart:198), [home_screen_test.dart:539](C:/code/misc/chess-trainer-2/src/test/screens/home_screen_test.dart:539), [home_screen_test.dart:614](C:/code/misc/chess-trainer-2/src/test/screens/home_screen_test.dart:614)).
   - Why it matters: duplication obscures intent and makes test maintenance error-prone when model fields evolve.
   - Suggested fix: extract fixture helpers (e.g. `makeReviewCard({repertoireId, leafMoveId})`) and split test groups into smaller files by behavior (`home_due_count_test.dart`, `home_actions_test.dart`, `home_layout_test.dart`).

3. **Minor — Hidden/Semantic Coupling in Tests**
   - The navigation tests rely on implicit alignment between fake repo defaults and DB seed assumptions: default fake repertoire `id:1, name:'Test'` ([home_screen_test.dart:30](C:/code/misc/chess-trainer-2/src/test/screens/home_screen_test.dart:30)) and DB inserts of `'Test'` ([home_screen_test.dart:691](C:/code/misc/chess-trainer-2/src/test/screens/home_screen_test.dart:691), [home_screen_test.dart:717](C:/code/misc/chess-trainer-2/src/test/screens/home_screen_test.dart:717)).
   - Why it matters: tests can fail for incidental fixture changes rather than behavior regressions.
   - Suggested fix: make coupling explicit per test by creating `FakeRepertoireRepository(repertoires: [...])` from the inserted DB row ID/name, instead of depending on shared defaults.

