# CT-2.9 Discovered Tasks

## 1. Extract undo operations into LinePersistenceService

- **Suggested ID:** CT-2.12
- **Title:** Extract undo persistence into LinePersistenceService
- **Description:** The `undoExtension()` and `undoNewLine()` methods in `AddLineController` still directly call repository methods (`_repertoireRepo.undoExtendLine`, `_repertoireRepo.undoNewLine`). Move these to `LinePersistenceService` for consistency with the forward persistence path. The generation-counter check remains in the controller.
- **Why discovered:** Design review flagged that persistence logic is split between the service (forward path) and controller (undo path), which is an incomplete extraction.

## 2. Extract shared test helpers

- **Suggested ID:** CT-2.13
- **Title:** Extract shared test helpers to test/helpers/
- **Description:** `seedRepertoire()`, `computeFens()`, and `createTestDatabase()` are duplicated across `add_line_controller_test.dart`, `line_persistence_service_test.dart`, and `pgn_importer_test.dart`. Extract to a shared `test/helpers/test_helpers.dart` file.
- **Why discovered:** Both test files required identical helper functions during implementation, making duplication visible.
