**Verdict** — `Needs Fixes`

**Issues**
1. **Major — Dependency Inversion / Layering violation**  
   [`repertoire_repository.dart:2`](/C:/code/misc/chess-trainer-7/src/lib/repositories/repertoire_repository.dart:2), [`repertoire_repository.dart:36`](/C:/code/misc/chess-trainer-7/src/lib/repositories/repertoire_repository.dart:36), [`line_persistence_service.dart:14`](/C:/code/misc/chess-trainer-7/src/lib/services/line_persistence_service.dart:14), [`local_repertoire_repository.dart:3`](/C:/code/misc/chess-trainer-7/src/lib/repositories/local/local_repertoire_repository.dart:3)  
   `RepertoireRepository` now depends on `PendingLabelUpdate` defined in `line_persistence_service.dart` (service layer), and the local repository imports that service type. This creates upward coupling and leaks use-case specifics into a core abstraction.  
   **Why it matters:** it weakens module boundaries, makes repository interfaces harder to reuse, and forces unrelated callers/tests to import service-layer concepts.  
   **Suggested fix:** move `PendingLabelUpdate` into a repository/domain-level module (or define a repository-owned DTO), then have `LinePersistenceService` depend on that abstraction.

2. **Major — Hidden temporal coupling in `updateLabel` contract**  
   [`add_line_controller.dart:665`](/C:/code/misc/chess-trainer-7/src/lib/controllers/add_line_controller.dart:665), [`add_line_controller.dart:697`](/C:/code/misc/chess-trainer-7/src/lib/controllers/add_line_controller.dart:697), [`add_line_controller.dart:674`](/C:/code/misc/chess-trainer-7/src/lib/controllers/add_line_controller.dart:674), [`add_line_screen.dart:453`](/C:/code/misc/chess-trainer-7/src/lib/screens/add_line_screen.dart:453)  
   `updateLabel()` is documented for saved pills, but it does not enforce that precondition. For buffered/out-of-range indices, `_getOriginalLabel()` returns `null`, and `_pendingLabels[pillIndex]` may still be written; later persistence ignores these entries because `getMoveIdAtPillIndex()` returns `null`.  
   **Why it matters:** behavior relies on callers invoking methods in the right order/path (saved pill -> `updateLabel`, unsaved -> `updateBufferedLabel`) with no guard; misuse fails silently.  
   **Suggested fix:** enforce preconditions in `updateLabel` (bounds + saved-pill check) and early-return or assert/throw on invalid usage.

3. **Minor — DRY / maintainability regression in repository transactions**  
   [`local_repertoire_repository.dart:140`](/C:/code/misc/chess-trainer-7/src/lib/repositories/local/local_repertoire_repository.dart:140), [`local_repertoire_repository.dart:178`](/C:/code/misc/chess-trainer-7/src/lib/repositories/local/local_repertoire_repository.dart:178), [`local_repertoire_repository.dart:250`](/C:/code/misc/chess-trainer-7/src/lib/repositories/local/local_repertoire_repository.dart:250), [`local_repertoire_repository.dart:297`](/C:/code/misc/chess-trainer-7/src/lib/repositories/local/local_repertoire_repository.dart:297)  
   `extendLineWithLabelUpdates` and `saveBranchWithLabelUpdates` duplicate substantial logic from `extendLine` and `saveBranch`.  
   **Why it matters:** future fixes in insert/card logic must be applied in 4 places, increasing divergence risk.  
   **Suggested fix:** extract shared private helpers for chain insertion/card creation and parameterize label-update step.

4. **Minor — File size smell (readability/architecture pressure)**  
   [`add_line_controller.dart`](/C:/code/misc/chess-trainer-7/src/lib/controllers/add_line_controller.dart), [`add_line_screen.dart`](/C:/code/misc/chess-trainer-7/src/lib/screens/add_line_screen.dart), [`local_repertoire_repository.dart`](/C:/code/misc/chess-trainer-7/src/lib/repositories/local/local_repertoire_repository.dart), [`add_line_controller_test.dart`](/C:/code/misc/chess-trainer-7/src/test/controllers/add_line_controller_test.dart), [`line_persistence_service_test.dart`](/C:/code/misc/chess-trainer-7/src/test/services/line_persistence_service_test.dart)  
   Modified files include multiple >300-line units (controller ~798, screen ~594, repository ~391, tests much larger).  
   **Why it matters:** harder to understand architecture from code alone; responsibilities are becoming diffuse.  
   **Suggested fix:** extract pending-label behavior into a focused collaborator/service and split large widget/controller/test modules by concern.