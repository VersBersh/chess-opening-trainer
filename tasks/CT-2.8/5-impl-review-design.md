- **Verdict** — Needs Fixes

- **Issues**
1. **Major — Interface Segregation / Dependency Inversion violation: `RepertoireRepository` now depends on review-table types**
   - Code: [`repertoire_repository.dart:26`](C:\code\misc\chess-trainer-1\src\lib\repositories\repertoire_repository.dart:26), [`local_repertoire_repository.dart:177`](C:\code\misc\chess-trainer-1\src\lib\repositories\local\local_repertoire_repository.dart:177), usage at [`add_line_controller.dart:561`](C:\code\misc\chess-trainer-1\src\lib\controllers\add_line_controller.dart:561).
   - Why it matters: `RepertoireRepository` is no longer focused on repertoire concerns; it now requires `ReviewCardsCompanion`. That leaks DB schema details across module boundaries and forced unrelated fakes to grow (`drill_filter_test.dart`, `drill_screen_test.dart`, `home_screen_test.dart`), which is a concrete sign of interface bloat.
   - Suggested fix: move branch persistence to a dedicated orchestration abstraction (e.g., `LinePersistenceService`) or a repository method that accepts domain-level inputs (not `ReviewCardsCompanion`) and internally creates the review card.

2. **Major — Hidden semantic coupling via sentinel `leafMoveId: 0` contract**
   - Code: placeholder creation at [`add_line_controller.dart:563`](C:\code\misc\chess-trainer-1\src\lib\controllers\add_line_controller.dart:563), overwrite assumption at [`local_repertoire_repository.dart:192`](C:\code\misc\chess-trainer-1\src\lib\repositories\local\local_repertoire_repository.dart:192).
   - Why it matters: correctness depends on an implicit “caller passes invalid leaf id, callee must overwrite it” rule. That temporal/semantic coupling is not enforced by types and is easy to break during refactors.
   - Suggested fix: change `saveBranch` signature to accept only branch inputs needed to build the card (`repertoireId`, `nextReviewDate`) and construct `ReviewCardsCompanion` entirely inside the repository/service.

3. **Minor — File-size design smell in modified files**
   - Code: [`add_line_controller.dart`](C:\code\misc\chess-trainer-1\src\lib\controllers\add_line_controller.dart) (~644 lines), [`add_line_screen.dart`](C:\code\misc\chess-trainer-1\src\lib\screens\add_line_screen.dart) (~503 lines), plus several very large modified test files.
   - Why it matters: these exceed the 300-line smell threshold and make architectural intent harder to read, especially where orchestration, UI behavior, and persistence error handling are all mixed.
   - Suggested fix: extract focused units (e.g., confirm/persist workflow object, snackbar/error presenter helpers, test helper modules) to reduce cognitive load and improve SRP clarity.