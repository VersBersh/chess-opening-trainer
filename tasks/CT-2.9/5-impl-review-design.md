- **Verdict** — `Approved with Notes`
- **Issues** —
1. **Major — Hidden temporal/semantic coupling (preconditions are implicit, not enforced)**  
   In [`line_persistence_service.dart` line 59](/C:/code/misc/chess-trainer-5/src/lib/services/line_persistence_service.dart#L59) and [`line_persistence_service.dart` line 105](/C:/code/misc/chess-trainer-5/src/lib/services/line_persistence_service.dart#L105), the service force-unwraps `parentMoveId`/`parentId` (`!`) and assumes `confirmData.newMoves` is non-empty and coherent with `isExtension`. That invariant currently depends on `AddLineController`+`LineEntryEngine` call order, but the service API does not enforce it.  
   Why it matters: this creates fragile coupling and runtime-failure risk if the service is reused elsewhere or if upstream behavior changes.  
   Suggested fix: validate preconditions at service boundary (e.g., reject invalid `ConfirmData` with explicit exception/result), or redesign input type so extension/branch are separate validated command objects.

2. **Minor — Single Responsibility / file-size smell remains in controller**  
   [`add_line_controller.dart`](/C:/code/misc/chess-trainer-5/src/lib/controllers/add_line_controller.dart) is still ~580 lines and owns UI-state transitions, board interaction, navigation, parity flow, persistence orchestration, undo generation, and label editing.  
   Why it matters: changes in unrelated concerns still converge in one class, increasing regression risk and making architecture harder to read from module boundaries alone.  
   Suggested fix: continue extraction into focused collaborators (for example, board/pill navigation coordinator and confirm/undo coordinator), leaving controller as orchestration glue.

3. **Minor — Dependency inversion is partial in construction path**  
   [`add_line_controller.dart` line 108](/C:/code/misc/chess-trainer-5/src/lib/controllers/add_line_controller.dart#L108) and [`add_line_controller.dart` line 111](/C:/code/misc/chess-trainer-5/src/lib/controllers/add_line_controller.dart#L111) still construct concrete `LinePersistenceService` inside the controller when optional injection is absent.  
   Why it matters: this keeps composition logic in a high-level module and makes extension/testing patterns less explicit.  
   Suggested fix: inject a persistence abstraction (or factory/provider) from composition root so the controller never creates concrete infrastructure-backed services itself.