# CT-2.9 Implementation Plan: Extract Line Persistence Service

## Goal

Extract the `_persistMoves()` method from `AddLineController` into a dedicated `LinePersistenceService` class that depends on repository abstractions, reducing controller complexity and enabling direct unit testing of persistence logic.

## Current State

The `_persistMoves()` method in `add_line_controller.dart` handles two persistence paths (extension and branching) with low-level companion construction, parent-ID chaining, and card creation. The controller directly imports `package:drift/drift.dart` for the `Value` wrapper. All persistence tests go through the controller's `confirmAndPersist()` method, which couples persistence testing to engine and state management concerns.

## Steps

### Step 1: Define the service result type and create the service class

**File to create:** `src/lib/services/line_persistence_service.dart`

Create a new file containing:

**1a.** A `PersistResult` class to represent the persistence-layer return value:

```dart
class PersistResult {
  final bool isExtension;
  final int? oldLeafMoveId;
  final List<int> insertedMoveIds;
  final ReviewCard? oldCard;

  const PersistResult({
    required this.isExtension,
    this.oldLeafMoveId,
    this.insertedMoveIds = const [],
    this.oldCard,
  });
}
```

This mirrors the fields of `ConfirmSuccess` but is owned by the service layer, not the controller.

**1b.** The `LinePersistenceService` class:

```dart
class LinePersistenceService {
  final RepertoireRepository _repertoireRepo;
  final ReviewRepository _reviewRepo;

  LinePersistenceService({
    required RepertoireRepository repertoireRepo,
    required ReviewRepository reviewRepo,
  }) : _repertoireRepo = repertoireRepo,
       _reviewRepo = reviewRepo;

  Future<PersistResult> persistNewMoves(ConfirmData confirmData) async {
    if (confirmData.isExtension) {
      return _persistExtension(confirmData);
    } else {
      return _persistBranch(confirmData);
    }
  }
}
```

The service imports `ConfirmData` from `line_entry_engine.dart`, `RepertoireMovesCompanion`/`ReviewCardsCompanion`/`ReviewCard` from `database.dart`, and the repository interfaces.

**Extension path** (`_persistExtension`):
1. Get old leaf move ID from `confirmData.parentMoveId`
2. Fetch old card via `_reviewRepo.getCardForLeaf()`
3. Construct `RepertoireMovesCompanion` objects from `BufferedMove` data
4. Call `_repertoireRepo.extendLine()` (atomic)
5. Return `PersistResult` with extension info

**Branch path** (`_persistBranch`):
1. Iterate through new moves, constructing `RepertoireMovesCompanion` for each
2. Chain `parentMoveId` from one insert to the next via `_repertoireRepo.saveMove()`
3. Create review card for the new leaf via `_reviewRepo.saveReview()`
4. Return `PersistResult` with branch info

**Depends on:** Nothing.

### Step 2: Refactor `AddLineController` to delegate to the service

**File to modify:** `src/lib/controllers/add_line_controller.dart`

**2a.** Add the service as a constructor dependency with a default:

```dart
class AddLineController extends ChangeNotifier {
  AddLineController(
    this._repertoireRepo,
    this._reviewRepo,
    this._repertoireId, {
    int? startingMoveId,
    LinePersistenceService? persistenceService,
  }) : _startingMoveId = startingMoveId,
       _persistenceService = persistenceService ??
           LinePersistenceService(
             repertoireRepo: _repertoireRepo,
             reviewRepo: _reviewRepo,
           );

  final LinePersistenceService _persistenceService;
}
```

By defaulting to a new instance when not provided, all existing call sites (screen, tests) continue to work without changes.

**2b.** Replace the body of `_persistMoves()` with a delegation call:

```dart
Future<ConfirmResult> _persistMoves(LineEntryEngine engine) async {
  final confirmData = engine.getConfirmData();
  final result = await _persistenceService.persistNewMoves(confirmData);

  await loadData();

  return ConfirmSuccess(
    isExtension: result.isExtension,
    oldLeafMoveId: result.oldLeafMoveId,
    insertedMoveIds: result.insertedMoveIds,
    oldCard: result.oldCard,
  );
}
```

