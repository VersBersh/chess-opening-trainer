# CT-24 Implementation Plan

## Goal

Extract delete-leaf, delete-branch, and handle-orphans logic from `RepertoireBrowserController` into a dedicated `DeletionService` class that depends on repository abstractions, with unit tests using fake repositories.

## Steps

### 1. Create the service file `src/lib/services/deletion_service.dart`

Create a new file containing:

- **Move `OrphanChoice` enum** from `repertoire_browser_controller.dart` to the new file. This enum is domain logic, not controller state.
- **Move `BranchDeleteInfo` class** from `repertoire_browser_controller.dart` to the new file. This is a data transfer object for the deletion flow.
- **Create `DeletionService` class** with constructor-injected dependencies:

```dart
class DeletionService {
  final RepertoireRepository _repertoireRepo;
  final ReviewRepository _reviewRepo;

  DeletionService({
    required RepertoireRepository repertoireRepo,
    required ReviewRepository reviewRepo,
  }) : _repertoireRepo = repertoireRepo,
       _reviewRepo = reviewRepo;
```

- **Move `deleteMoveAndGetParent(int moveId)`** from the controller. Unchanged logic: fetches the move, records its parent ID, deletes it, returns the parent ID.
- **Move `getBranchDeleteInfo(int moveId)`** from the controller. Unchanged logic: counts leaves in subtree, fetches cards for subtree, returns `BranchDeleteInfo`.
- **Move `handleOrphans(int? parentMoveId, Future<OrphanChoice?> Function(int) promptUser)`** from the controller. Unchanged logic: recursive loop that checks children, prompts user, and either creates a card or deletes the orphan.
- **Add `getMoveForOrphanPrompt(int moveId)`** -- a thin delegation to `_repertoireRepo.getMove()`. The screen's orphan prompt callback needs move data for display, and this keeps the screen from needing a direct repository reference for this purpose.

The file imports only:
- `../repositories/repertoire_repository.dart`
- `../repositories/review_repository.dart`
- `../repositories/local/database.dart` (for data classes: `RepertoireMove`, `ReviewCard`, `ReviewCardsCompanion`)

No Flutter imports. No controller imports.

### 2. Update `src/lib/controllers/repertoire_browser_controller.dart`

- **Add import:** `import '../services/deletion_service.dart';`
- **Remove** the `OrphanChoice` enum definition (moved to service).
- **Remove** the `BranchDeleteInfo` class definition (moved to service).
- **Add a `DeletionService` field** and accept it as a constructor parameter:

```dart
class RepertoireBrowserController extends ChangeNotifier {
  RepertoireBrowserController(
    this._repertoireRepo,
    this._reviewRepo,
    this._repertoireId,
    this._deletionService,
  );

  final RepertoireRepository _repertoireRepo;
  final ReviewRepository _reviewRepo;
  final int _repertoireId;
  final DeletionService _deletionService;
```

- **Replace the deletion method bodies** with delegations to the service:

```dart
Future<int?> deleteMoveAndGetParent(int moveId) =>
    _deletionService.deleteMoveAndGetParent(moveId);

Future<BranchDeleteInfo> getBranchDeleteInfo(int moveId) =>
    _deletionService.getBranchDeleteInfo(moveId);

Future<void> handleOrphans(
  int? parentMoveId,
  Future<OrphanChoice?> Function(int moveId) promptUser,
) => _deletionService.handleOrphans(parentMoveId, promptUser);

Future<RepertoireMove?> getMoveForOrphanPrompt(int moveId) =>
    _deletionService.getMoveForOrphanPrompt(moveId);
```

- **Re-export** `OrphanChoice` and `BranchDeleteInfo` from the controller file so that existing callers (the screen, dialogs) do not need import changes:

```dart
export '../services/deletion_service.dart'
    show OrphanChoice, BranchDeleteInfo, DeletionService;
```

This ensures that `repertoire_dialogs.dart` (which imports from the controller for `OrphanChoice`) and the screen continue to work without import changes.

**Dependencies:** Step 1 must be complete.

### 3. Update `src/lib/screens/repertoire_browser_screen.dart`

- **Update controller construction** in `initState` to pass a `DeletionService` instance:

```dart
final deletionService = DeletionService(
  repertoireRepo: ref.read(repertoireRepositoryProvider),
  reviewRepo: ref.read(reviewRepositoryProvider),
);
_controller = RepertoireBrowserController(
  ref.read(repertoireRepositoryProvider),
  ref.read(reviewRepositoryProvider),
  widget.repertoireId,
  deletionService,
);
```

No other changes to the screen. The `_onDelete()` and `_showOrphanPrompt()` methods remain unchanged since they call the controller's delegation methods, which have the same signatures.

**Dependencies:** Steps 1 and 2 must be complete.

### 4. Update existing controller tests `src/test/controllers/repertoire_browser_controller_test.dart`

- Update every `RepertoireBrowserController(...)` construction to pass a `DeletionService`:

```dart
final deletionService = DeletionService(
  repertoireRepo: LocalRepertoireRepository(db),
  reviewRepo: LocalReviewRepository(db),
);
final controller = RepertoireBrowserController(
  LocalRepertoireRepository(db),
  LocalReviewRepository(db),
  repId,
  deletionService,
);
```

- Add import for `DeletionService` (it is re-exported from the controller, so the existing import should suffice).
- All existing test assertions remain unchanged -- the behavior is identical, just the wiring differs.

**Dependencies:** Steps 1 and 2 must be complete.

### 5. Create unit tests `src/test/services/deletion_service_test.dart`

