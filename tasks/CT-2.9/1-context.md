# CT-2.9 Context: Extract Line Persistence Service

## Relevant Files

| File | Role |
|------|------|
| `src/lib/controllers/add_line_controller.dart` | Controller that owns `_persistMoves()` -- the method to extract. Contains extension, branching, undo persistence logic (~620 lines total). |
| `src/lib/services/line_entry_engine.dart` | Pure engine that produces `ConfirmData` (parentMoveId, newMoves, isExtension, repertoireId, sortOrder). The service will consume this data type. |
| `src/lib/repositories/repertoire_repository.dart` | Abstract interface for move persistence (`saveMove`, `extendLine`, `undoExtendLine`, `undoNewLine`). The new service depends on this. |
| `src/lib/repositories/review_repository.dart` | Abstract interface for card persistence (`saveReview`, `getCardForLeaf`). The new service depends on this. |
| `src/lib/repositories/local/database.dart` | Drift database schema. Defines `RepertoireMovesCompanion`, `ReviewCardsCompanion`, `ReviewCard`, `RepertoireMove` data types used in persistence logic. |
| `src/lib/repositories/local/local_repertoire_repository.dart` | SQLite implementation. Has `extendLine()` (atomic transaction with card deletion + move insertion + card creation), `undoExtendLine()`, `undoNewLine()`. |
| `src/lib/repositories/local/local_review_repository.dart` | SQLite review repository. Has `saveReview()`, `getCardForLeaf()`. |
| `src/lib/services/pgn_importer.dart` | Reference pattern: a service class that takes repository abstractions, constructs companions, chains parent IDs, and creates cards. Most similar existing service to what this task creates. |
| `src/lib/models/repertoire.dart` | `RepertoireTreeCache` model. Not directly used by the persistence logic but provides context for `ConfirmData.isExtension`. |
| `src/lib/providers.dart` | Riverpod providers for repositories. No provider for services currently. |
| `src/test/controllers/add_line_controller_test.dart` | Existing controller tests for confirm persistence (extension and branching groups). These tests exercise `_persistMoves` indirectly via `confirmAndPersist()`. |
| `src/test/services/pgn_importer_test.dart` | Reference test pattern: creates in-memory database, seeds data, instantiates service with real repository implementations. |
| `src/test/screens/drill_screen_test.dart` | Contains `FakeRepertoireRepository` -- will need a stub for any new repository methods (none expected for this task). |
| `src/test/screens/drill_filter_test.dart` | Contains `FakeRepertoireRepository` -- same consideration as above. |
| `src/test/screens/home_screen_test.dart` | Contains `FakeRepertoireRepository` -- same consideration as above. |

## Architecture

### Subsystem Overview

The Add Line flow is a three-layer system:

1. **Screen** (`AddLineScreen`) -- Flutter widget that renders the board, move pills, action bar, and undo snackbars. Delegates all logic to the controller. The screen has no persistence awareness beyond showing undo snackbar results.

2. **Controller** (`AddLineController`) -- ChangeNotifier owning `AddLineState` and a `LineEntryEngine`. Translates user actions into engine calls and repository writes. Currently contains the `_persistMoves()` method (lines 501-564) that mixes orchestration concerns (parity validation, undo generation) with low-level persistence detail (companion construction, parent-ID chaining, card creation).

3. **Engine** (`LineEntryEngine`) -- Pure business logic with no DB or Flutter dependencies. Produces `ConfirmData` from the current line state: `parentMoveId`, `newMoves` (list of `BufferedMove`), `isExtension`, `repertoireId`, `sortOrder`.

### The SRP Violation in `_persistMoves()`

The `_persistMoves()` method in `AddLineController` has two distinct responsibility paths:

**Path A -- Extension:**
1. Gets the old leaf move ID from `confirmData.parentMoveId`
2. Fetches the old card via `_reviewRepo.getCardForLeaf()`
3. Constructs `RepertoireMovesCompanion` objects from `BufferedMove` data, assigning `sortOrder`
4. Calls `_repertoireRepo.extendLine()` which atomically deletes old card, inserts moves with parent-ID chaining, creates new card
5. Calls `loadData()` to rebuild tree cache
6. Returns `ConfirmSuccess` with extension info (old card, old leaf ID, inserted move IDs)

**Path B -- New Branch:**
1. Iterates through new moves, constructing `RepertoireMovesCompanion` for each
2. Chains `parentMoveId` from one insert to the next via `_repertoireRepo.saveMove()`
3. Creates a review card for the new leaf via `_reviewRepo.saveReview()`
4. Calls `loadData()` to rebuild tree cache
5. Returns `ConfirmSuccess` with branch info (inserted move IDs, no old card)

Both paths involve: Drift companion construction (an infrastructure concern), sequential parent-ID chaining (a persistence pattern), and card lifecycle management (domain logic mixed with data access). This makes the controller hard to test in isolation and couples it to Drift's `Value()` wrapper and `RepertoireMovesCompanion` types.

### Existing Service Pattern

The codebase has two categories of services:

1. **Pure engines** (`LineEntryEngine`, `DrillEngine`, `Sm2Scheduler`) -- No dependencies on repositories. Take in-memory data structures, return results. No `Future` methods.

2. **Repository-backed services** (`PgnImporter`) -- Takes `RepertoireRepository`, `ReviewRepository`, and `AppDatabase` as constructor parameters. Constructs companions, calls repository methods, manages transactions. Returns result types summarizing what happened.

The `PgnImporter` is the closest pattern match for the new service.

### Key Constraints

- **`ConfirmData` is the input contract**: The `LineEntryEngine` already produces a `ConfirmData` object with all the information needed for persistence. The new service should accept this as input.
- **Extension atomicity**: The `extendLine()` repository method is already atomic (runs in a transaction). The service should use it directly.
- **`loadData()` remains in the controller**: The tree cache rebuild is a controller concern (state management), not a persistence concern.
- **Undo methods stay in the controller initially**: The generation-counter check is controller-level logic. The initial extraction focuses on the forward path (`_persistMoves`).
- **No new repository interface methods needed**: The existing interfaces already have all the methods the service needs.
