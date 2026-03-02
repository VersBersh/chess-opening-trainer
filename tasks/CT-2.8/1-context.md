# CT-2.8 Context

## Relevant Files

- **`src/lib/controllers/add_line_controller.dart`** — Controller with `_persistMoves()`, `confirmAndPersist()`, `flipAndConfirm()`, and sealed `ConfirmResult` hierarchy. Primary file to modify.
- **`src/lib/screens/add_line_screen.dart`** — UI screen with `_onConfirmLine()` and `_onFlipAndConfirm()` that switch on `ConfirmResult` and show SnackBars.
- **`src/lib/repositories/local/local_repertoire_repository.dart`** — Contains `extendLine()` (transactional) and `saveMove()` (non-transactional). These are the DB operations that can throw on unique constraint violations.
- **`src/lib/repositories/local/database.dart`** — Schema with unique indexes `idx_moves_unique_sibling` and `idx_moves_unique_root`.
- **`src/lib/repositories/repertoire_repository.dart`** — Abstract interface for `RepertoireRepository`.
- **`src/lib/repositories/review_repository.dart`** — Abstract interface for `ReviewRepository`.
- **`src/lib/services/line_entry_engine.dart`** — Pure logic engine producing `ConfirmData`.
- **`src/test/controllers/add_line_controller_test.dart`** — Existing controller tests. Error handling tests go here.
- **`src/pubspec.yaml`** — `sqlite3` is a dev_dependency; needs to move to regular dependencies for `SqliteException` import.

## Architecture

The confirm flow follows a Controller → Repository layered architecture:

1. **Screen** (`AddLineScreen`) calls `controller.confirmAndPersist()` or `controller.flipAndConfirm()`.
2. **Controller** (`AddLineController`) validates parity, then calls `_persistMoves()`.
3. **`_persistMoves()`** has two paths:
   - **Path A (Extension):** Calls `_repertoireRepo.extendLine()` — runs inside a Drift `transaction()`, so it's atomic.
   - **Path B (Branching):** Calls `_repertoireRepo.saveMove()` in a loop + `_reviewRepo.saveReview()` — NOT wrapped in a transaction, so a mid-loop failure leaves partial data.
4. Both paths call `loadData()` after success to rebuild the tree cache.

The database has unique indexes that throw `SqliteException` (code 2067, SQLITE_CONSTRAINT_UNIQUE) when duplicate SANs are inserted under the same parent. Currently these exceptions are unhandled.