**2c.** Remove `import 'package:drift/drift.dart' hide Column;` if no other code in the controller references Drift types. Remove unused imports of `RepertoireMovesCompanion`, `ReviewCardsCompanion`, `Value()`.

**Depends on:** Step 1.

### Step 3: Verify screen requires no changes

**File to review:** `src/lib/screens/add_line_screen.dart`

The screen creates the controller in `initState()`. Since the controller's constructor now has an optional `persistenceService` parameter with a default, the screen requires **no changes**. The `controllerOverride` parameter already allows full controller injection in tests.

**Depends on:** Step 2.

### Step 4: Write unit tests for `LinePersistenceService`

**File to create:** `src/test/services/line_persistence_service_test.dart`

Follow the existing test pattern from `pgn_importer_test.dart` and `add_line_controller_test.dart`: use in-memory SQLite databases with real repository implementations.

**Tests to write:**

1. **Extension test:** Seed repertoire with [e4] and a card. Create ConfirmData with isExtension=true. Verify: old card fetched, moves inserted, new card created, result fields correct.

2. **Branch test:** Seed repertoire with [e4, e5] and a card. Create ConfirmData with isExtension=false, parentMoveId=e4's ID. Verify: new moves inserted, new card created, existing card preserved.

3. **Root branch test:** Empty repertoire. ConfirmData with parentMoveId=null. Verify: moves inserted starting from null parent, parent chain correct.

4. **Multi-move extension test:** Seed [e4] with card. ConfirmData with isExtension=true, newMoves=[e5, Nf3]. Verify 3 moves, parent chain e4 -> e5 -> Nf3, card on Nf3.

**Depends on:** Step 1.

### Step 5: Verify all tests pass

Run all test suites from the Flutter project root (`src/`):
- `cd src && flutter test test/services/line_persistence_service_test.dart` (new service tests)
- `cd src && flutter test test/controllers/add_line_controller_test.dart` (existing controller tests)
- `cd src && flutter test test/screens/add_line_screen_test.dart` (existing screen tests)

All existing tests should pass without modification because the controller's public API is unchanged. The new service tests verify the extracted logic in isolation.

**Depends on:** Steps 2, 3, 4.

## Risks / Open Questions

1. **`ConfirmData` import coupling.** The new service imports `ConfirmData` from `line_entry_engine.dart`. This creates a dependency between two services. Acceptable because `ConfirmData` is a simple data class. Could be moved to a shared models file later if desired.

2. **Drift type leakage.** The service uses `RepertoireMovesCompanion`, `ReviewCardsCompanion`, and `Value()` from Drift. This matches the pattern used by `PgnImporter`, so it is consistent with the codebase.

3. **Test helper duplication.** The `seedRepertoire()`, `createTestDatabase()`, and `computeFens()` helpers in `add_line_controller_test.dart` may need duplication in the new test file. Extract to shared test utility if straightforward.

4. **Transaction boundary for branch path.** The branch path inserts moves one-by-one without a transaction wrapper. The extraction does not change this behavior, but it makes the gap more visible. A follow-up could wrap in a transaction.

5. **No behavioral change.** This is a pure refactoring. The `ConfirmSuccess` type returned to the screen is unchanged. The undo flow is unchanged. The persistence behavior is identical.

6. **Default service construction.** The controller creates a default `LinePersistenceService` when none is provided. This avoids changes to all existing call sites but means the controller still has knowledge of how to construct the service. An alternative (Riverpod provider injection) would require more changes.

7. **Undo extraction deferred.** Extracting undo operations (`undoExtension`, `undoNewLine`) into the service is a natural follow-up but out of scope for this task to keep the change set focused. The undo methods are simpler (single repository calls) and the generation-counter check is controller-level logic. This should be a separate task.
