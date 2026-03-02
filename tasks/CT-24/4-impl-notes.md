# CT-24 Implementation Notes

## Files Created

- **`src/lib/services/deletion_service.dart`** -- New service containing `DeletionService` class, `OrphanChoice` enum, and `BranchDeleteInfo` class. All deletion and orphan-handling logic moved here from the controller.
- **`src/test/services/deletion_service_test.dart`** -- Unit tests for `DeletionService` using fake repository implementations. Covers `deleteMoveAndGetParent`, `getBranchDeleteInfo`, `handleOrphans` (6 scenarios), and `getMoveForOrphanPrompt`.

## Files Modified

- **`src/lib/controllers/repertoire_browser_controller.dart`** -- Removed `OrphanChoice` enum and `BranchDeleteInfo` class definitions. Added `DeletionService` as a constructor parameter. Replaced deletion method bodies with one-line delegations to the service. Added `export` directive to re-export `OrphanChoice`, `BranchDeleteInfo`, and `DeletionService` from the service file.
- **`src/lib/screens/repertoire_browser_screen.dart`** -- Updated `initState` to construct a `DeletionService` instance and pass it to the controller constructor.
- **`src/test/controllers/repertoire_browser_controller_test.dart`** -- Updated all 17 `RepertoireBrowserController(...)` construction sites to create and pass a `DeletionService` instance.

## Deviations from Plan

None. All steps were implemented as specified.

## Follow-up Work

- None identified during implementation.
