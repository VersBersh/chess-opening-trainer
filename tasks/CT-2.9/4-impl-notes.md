# CT-2.9 Implementation Notes

## Files Created

- `src/lib/services/line_persistence_service.dart` — New service class with `PersistResult` and `LinePersistenceService`. Contains `persistNewMoves()` which dispatches to `_persistExtension()` or `_persistBranch()`.
- `src/test/services/line_persistence_service_test.dart` — Unit tests covering extension (single and multi-move) and branching (from non-leaf and from root) paths.

## Files Modified

- `src/lib/controllers/add_line_controller.dart` — Removed `import 'package:drift/drift.dart'`, added `import '../services/line_persistence_service.dart'`. Added optional `persistenceService` constructor parameter with default. Replaced `_persistMoves()` body with delegation to service.

## Deviations from Plan

None. The implementation follows the plan exactly.

## New Tasks / Follow-up Work

- **Extract undo operations into LinePersistenceService** — The `undoExtension()` and `undoNewLine()` methods in `AddLineController` still directly call repository methods. These could be moved to the service for consistency, with the generation-counter check remaining in the controller.
- **Extract test helpers to shared utility** — Both `add_line_controller_test.dart` and `line_persistence_service_test.dart` duplicate `seedRepertoire()`, `computeFens()`, and `createTestDatabase()` helpers. These could be extracted to a shared `test/helpers/` directory.
