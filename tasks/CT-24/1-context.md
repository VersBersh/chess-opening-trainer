# CT-24 Context

## Relevant Files

| File | Role |
|------|------|
| `src/lib/controllers/repertoire_browser_controller.dart` | Contains the deletion/orphan logic to be extracted: `deleteMoveAndGetParent()`, `getBranchDeleteInfo()`, `handleOrphans()`, and supporting types `OrphanChoice`, `BranchDeleteInfo`. Also holds the `RepertoireBrowserState` and all controller logic for the browser screen. |
| `src/lib/screens/repertoire_browser_screen.dart` | Screen widget that orchestrates the deletion flow: `_onDelete()` calls controller methods in sequence (confirm dialog, delete, orphan handling, reload, clear selection). `_showOrphanPrompt()` is the UI callback passed to `handleOrphans()`. |
| `src/lib/repositories/repertoire_repository.dart` | Abstract `RepertoireRepository` interface. The service will depend on this for `getMove()`, `getChildMoves()`, `deleteMove()`, and `countLeavesInSubtree()`. |
| `src/lib/repositories/review_repository.dart` | Abstract `ReviewRepository` interface. The service will depend on this for `getCardsForSubtree()` and `saveReview()`. |
| `src/lib/repositories/local/database.dart` | Drift-generated data classes: `RepertoireMove`, `ReviewCard`, `ReviewCardsCompanion`, etc. The service needs these types. |
| `src/lib/models/repertoire.dart` | `RepertoireTreeCache` model. The screen uses `cache.isLeaf()` to determine leaf vs. branch before calling deletion. The service may need the cache, or can query the repository directly. |
| `src/lib/widgets/repertoire_dialogs.dart` | Dialog functions: `showDeleteConfirmationDialog()`, `showBranchDeleteConfirmationDialog()`, `showOrphanPromptDialog()`. These remain in the screen/widget layer -- the service must not depend on them. |
| `src/lib/providers.dart` | Riverpod providers for `RepertoireRepository` and `ReviewRepository`. A new provider for the service will be registered here. |
| `src/lib/services/pgn_importer.dart` | Existing service class that depends on both repository abstractions. Demonstrates the pattern: constructor injection of `RepertoireRepository` and `ReviewRepository`, pure Dart (no Flutter imports). |
| `src/lib/services/drill_engine.dart` | Another existing service. Demonstrates the pattern of a pure-logic class with no repository dependencies (takes in-memory data). |
| `src/test/controllers/repertoire_browser_controller_test.dart` | Existing tests for deletion logic (`deleteMoveAndGetParent`, `handleOrphans`, `getBranchDeleteInfo`). Uses real in-memory database, not mocks. These tests will need to be migrated or duplicated for the new service. |
| `src/test/screens/drill_filter_test.dart` | Contains `FakeRepertoireRepository` and `FakeReviewRepository` implementations. Demonstrates the project's pattern for fake/stub repositories in tests. |
| `src/test/screens/repertoire_browser_screen_test.dart` | Widget tests for the browser screen. After extraction, these tests still exercise the full deletion flow via the screen. |

## Architecture

### Subsystem: Deletion and Orphan Handling

The deletion subsystem handles three related operations on the repertoire move tree:

1. **Leaf deletion** -- Deletes a single leaf node and its associated review card (card is cascade-deleted via foreign key). Returns the parent move ID to feed into orphan handling.

2. **Branch deletion** -- Deletes a non-leaf node and all its descendants via `ON DELETE CASCADE`. Before deletion, the screen gathers branch info (line count, card count) to show a confirmation dialog.

3. **Orphan handling** -- After a deletion leaves a parent node childless, the system prompts the user in a recursive loop:
   - "Keep shorter line" -- creates a new review card for the now-childless parent, treating it as a leaf.
   - "Remove move" -- deletes the childless parent and checks the grandparent, repeating until a non-orphan ancestor is found or the user dismisses the dialog.

### Current Component Layout

All three operations currently live in `RepertoireBrowserController`, which also handles: data loading, tree cache construction, expand/collapse state, board navigation, label editing, and card stats. The controller receives `RepertoireRepository` and `ReviewRepository` via constructor injection.

The screen (`RepertoireBrowserScreen`) orchestrates the deletion flow by:
1. Checking whether the selected node is a leaf or branch (via `treeCache.isLeaf()`).
2. Showing the appropriate confirmation dialog (leaf vs. branch).
3. Calling `controller.deleteMoveAndGetParent()`.
4. Calling `controller.handleOrphans()` with a UI callback for orphan prompts.
5. Reloading data and clearing selection.

### Key Constraints

1. **Repository abstractions are interfaces.** The service must depend on `RepertoireRepository` and `ReviewRepository` (abstract classes), not concrete implementations. This is the DIP principle the task enforces.

2. **No Flutter imports in the service.** The service is pure Dart. The orphan-handling loop uses a `Future<OrphanChoice?> Function(int moveId)` callback to request user input without importing Flutter. This pattern already exists in the controller.

3. **`ReviewCardsCompanion` for inserts.** When creating a new card for "keep shorter line," the code uses `ReviewCardsCompanion.insert()` -- a Drift companion class. This is the established pattern.

4. **Test pattern: real in-memory DB.** The existing controller tests use `AppDatabase(NativeDatabase.memory())` with `LocalRepertoireRepository` and `LocalReviewRepository`. The new service tests should follow this same pattern for integration-style testing, but could also use fake repositories (as in `drill_filter_test.dart`) for pure unit tests.

5. **Callback-based orphan prompting.** The `handleOrphans` method takes a user-prompt callback as a parameter. This decouples the deletion logic from the UI. The service should preserve this pattern.
