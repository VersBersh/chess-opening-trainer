# CT-20.4 Discovered Tasks

## CT-20.6: Consolidate test helper duplication

**Title:** Extract shared test helpers into a common test utility file
**Description:** `seedRepertoire()`, `createTestDatabase()`, and `getMoveIdBySan()` are duplicated across `repertoire_browser_controller_test.dart`, `repertoire_browser_screen_test.dart`, `add_line_controller_test.dart`, and other test files. Extract these into a shared `test/helpers/` utility file.
**Why discovered:** During CT-20.4 implementation, a new test file (`repertoire_browser_controller_test.dart`) was created that required copying these helpers yet again, making the duplication more visible.

## CT-20.7: Add `runInTransaction` to repository interface to remove PgnImporter's AppDatabase dependency

**Title:** Eliminate PgnImporter's direct AppDatabase dependency via repository transaction abstraction
**Description:** `PgnImporter` still accepts `AppDatabase` directly (alongside repository interfaces) solely for `_db.transaction()`. Add a `runInTransaction()` method to the repository interface (or a separate `UnitOfWork` abstraction) so `PgnImporter` can wrap operations in a transaction without depending on the concrete Drift database.
**Why discovered:** During CT-20.4 refactoring, the plan explicitly preserved `AppDatabase` in `PgnImporter` as a pragmatic compromise. The design review flagged this as a hidden semantic coupling (transaction boundary not enforced by type system).