Create a new test file with fake repository implementations following the pattern in `drill_filter_test.dart`. The fakes must implement the **full interface** of `RepertoireRepository` and `ReviewRepository`. This is how all existing fakes in the codebase work -- each fake class uses `implements` and provides an `@override` for every method in the interface. Methods not exercised by the service return sensible defaults (empty lists, dummy values, no-ops).

**`FakeRepertoireRepository implements RepertoireRepository`** -- all methods overridden. The methods exercised by `DeletionService` need meaningful implementations:
- `getMove(int id)` -- returns from an in-memory list
- `getChildMoves(int parentMoveId)` -- filters in-memory list
- `deleteMove(int id)` -- removes from in-memory list, tracks call
- `countLeavesInSubtree(int moveId)` -- returns configurable value

All other methods (`getAllRepertoires`, `getRepertoire`, `saveRepertoire`, `deleteRepertoire`, `renameRepertoire`, `getMovesForRepertoire`, `saveMove`, `getRootMoves`, `getLineForLeaf`, `isLeafMove`, `getMovesAtPosition`, `extendLine`, `undoExtendLine`, `getOrphanedLeaves`, `pruneOrphans`, `updateMoveLabel`) return default stubs (e.g., empty lists, `0`, `async {}`).

**`FakeReviewRepository implements ReviewRepository`** -- all methods overridden. The methods exercised by `DeletionService` need meaningful implementations:
- `getCardsForSubtree(int moveId, ...)` -- returns configurable list
- `saveReview(ReviewCardsCompanion card)` -- tracks call

All other methods (`getDueCards`, `getDueCardsForRepertoire`, `getCardForLeaf`, `deleteCard`, `getAllCardsForRepertoire`, `getCardCountForRepertoire`) return default stubs.

**Test groups:**

**`deleteMoveAndGetParent` group:**
- Returns parent ID after deleting a move
- Returns null when move does not exist
- Calls `deleteMove` on the repository with the correct ID

**`getBranchDeleteInfo` group:**
- Returns correct line count from `countLeavesInSubtree`
- Returns correct card count from `getCardsForSubtree`

**`handleOrphans` group:**
- `keepShorterLine`: creates a review card for the orphaned parent via `saveReview`
- `removeMove`: deletes the orphan and walks up to the grandparent
- Recursive removal: walks up multiple levels until a non-orphan ancestor is found
- Dialog dismissed (null choice): stops the loop without deleting or creating
- Non-orphan parent (has children): returns immediately without prompting
- Null parent ID: returns immediately

**`getMoveForOrphanPrompt` group:**
- Returns the move when it exists
- Returns null when it does not exist

**Dependencies:** Step 1 must be complete.

### 6. Run tests and verify no regressions

All commands run from the `src/` directory:

```bash
cd src
flutter test test/services/deletion_service_test.dart
flutter test test/controllers/repertoire_browser_controller_test.dart
flutter test test/screens/repertoire_browser_screen_test.dart
flutter test
```

- New service tests pass.
- Existing controller tests pass (behavior unchanged, only wiring changed).
- Existing screen widget tests pass (the screen constructs the controller internally in `initState`, so the screen test requires no direct changes -- it picks up the new constructor signature through the production screen code updated in Step 3).
- Full suite passes with no regressions.

**Dependencies:** All previous steps must be complete.

## Risks / Open Questions

1. **Re-export vs. direct imports.** The plan uses `export` in the controller file to re-export `OrphanChoice`, `BranchDeleteInfo`, and `DeletionService` so existing callers (screen, dialogs) need zero import changes. An alternative is to update all import sites to import from `deletion_service.dart` directly. The re-export approach is less disruptive; the direct-import approach is cleaner long-term. Either works -- the plan uses re-export for minimal churn.

2. **Constructor parameter count.** Adding `DeletionService` as a fourth constructor parameter to `RepertoireBrowserController` means every direct call site must be updated. A grep for `RepertoireBrowserController(` shows the call sites are: the screen's `initState` (Step 3) and the controller test file (Step 4). The screen test (`repertoire_browser_screen_test.dart`) does **not** construct the controller directly -- it pumps `RepertoireBrowserScreen`, which constructs the controller internally. So the screen test needs no changes for the new constructor parameter.

3. **Fake vs. real-DB tests for the service.** The plan creates fake-repository-based unit tests for the service (following `drill_filter_test.dart` style). The existing controller tests that exercise deletion already use real in-memory databases. Both provide coverage. The fakes give faster, more focused tests; the real-DB tests provide integration confidence. Keeping both is intentional.

4. **`ReviewCardsCompanion` dependency.** The `handleOrphans` method uses `ReviewCardsCompanion.insert(...)`, which is a Drift-generated companion class from `database.dart`. This is a concrete type, not an abstraction. However, this is the established pattern across the codebase (e.g., `pgn_importer.dart` does the same), and `ReviewCardsCompanion` is a data class, not a repository implementation. The DIP concern applies to repository classes, not data transfer objects.

5. **No Riverpod provider for the service.** The plan constructs `DeletionService` directly in `initState` rather than registering a Riverpod provider. This matches how `PgnImporter` is constructed (directly in the import screen). If the service is later needed by other screens, a provider can be added to `providers.dart`. For now, direct construction is simpler.

6. **Review issue 2 (original Step 6) -- removed as a separate step.** The original plan had a Step 6 to "update widget tests and other callers," specifically claiming `repertoire_browser_screen_test.dart` contains direct `RepertoireBrowserController(` construction calls. Investigation confirmed this is not the case: the screen test pumps `RepertoireBrowserScreen` and never constructs the controller directly. The only files that construct `RepertoireBrowserController(` are `repertoire_browser_screen.dart` (covered by Step 3) and `repertoire_browser_controller_test.dart` (covered by Step 4). The former Step 6 has been removed since its work is fully covered by existing steps.
